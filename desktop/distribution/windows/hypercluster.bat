@echo off
rem Hypercluster Desktop — Windows CLI launcher wrapper (CMD/PowerShell callers only).
rem The Tauri desktop backend invokes the bash script via WSL2 directly, not via this .bat.
setlocal

set "SCRIPT_DIR=%~dp0"
set "HC_SCRIPT=%SCRIPT_DIR%hypercluster"

where wsl >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: WSL2 not found. Hypercluster requires WSL2 on Windows. >&2
    echo Install WSL2 from: https://aka.ms/wsl >&2
    echo Then run: wsl --install -d Ubuntu >&2
    exit /b 1
)

rem Translate the Windows path to a WSL2 mount path (C:\foo\bar -> /mnt/c/foo/bar)
for /f "delims=" %%P in ('wsl wslpath -u "%HC_SCRIPT%"') do set "HC_SCRIPT_WSL=%%P"
if "%HC_SCRIPT_WSL%"=="" (
    echo ERROR: Could not translate script path to WSL. Is WSL2 configured? >&2
    exit /b 1
)

wsl -- /bin/bash "%HC_SCRIPT_WSL%" %*
exit /b %ERRORLEVEL%
