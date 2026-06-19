#Requires -Version 5.1
# Install Hypercluster Desktop on Windows by running the NSIS installer.
param(
    [string]$InstallerPath = "",
    [switch]$Silent
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$Dist = "$Root\desktop\distribution"

if (-not $InstallerPath) {
    $found = Get-ChildItem $Dist -Filter "Hypercluster-*-x86_64-Setup.exe" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $found) {
        Write-Error "Installer not found in $Dist. Build it first: make desktop-pkg-windows"
    }
    $InstallerPath = $found.FullName
}

if (-not (Test-Path $InstallerPath)) {
    Write-Error "Installer not found: $InstallerPath"
}

Write-Host "-> Installing Hypercluster Desktop from: $InstallerPath"
if ($Silent) {
    Start-Process $InstallerPath -ArgumentList "/S" -Wait
} else {
    Start-Process $InstallerPath -Wait
}
Write-Host "OK Installation complete."
Write-Host "   Run preflight: scripts\windows\desktop-preflight.ps1"
