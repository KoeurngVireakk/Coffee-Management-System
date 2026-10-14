#Requires -Version 5.1
# Guided setup: .\setup.ps1 [-Target android] [-ConfigureDatabase] [-Check]
$ErrorActionPreference = 'Stop'
try {
    & (Join-Path $PSScriptRoot 'scripts/setup.ps1') @args
    exit $LASTEXITCODE
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
