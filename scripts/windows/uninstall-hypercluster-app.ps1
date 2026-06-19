#Requires -Version 5.1
# Uninstall Hypercluster Desktop on Windows.
# Use -Purge to also remove app data and license acceptance (trial record is preserved).
param([switch]$Purge)
Set-StrictMode -Version Latest

$AppName = "Hypercluster"

# Find uninstall entry in user or machine registry
$uninstallKey = Get-ItemProperty `
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq $AppName } |
    Select-Object -First 1

if (-not $uninstallKey) {
    $uninstallKey = Get-ItemProperty `
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $AppName } |
        Select-Object -First 1
}

if ($uninstallKey -and $uninstallKey.UninstallString) {
    Write-Host "-> Uninstalling $AppName..."
    $uninstallArgs = if ($uninstallKey.QuietUninstallString) {
        $uninstallKey.QuietUninstallString
    } else {
        "$($uninstallKey.UninstallString) /S"
    }
    Start-Process cmd -ArgumentList "/c $uninstallArgs" -Wait
    Write-Host "OK $AppName uninstalled."
} else {
    Write-Host "$AppName not found in installed programs."
}

if ($Purge) {
    $dataDir = "$env:APPDATA\Hypercluster"
    $licFile = "$env:USERPROFILE\.hypercluster\license-acceptance.json"

    if (Test-Path $dataDir) {
        Remove-Item $dataDir -Recurse -Force
        Write-Host "Removed app data: $dataDir"
    }
    if (Test-Path $licFile) {
        Remove-Item $licFile -Force
        Write-Host "Removed license acceptance: $licFile"
    }
    Write-Host "Trial record preserved (Windows Credential Manager + $env:USERPROFILE\.hypercluster\trial.json)."
    Write-Host "Reinstalling will NOT reset the 30-day trial."
}
