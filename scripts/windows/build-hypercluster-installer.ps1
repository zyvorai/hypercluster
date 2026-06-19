#Requires -Version 5.1
# Build the Hypercluster Desktop NSIS installer for Windows.
# Stages CLI runtime, runs Tauri build, copies .exe to desktop/distribution/.
param(
    [string]$Target     = "x86_64-pc-windows-msvc",
    [switch]$SkipStage,
    [switch]$SkipBuild
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root    = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$Version = if (Test-Path "$Root\VERSION") {
    (Get-Content "$Root\VERSION" -Raw).Trim()
} else { "0.1.0" }
$Dist = "$Root\desktop\distribution"

Write-Host "-> Building Hypercluster Desktop NSIS installer v$Version ($Target)"

if (-not $SkipStage) {
    Write-Host "-> Staging CLI resources..."
    & "$PSScriptRoot\stage-cli-resources.ps1"
}

if (-not $SkipBuild) {
    Push-Location "$Root\desktop"
    try {
        npm install
        if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        npx tauri build --bundles nsis --target $Target
        if ($LASTEXITCODE -ne 0) { throw "tauri build failed" }
    } finally {
        Pop-Location
    }
}

# Find the produced NSIS installer
$BundleDir = "$Root\desktop\src-tauri\target\$Target\release\bundle\nsis"
if (-not (Test-Path $BundleDir)) {
    $BundleDir = "$Root\desktop\src-tauri\target\release\bundle\nsis"
}
$NsisExe = Get-ChildItem $BundleDir -Filter "*.exe" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $NsisExe) {
    Write-Error "NSIS installer not found in $BundleDir after tauri build."
}

$OutName = "Hypercluster-$Version-x86_64-Setup.exe"
$OutPath = "$Dist\$OutName"
if (-not (Test-Path $Dist)) { New-Item -ItemType Directory -Path $Dist -Force | Out-Null }
Copy-Item $NsisExe.FullName $OutPath -Force

Write-Host ""
Write-Host "OK $OutPath"
Write-Host "   Install: double-click or run: Start-Process '$OutPath'"
Write-Host "   Uninstall: scripts\windows\uninstall-hypercluster-app.ps1"
