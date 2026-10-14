# Shared by setup.ps1, run.ps1 and the dependency-free script checks.
Set-StrictMode -Version Latest
$script:ProjectSecrets = New-Object 'System.Collections.Generic.List[string]'

function Protect-ProjectOutput {
    param([string]$Text)
    $Text = [regex]::Replace($Text, '\x1B\[[0-9;]*[A-Za-z]', '')
    foreach ($secret in $script:ProjectSecrets) {
        if ($secret.Length -gt 0) { $Text = $Text.Replace($secret, '[redacted]') }
    }
    return $Text
}

function Read-ProjectSecret {
    param([string]$Prompt)
    $secure = Read-Host $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        if ($plain.Length -gt 0) { $script:ProjectSecrets.Add($plain) }
        return $plain
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $secure.Dispose()
    }
}

function Read-ProjectValue {
    param([string]$Prompt, [string]$Default)
    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) { return $Default }
    return $value.Trim()
}

function Invoke-ProjectCommand {
    param(
        [string]$Command, [string[]]$Arguments = @(), [string]$Directory,
        [string]$Step, [string]$Fix, [switch]$Capture, [switch]$AllowFailure
    )
    if ($Step) { Write-Host "`n$Step" -ForegroundColor Cyan }
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) { throw "$Command is not available on PATH.`nFix: $Fix" }
    $previousPreference = $ErrorActionPreference
    Push-Location -LiteralPath $Directory
    try {
        # Windows PowerShell treats native stderr as ErrorRecords. Check the exit code instead.
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        $lines = @(& $Command @Arguments 2>&1 | ForEach-Object {
            $line = Protect-ProjectOutput ([string]$_)
            if (-not $Capture) { Write-Host $line }
            $line
        })
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousPreference
        Pop-Location
    }
    if ($code -ne 0 -and -not $AllowFailure) {
        $detail = if ($Capture) { "`n" + ($lines -join "`n") } else { '' }
        throw "$Command exited with code $code during '$Step'.$detail`nFix: $Fix"
    }
    if ($Capture) { return ($lines -join "`n") }
    if ($code -ne 0) { Write-Host "Diagnostic exited with code $code; review the findings above." -ForegroundColor Yellow }
}

function ConvertTo-ProjectArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows process argument quoting, including trailing backslashes before a quote.
    return '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function Invoke-ProjectHelper {
    param([string]$Root, [string]$Action, [hashtable]$Payload = @{})
    $php = (Get-Command php -CommandType Application -ErrorAction Stop).Source
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $php
    $start.Arguments = (@((Join-Path $Root 'scripts/dev-setup.php'), $Action, (Join-Path $Root 'apps/backend')) | ForEach-Object { ConvertTo-ProjectArgument $_ }) -join ' '
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $start.StandardOutputEncoding = $encoding
    $start.StandardErrorEncoding = $encoding
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        # Explicit UTF-8 preserves Khmer and special-character passwords on PowerShell 5.1.
        $writer = New-Object System.IO.StreamWriter($process.StandardInput.BaseStream, $encoding)
        $writer.WriteLine(($Payload | ConvertTo-Json -Compress -Depth 4))
        $writer.Dispose()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            $process.Kill()
            throw "Setup helper timed out during '$Action'. Check whether local MySQL is running and responsive."
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        try { $response = $stdout | ConvertFrom-Json -ErrorAction Stop }
        catch { throw "Setup helper returned invalid output (exit $($process.ExitCode)). $(Protect-ProjectOutput $stderr)" }
        if (-not $response.ok) { throw "$(Protect-ProjectOutput $response.error)`nFix: $($response.fix)" }
        if ($process.ExitCode -ne 0) { throw "Setup helper failed with exit $($process.ExitCode). $(Protect-ProjectOutput $stderr)" }
        return $response.result
    }
    finally { $process.Dispose() }
}

function Test-ProjectTools {
    param([string]$Root)
    $missing = @()
    $links = @{ php = 'https://windows.php.net/download/'; composer = 'https://getcomposer.org/download/'; flutter = 'https://docs.flutter.dev/install' }
    foreach ($tool in @('php', 'composer', 'flutter')) {
        if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            $missing += "$tool is not on PATH. Install it from $($links[$tool]) and reopen PowerShell."
        }
    }
    if ($missing.Count -gt 0) { throw ($missing -join "`n") }
    $php = Invoke-ProjectCommand php @('-r', 'echo json_encode([PHP_VERSION, get_loaded_extensions()]);') $Root 'Checking PHP' 'Run php --ini and check your PHP installation.' -Capture | ConvertFrom-Json
    if ([version]$php[0] -lt [version]'8.4.0' -or [version]$php[0] -ge [version]'9.0.0') { throw "PHP $($php[0]) does not satisfy this project's ^8.4 constraint. Install PHP 8.4+ (8.x) and update PATH." }
    $required = @('ctype', 'curl', 'dom', 'fileinfo', 'filter', 'hash', 'mbstring', 'openssl', 'pcre', 'PDO', 'session', 'tokenizer', 'xml', 'pdo_mysql', 'pdo_sqlite', 'zip')
    $missingExtensions = @($required | Where-Object { $_ -notin $php[1] })
    if ($missingExtensions.Count -gt 0) { throw "Missing PHP extensions: $($missingExtensions -join ', '). Run php --ini, enable them in the loaded php.ini, then retry." }
    $composer = Invoke-ProjectCommand composer @('--version', '--no-ansi') $Root 'Checking Composer' 'Repair Composer/PHP, then reopen PowerShell.' -Capture
    if ($composer -notmatch 'Composer version 2\.') { throw 'Composer 2.x is required. Update Composer from https://getcomposer.org/download/.' }
    $flutter = Invoke-ProjectCommand flutter @('--version', '--machine') $Root 'Checking Flutter' 'Repair the Flutter SDK and PATH; see https://docs.flutter.dev/install.' -Capture | ConvertFrom-Json
    if ([version]($flutter.frameworkVersion -split '-')[0] -lt [version]'3.44.6') { throw "Flutter $($flutter.frameworkVersion) is too old. Use Flutter 3.44.6 stable, the CI baseline." }
    if ($flutter.frameworkVersion -ne '3.44.6') { Write-Host "Flutter $($flutter.frameworkVersion) detected; CI uses 3.44.6 stable." -ForegroundColor Yellow }
    Write-Host "PHP $($php[0]), Composer 2 and Flutter $($flutter.frameworkVersion) are available." -ForegroundColor Green
}

function Get-ProjectDevices {
    param([string]$Root)
    $json = Invoke-ProjectCommand flutter @('devices', '--machine', '--device-timeout', '5') $Root 'Checking connected devices' 'Run flutter doctor -v and flutter devices.' -Capture
    # ConvertFrom-Json does not enumerate root arrays on Windows PowerShell 5.1.
    foreach ($device in (ConvertFrom-Json -InputObject $json)) { $device }
}

function Assert-ProjectPort {
    param([int]$Port, [string]$Address = '127.0.0.1')
    $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($Address), $Port)
    try { $listener.Start() }
    catch { throw "Port $Port on $Address is unavailable: $($_.Exception.Message)`nFix: Stop the existing server, or choose another -ApiPort/-WebPort. No existing process was stopped." }
    finally { $listener.Stop() }
}

function Write-ProjectFailure {
    param([string]$Message)
    Write-Host "`nStopped: $(Protect-ProjectOutput $Message)" -ForegroundColor Red
    Write-Host 'See docs/project/local-development.md for setup and troubleshooting.' -ForegroundColor Yellow
}
