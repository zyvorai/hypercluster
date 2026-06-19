#Requires -Version 5.1
# Stage the hypercluster CLI runtime into desktop/src-tauri/resources/ so that
# Tauri's NSIS bundler includes it in the Windows installer.
# Must be run before: npx tauri build --bundles nsis
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root  = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
$Stage = "$Root\desktop\src-tauri\resources\hypercluster-runtime"

Write-Host "-> Staging CLI runtime to: $Stage"
if (-not (Test-Path $Stage)) {
    New-Item -ItemType Directory -Path $Stage -Force | Out-Null
}

# Prefer Python-built native .exe (no WSL2 required) over bash script.
$PyExe = "$Root\cli\dist\hypercluster.exe"
if (Test-Path $PyExe) {
    Write-Host "  -> Staging Python-built hypercluster.exe (native, no WSL2)"
    Copy-Item $PyExe "$Stage\hypercluster.exe" -Force
} else {
    Write-Host "  -> Python .exe not found; staging bash script + WSL2 launcher"
    Copy-Item "$Root\hypercluster" "$Stage\hypercluster" -Force
}
# Always stage the .bat launcher as a WSL2 fallback regardless of whether .exe was built.
Copy-Item "$Root\desktop\distribution\windows\hypercluster.bat" "$Stage\hypercluster.bat" -Force

# Library and config directories — always clean stale staged copies first so a
# removed source directory doesn't leave orphan files in the installer bundle.
foreach ($dir in @("lib", "config")) {
    $staged = "$Stage\$dir"
    if (Test-Path $staged) { Remove-Item $staged -Recurse -Force }
    if (Test-Path "$Root\$dir") {
        Copy-Item "$Root\$dir" $staged -Recurse -Force
    }
}
if (Test-Path "$Root\VERSION") {
    Copy-Item "$Root\VERSION" "$Stage\VERSION" -Force
}

Write-Host "OK CLI runtime staged ($Stage)"
