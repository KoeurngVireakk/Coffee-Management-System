#Requires -Version 5.1
# Daily runner: .\run.ps1 [-Target web|android|backend] [-DeviceId <id>]
$ErrorActionPreference = 'Stop'
try {
    & (Join-Path $PSScriptRoot 'scripts/run.ps1') @args
    exit $LASTEXITCODE
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
