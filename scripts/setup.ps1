#Requires -Version 5.1
<#
.SYNOPSIS
Guided Windows development setup after cloning the repository.
.EXAMPLE
.\setup.ps1
.EXAMPLE
.\setup.ps1 -ConfigureDatabase -Target android
.EXAMPLE
.\setup.ps1 -Check
#>
[CmdletBinding()]
param(
    [ValidateSet('web', 'android')][string]$Target = 'web',
    [switch]$ConfigureDatabase,
    [switch]$SkipAdmin,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'project-common.ps1')
$backend = Join-Path $projectRoot 'apps/backend'
$mobile = Join-Path $projectRoot 'apps/mobile'

try {
    Write-Host 'Coffee Management System - local development setup' -ForegroundColor Cyan
    Test-ProjectTools $projectRoot
    if ($Check) {
        Write-Host 'Tool checks passed. No project configuration or database was changed.' -ForegroundColor Green
        exit 0
    }
    if (-not (Test-Path -LiteralPath (Join-Path $backend 'composer.lock')) -or -not (Test-Path -LiteralPath (Join-Path $mobile 'pubspec.lock'))) {
        throw 'A committed dependency lockfile is missing. Restore it from Git before running setup.'
    }
    $envPath = Join-Path $backend '.env'
    $examplePath = Join-Path $backend '.env.example'
    $createdEnv = -not (Test-Path -LiteralPath $envPath)
    if ($createdEnv) {
        Copy-Item -LiteralPath $examplePath -Destination $envPath
        Write-Host 'Created apps/backend/.env from .env.example.'
    }
    $untouchedExample = (Get-FileHash -LiteralPath $envPath).Hash -eq (Get-FileHash -LiteralPath $examplePath).Hash
    Invoke-ProjectCommand composer @('install', '--no-interaction', '--prefer-dist', '--no-progress', '--no-scripts') $backend 'Installing locked PHP dependencies' 'Read the Composer error above. Check php --ini, required extensions, network access and composer diagnose.'
    $config = Invoke-ProjectHelper $projectRoot 'inspect'
    if ($createdEnv -or $untouchedExample -or $ConfigureDatabase) {
        Write-Host "`nEnter credentials for your local MySQL development account. The password is hidden."
        Write-Host 'MySQL must already be installed/running. A dedicated account is recommended; see docs/database/README.md.'
        $databaseSettings = @{
            DB_HOST = Read-ProjectValue 'MySQL host' $config.DB_HOST
            DB_PORT = Read-ProjectValue 'MySQL port' $config.DB_PORT
            DB_DATABASE = Read-ProjectValue 'Development database name' $config.DB_DATABASE
            DB_USERNAME = Read-ProjectValue 'MySQL username' $config.DB_USERNAME
            DB_PASSWORD = Read-ProjectSecret 'MySQL password (Enter if your local account has no password)'
        }
        $saved = Invoke-ProjectHelper $projectRoot 'configure' $databaseSettings
        Write-Host $saved.message
        $databaseSettings.Clear()
        $config = Invoke-ProjectHelper $projectRoot 'inspect'
    }
    else { Write-Host 'Preserving existing .env settings. Use -ConfigureDatabase to change database credentials.' }

    Invoke-ProjectCommand php @('artisan', 'config:clear', '--no-interaction') $backend 'Clearing stale local Laravel configuration' 'Check bootstrap/cache write permissions.'
    Invoke-ProjectCommand composer @('run-script', 'post-autoload-dump', '--no-interaction') $backend 'Discovering installed Laravel packages' 'Check the package discovery error above and local .env syntax.'

    if (-not $config.hasAppKey) {
        Invoke-ProjectCommand php @('artisan', 'key:generate', '--no-interaction') $backend 'Generating the missing Laravel app key' 'Check .env syntax and write permissions.'
    }
    else { Write-Host 'Preserving the existing Laravel app key.' }
    $database = Invoke-ProjectHelper $projectRoot 'database'
    Write-Host "`nTarget: $($config.DB_HOST):$($config.DB_PORT) / $($config.DB_DATABASE)"
    Write-Host 'Setup applies pending migrations and seeds staff roles. Use a database dedicated to this checkout.'
    $confirmation = Read-Host 'Type the database name to confirm this is your local development database (Enter to cancel)'
    if ($confirmation -cne $config.DB_DATABASE) { throw 'Database confirmation did not match. No migrations or role seeding were run.' }
    if (-not $database.exists) {
        Write-Host 'Creating the missing local database (requires CREATE privilege).'
        [void](Invoke-ProjectHelper $projectRoot 'create-database' @{ confirmation = $confirmation })
    }
    Invoke-ProjectCommand php @('artisan', 'migrate', '--no-interaction') $backend 'Applying pending migrations' 'Check the reported SQL error and account privileges. Never use migrate:fresh to repair an existing database.'
    Invoke-ProjectCommand php @('artisan', 'db:seed', '--class=RoleSeeder', '--no-interaction') $backend 'Seeding cashier, manager and admin roles' 'Check database access and the RoleSeeder error above.'
    Invoke-ProjectCommand php @('artisan', 'migrate:status', '--no-interaction') $backend 'Verifying migration status' 'Check database access and the migration error above.'
    [void](Invoke-ProjectHelper $projectRoot 'ready')
    if (-not $SkipAdmin) {
        $admin = Invoke-ProjectHelper $projectRoot 'admin-status'
        if ($admin.exists) { Write-Host 'An active admin already exists; its account and password were preserved.' }
        elseif ((Read-ProjectValue 'Create your first local admin login? (y/n)' 'y') -eq 'y') {
            $name = Read-ProjectValue 'Admin display name' 'Local Developer'
            $email = Read-ProjectValue 'Admin email' 'admin@example.test'
            $password = Read-ProjectSecret 'Choose an app login password (at least 12 characters; separate from MySQL)'
            $repeat = Read-ProjectSecret 'Confirm the app login password'
            if ($password -cne $repeat) { throw 'App passwords did not match. No admin was created; rerun setup to retry.' }
            $result = Invoke-ProjectHelper $projectRoot 'create-admin' @{ name = $name; email = $email; password = $password }
            Write-Host $result.message -ForegroundColor Green
            $password = $null
            $repeat = $null
        }
    }
    Invoke-ProjectCommand flutter @('pub', 'get', '--enforce-lockfile') $mobile 'Installing locked Flutter dependencies' 'Check the Flutter/Dart version and network error above. Use the CI Flutter baseline; do not delete the lockfile.'
    $developmentConfig = Join-Path $mobile 'config/development.local.json'
    if (-not (Test-Path -LiteralPath $developmentConfig)) {
        Copy-Item -LiteralPath (Join-Path $mobile 'config/development.example.json') -Destination $developmentConfig
        Write-Host 'Created the public Flutter development configuration.'
    }
    $doctor = Invoke-ProjectCommand flutter @('doctor', '-v') $mobile 'Checking Flutter platform setup' 'Run flutter doctor -v and fix the platform you intend to use.' -Capture -AllowFailure
    Write-Host $doctor
    if ($Target -eq 'android' -and $doctor -match '(?m)^\[(!|X|x)\] Android toolchain') {
        throw 'Android toolchain is not ready. Follow the Android findings above; run flutter doctor --android-licenses to review licenses, and check Android SDK/JDK 21. Project configuration has been retained.'
    }
    if ($Target -eq 'web' -and -not (@(Get-ProjectDevices $projectRoot | Where-Object { $_.id -eq 'chrome' }).Count)) {
        throw 'Chrome was not detected. Install Chrome (or configure CHROME_EXECUTABLE), reopen PowerShell and run flutter doctor -v.'
    }
    Write-Host "`nSetup completed. Start the project with .\run.ps1" -ForegroundColor Green
    Write-Host 'Android: .\run.ps1 -Target android -DeviceId emulator-5554'
    Write-Host 'This created no sample products, orders, inventory or payment data.'
    exit 0
}
catch {
    Write-ProjectFailure $_.Exception.Message
    exit 1
}
finally { $script:ProjectSecrets.Clear() }
