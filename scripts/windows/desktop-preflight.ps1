#Requires -Version 5.1
# Preflight checks for Hypercluster Desktop on Windows.
# Run before first deploy from the GUI app or after install issues.
param()
Set-StrictMode -Version Latest

$PASS = 0; $WARN = 0; $FAIL = 0

function ok   { param($msg) Write-Host "  OK   $msg"; $script:PASS++ }
function warn { param($msg) Write-Host "  WARN $msg"; $script:WARN++ }
function fail { param($msg) Write-Host "  FAIL $msg"; $script:FAIL++ }

Write-Host "Hypercluster Desktop -- Windows preflight"
Write-Host "Host arch: $env:PROCESSOR_ARCHITECTURE"
Write-Host ""

# WSL2
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $distros = (wsl --list --quiet 2>&1 | Out-String).Trim()
    if ($distros -ne "") {
        ok "WSL2 available with distributions: $($distros -replace '\r?\n', ', ')"
    } else {
        warn "WSL2 installed but no distributions -- run: wsl --install -d Ubuntu"
    }
} else {
    fail "WSL2 not found -- required for Hypercluster CLI. Install: https://aka.ms/wsl"
}

# Python 3.11+ in WSL2
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $pyver = (wsl -- python3 --version 2>&1 | Out-String).Trim()
    if ($pyver -match "Python 3\.(1[1-9]|[2-9]\d)") {
        ok "Python in WSL2: $pyver"
    } elseif ($pyver -ne "") {
        warn "Python in WSL2: $pyver (need 3.11+) -- run in WSL2: sudo apt install python3.12"
    } else {
        warn "python3 not found in WSL2 -- run in WSL2: sudo apt install python3.12"
    }
}

# kubectl, helm, ssh, git in WSL2
foreach ($tool in @("kubectl", "helm", "ssh", "git", "ansible")) {
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        $found = (wsl -- which $tool 2>&1 | Out-String).Trim()
        if ($found -and -not $found.StartsWith("which:")) {
            ok "$tool in WSL2 ($found)"
        } else {
            warn "$tool not found in WSL2 -- needed for deploy"
        }
    }
}

# WebView2 runtime — check all three install locations: per-user, machine 64-bit, machine 32-bit
$wv2Guid = "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
$wv2 = Get-ItemProperty "HKCU:\Software\Microsoft\EdgeUpdate\Clients\$wv2Guid" `
    -ErrorAction SilentlyContinue
if (-not $wv2) {
    $wv2 = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$wv2Guid" `
        -ErrorAction SilentlyContinue
}
if (-not $wv2) {
    $wv2 = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$wv2Guid" `
        -ErrorAction SilentlyContinue
}
if ($wv2) {
    ok "WebView2 runtime installed ($($wv2.pv))"
} else {
    warn "WebView2 runtime not found -- the NSIS installer handles this automatically on first run"
}

# Hypercluster app installed
$appPath = "$env:LOCALAPPDATA\Programs\Hypercluster\Hypercluster.exe"
if (Test-Path $appPath) {
    ok "Hypercluster.exe installed at $appPath"
    $hcPath = "$env:LOCALAPPDATA\Programs\Hypercluster\resources\hypercluster-runtime\hypercluster"
    if (Test-Path $hcPath) {
        ok "Bundled CLI runtime present"
    } else {
        warn "Bundled CLI runtime not found -- reinstall with: make desktop-pkg-windows"
    }
} else {
    warn "Hypercluster.exe not found (dev mode or not installed yet)"
}

Write-Host ""
Write-Host "Summary: $PASS passed, $WARN warnings, $FAIL failed"
if ($FAIL -gt 0) {
    Write-Host ""
    Write-Host "See desktop/distribution/windows/ for troubleshooting."
    exit 1
}
exit 0
