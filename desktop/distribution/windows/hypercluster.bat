@echo off
rem Hypercluster Desktop — Windows CLI launcher wrapper.
rem Requires WSL2. This file is invoked by the Tauri desktop app via paths::bundled_hypercluster_bin().
setlocal

set "SCRIPT_DIR=%~dp0"
set "HC_SCRIPT=%SCRIPT_DIR%hypercluster"

where wsl >nul 2>&1
if %ERRORLEVEL% equ 0 (
    wsl -- bash -lc "exec \"%HC_SCRIPT%\" %*"
    exit /b %ERRORLEVEL%
)

echo ERROR: WSL2 not found. Hypercluster requires WSL2 on Windows. >&2
echo Install WSL2 from: https://aka.ms/wsl >&2
echo Then run: wsl --install -d Ubuntu >&2
exit /b 1
