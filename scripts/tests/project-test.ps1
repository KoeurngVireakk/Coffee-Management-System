#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $projectRoot 'scripts/project-common.ps1')
$checks = 0
function Assert-Check {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Failed: $Message" }
    $script:checks++
}
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('coffee-script-test-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $testDirectory)
try {
    $errors = @()
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'scripts') -Filter '*.ps1' -Recurse) + @(Get-Item -LiteralPath (Join-Path $projectRoot 'setup.ps1'),(Join-Path $projectRoot 'run.ps1'))) {
        $tokens = $null
        $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        $errors += $parseErrors
    }
    Assert-Check ($errors.Count -eq 0) 'PowerShell scripts parse'
    $failureFile = Join-Path $testDirectory 'native-error.php'
    [IO.File]::WriteAllText($failureFile, '<?php fwrite(STDERR, "synthetic-password failure"); exit(7);')
    $script:ProjectSecrets.Add('synthetic-password')
    $previousLocation = (Get-Location).Path
    try {
        Invoke-ProjectCommand php @($failureFile) $testDirectory 'intentional failure' 'Synthetic fix instruction.' -Capture
        throw 'Expected a native failure.'
    }
    catch {
        Assert-Check ($_.Exception.Message -match 'code 7') 'real native exit code preserved'
        Assert-Check ($_.Exception.Message -match '\[redacted\]' -and $_.Exception.Message -notmatch 'synthetic-password') 'secret redacted from diagnostics'
        Assert-Check ($_.Exception.Message -match 'Synthetic fix instruction') 'fix instruction retained'
    }
    Assert-Check ((Get-Location).Path -eq $previousLocation) 'working directory restored after failure'
    try {
        Invoke-ProjectCommand 'coffee-definitely-missing-command' @() $testDirectory 'intentional missing tool' 'Install the missing tool.'
        throw 'Missing command was accepted.'
    }
    catch { Assert-Check ($_.Exception.Message -match 'not available on PATH') 'missing tool fails instead of reporting success' }
    foreach ($entry in @('setup.ps1', 'run.ps1')) {
        try {
            Invoke-ProjectCommand powershell @('-NoProfile', '-File', (Join-Path $projectRoot $entry), '-Target', 'invalid-target') $testDirectory 'intentional invalid argument' 'Choose a documented target.' -Capture
            throw 'Invalid target was accepted.'
        }
        catch { Assert-Check ($_.Exception.Message -match 'code 1') "$entry returns failure for an invalid target" }
    }
    function Read-Host {
        param([string]$Prompt, [switch]$AsSecureString)
        return (New-Object Security.SecureString)
    }
    try {
        $emptyPassword = Read-ProjectSecret 'synthetic empty password'
        Assert-Check ($emptyPassword -is [string] -and $emptyPassword.Length -eq 0) 'empty MySQL password stays an empty string'
    }
    finally { Remove-Item Function:Read-Host }
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        $busyPort = $listener.LocalEndpoint.Port
        try { Assert-ProjectPort $busyPort; throw 'Expected a busy port failure.' }
        catch { Assert-Check ($_.Exception.Message -match 'unavailable') 'busy port reported accurately' }
        Assert-Check $listener.Server.IsBound 'existing listener preserved'
    }
    finally { $listener.Stop() }
    Assert-ProjectPort $busyPort
    Assert-Check $true 'released port accepted'
    # Verify Windows argument escaping against a real native process, including Unicode.
    $echoFile = Join-Path $testDirectory 'argument echo.php'
    [IO.File]::WriteAllText($echoFile, '<?php echo json_encode(array_slice($argv, 1), JSON_UNESCAPED_UNICODE);')
    $khmer = -join ([char[]]@(0x1781, 0x17D2, 0x1798, 0x17C2, 0x179A))
    $expected = @('with spaces', 'embedded "quotes"', 'trailing\', $khmer, '$literal')
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-Command php -CommandType Application).Source
    $start.Arguments = (@($echoFile) + $expected | ForEach-Object { ConvertTo-ProjectArgument $_ }) -join ' '
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.StandardOutputEncoding = New-Object Text.UTF8Encoding($false)
    $process = [Diagnostics.Process]::Start($start)
    try {
        $actual = ConvertFrom-Json -InputObject $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        Assert-Check ($actual.Count -eq $expected.Count) 'native argument count'
        for ($index = 0; $index -lt $expected.Count; $index++) {
            Assert-Check ($actual[$index] -ceq $expected[$index]) "native argument $index survives quoting and Unicode"
        }
    }
    finally { $process.Dispose() }
    Write-Host "$checks PowerShell script checks passed." -ForegroundColor Green
}
finally {
    $script:ProjectSecrets.Clear()
    # Delete only the two fixture files created above; never recurse over a computed path.
    foreach ($name in @('native-error.php', 'argument echo.php')) {
        $file = Join-Path $testDirectory $name
        if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
    }
    Remove-Item -LiteralPath $testDirectory
}
