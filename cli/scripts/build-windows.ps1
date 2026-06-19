#Requires -Version 5.1
# Build hypercluster.exe for Windows via PyInstaller
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$CliDir = Split-Path $ScriptDir -Parent

Push-Location $CliDir
try {
    Write-Host "-> Creating Python venv ..."
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1

    Write-Host "-> Installing dependencies ..."
    pip install --upgrade pip
    pip install -e ".[dev]"

    Write-Host "-> Building with PyInstaller ..."
    pyinstaller hypercluster-windows.spec --clean --noconfirm

    $exe = "$CliDir\dist\hypercluster.exe"
    if (Test-Path $exe) {
        $size = (Get-Item $exe).Length / 1MB
        Write-Host "OK Binary: $exe ($([Math]::Round($size, 1)) MB)"
    } else {
        Write-Host "ERROR: hypercluster.exe not found after build" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
