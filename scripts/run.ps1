#Requires -Version 5.1
<#
.SYNOPSIS
Runs Laravel and Flutter. Ctrl+C stops the API process started by this runner.
.EXAMPLE
.\run.ps1 -Target android -Emulator Pixel_10_Pro_XL
#>
[CmdletBinding()]
param(
    [ValidateSet('web', 'android', 'backend')][string]$Target = 'web',
    [string]$DeviceId,
    [string]$Emulator,
    [ValidateRange(1, 65535)][int]$ApiPort = 8000,
    [ValidateRange(1, 65535)][int]$WebPort = 5173,
    [ValidateSet('127.0.0.1', '0.0.0.0')][string]$BindAddress = '127.0.0.1',
    [string]$ApiBaseUrl
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'project-common.ps1')
$backend = Join-Path $projectRoot 'apps/backend'
$mobile = Join-Path $projectRoot 'apps/mobile'
$apiProcess = $null

try {
    if (-not (Get-Command php -CommandType Application -ErrorAction SilentlyContinue)) { throw 'PHP is not on PATH. Run .\setup.ps1 -Check for installation guidance.' }
    if (-not (Test-Path -LiteralPath (Join-Path $backend 'vendor/autoload.php')) -or -not (Test-Path -LiteralPath (Join-Path $backend '.env'))) {
        throw 'Backend dependencies/configuration are missing. Run .\setup.ps1 first.'
    }
    $config = Invoke-ProjectHelper $projectRoot 'inspect'
    if (-not $config.hasAppKey) { throw 'The Laravel app key is missing. Run .\setup.ps1 first.' }
    Invoke-ProjectCommand php @('artisan', 'config:clear', '--no-interaction') $backend 'Refreshing local API configuration' 'Check .env syntax and bootstrap/cache write permissions.'
    $database = Invoke-ProjectHelper $projectRoot 'database'
    if (-not $database.exists) { throw 'The configured MySQL database does not exist. Run .\setup.ps1 first.' }
    [void](Invoke-ProjectHelper $projectRoot 'ready')
    if ($Target -ne 'backend') {
        if (-not (Get-Command flutter -CommandType Application -ErrorAction SilentlyContinue) -or -not (Test-Path -LiteralPath (Join-Path $mobile '.dart_tool/package_config.json'))) {
            throw 'Flutter or its dependencies are missing. Run .\setup.ps1 first.'
        }
        if ($Emulator -and $Target -ne 'android') { throw '-Emulator requires -Target android.' }
        if ($Target -eq 'android' -and $Emulator) {
            $existing = @(Get-ProjectDevices $projectRoot | Where-Object { $_.targetPlatform -like 'android*' -and $_.emulator })
            if ($existing.Count -gt 0) { throw 'An Android emulator is already running. Use -DeviceId <id> instead of -Emulator, or close it before starting a different AVD.' }
            Invoke-ProjectCommand flutter @('emulators', '--launch', $Emulator, '--cold') $mobile 'Starting Android with a cold boot' 'Check flutter emulators. For a hang, use Android Studio Device Manager > Cold Boot; check available RAM and flutter doctor -v.'
            $deadline = [DateTime]::UtcNow.AddSeconds(120)
            do {
                $devices = @(Get-ProjectDevices $projectRoot)
                $android = @($devices | Where-Object { $_.targetPlatform -like 'android*' -and $_.emulator })
                if ($android.Count -gt 0) { break }
                Write-Host 'Waiting for Android to become available...'
                Start-Sleep -Seconds 3
            } while ([DateTime]::UtcNow -lt $deadline)
        }
        else { $devices = @(Get-ProjectDevices $projectRoot) }
        if ($Target -eq 'web') {
            if (-not $DeviceId) { $DeviceId = 'chrome' }
            if ($DeviceId -notin @('chrome', 'edge')) { throw 'Web mode supports -DeviceId chrome or edge.' }
            Assert-ProjectPort $WebPort
        }
        else {
            $android = @($devices | Where-Object { $_.targetPlatform -like 'android*' })
            if (-not $DeviceId) {
                if ($android.Count -ne 1) { throw 'Choose an Android device with -DeviceId. Run flutter devices, or start one with -Emulator <name>.' }
                $DeviceId = $android[0].id
            }
        }
        $selected = @($devices | Where-Object { $_.id -eq $DeviceId })
        if ($selected.Count -ne 1) { throw "Device '$DeviceId' is unavailable. Run flutter devices; check Android USB debugging or emulator boot completion." }
        if ($Target -eq 'android' -and $selected[0].targetPlatform -notlike 'android*') { throw "Device '$DeviceId' is not Android. Check flutter devices." }
        if ($Target -eq 'android' -and -not $selected[0].emulator -and $BindAddress -ne '0.0.0.0') { throw 'Physical Android requires -BindAddress 0.0.0.0 and an -ApiBaseUrl using your PC LAN IP on a trusted network.' }
        if (-not $ApiBaseUrl) {
            if ($Target -eq 'web') { $ApiBaseUrl = "http://localhost:$ApiPort/api/v1" }
            elseif ($selected[0].emulator) { $ApiBaseUrl = "http://10.0.2.2:$ApiPort/api/v1" }
            else { throw 'For physical Android, supply -BindAddress 0.0.0.0 -ApiBaseUrl http://<PC-LAN-IP>:8000/api/v1 on a trusted network.' }
        }
        $uri = $null
        if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin @('http', 'https') -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
            throw 'API_BASE_URL must be an absolute HTTP(S) API URL without credentials, a query or a fragment. It is public build configuration.'
        }
    }
    Assert-ProjectPort $ApiPort $BindAddress
    $logDirectory = Join-Path $projectRoot '.dev'
    if (-not (Test-Path -LiteralPath $logDirectory)) { [void](New-Item -ItemType Directory -Path $logDirectory) }
    $logPrefix = Join-Path $logDirectory ('api-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + $PID)
    $router = Join-Path $backend 'vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php'
    # Use Laravel's development router in one PHP process, so shutdown owns exactly one PID.
    $serverArguments = (@('-S', "${BindAddress}:$ApiPort", '-t', (Join-Path $backend 'public'), $router) | ForEach-Object { ConvertTo-ProjectArgument $_ }) -join ' '
    $apiProcess = Start-Process -FilePath (Get-Command php -CommandType Application).Source -ArgumentList $serverArguments -WorkingDirectory (Join-Path $backend 'public') -WindowStyle Hidden -RedirectStandardOutput ($logPrefix + '.stdout.log') -RedirectStandardError ($logPrefix + '.stderr.log') -PassThru
    $ready = $false
    $healthError = 'No successful response.'
    for ($attempt = 0; $attempt -lt 15; $attempt++) {
        if ($apiProcess.HasExited) { throw "API server exited with code $($apiProcess.ExitCode). Read $logPrefix.stderr.log for the PHP error." }
        try {
            $health = Invoke-WebRequest -Uri "http://127.0.0.1:$ApiPort/up" -UseBasicParsing -TimeoutSec 2
            if ($health.StatusCode -eq 200) { $ready = $true; break }
        }
        catch { $healthError = $_.Exception.Message }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw "API health check failed: $healthError`nFix: Read $logPrefix.stderr.log and apps/backend/storage/logs/laravel.log. Check APP_KEY and .env settings." }
    Write-Host "`nAPI ready: http://127.0.0.1:$ApiPort/api/v1" -ForegroundColor Green
    Write-Host "API log: $logPrefix.stderr.log"
    Write-Host 'Press Ctrl+C to stop. The runner only stops the API process it started.'
    if ($Target -eq 'backend') {
        while (-not $apiProcess.HasExited) { Start-Sleep -Seconds 1 }
        throw "API server exited with code $($apiProcess.ExitCode). Read $logPrefix.stderr.log."
    }
    Write-Host "Flutter device: $DeviceId | API_BASE_URL: $ApiBaseUrl" -ForegroundColor Cyan
    $flutterArguments = @('run', '-d', $DeviceId, "--dart-define=API_BASE_URL=$ApiBaseUrl")
    if ($Target -eq 'web') { $flutterArguments += @('--web-port', [string]$WebPort) }
    Push-Location -LiteralPath $mobile
    try {
        & flutter @flutterArguments
        if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE. Read the error above; run flutter doctor -v. For Android licenses, run flutter doctor --android-licenses." }
    }
    finally { Pop-Location }
}
catch { Write-ProjectFailure $_.Exception.Message; exit 1 }
finally {
    if ($null -ne $apiProcess) {
        if (-not $apiProcess.HasExited) { $apiProcess.Kill(); $apiProcess.WaitForExit() }
        $apiProcess.Dispose()
    }
    $script:ProjectSecrets.Clear()
}
