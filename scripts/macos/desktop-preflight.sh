#!/usr/bin/env bash
# Preflight checks for Hypercluster Desktop on Apple Silicon (M1/M2/M3/M4).
# Run before first deploy from the GUI app or after install issues.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=arch-check.sh
source "${ROOT}/scripts/macos/arch-check.sh"

PASS=0
WARN=0
FAIL=0

ok()   { echo "  ✅ $*"; PASS=$((PASS + 1)); }
warn() { echo "  ⚠️  $*"; WARN=$((WARN + 1)); }
fail() { echo "  ❌ $*"; FAIL=$((FAIL + 1)); }

echo "Hypercluster Desktop — macOS preflight"
echo "Host arch: $(hc_macos_host_arch)"
echo ""

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "This script is for macOS only."
  exit 1
fi

if hc_macos_is_arm64_host; then
  ok "Apple Silicon host (arm64)"
else
  fail "Host is not arm64 — release Hypercluster Desktop is Apple Silicon only."
  echo "     Local dev on Intel: npm run desktop (x86_64 build)."
fi

for p in /opt/homebrew/bin /usr/local/bin; do
  [[ -d "$p" ]] && ok "Homebrew prefix present: $p" || true
done

BASH5=""
for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
  if [[ -x "$candidate" ]]; then
    ver="$("$candidate" --version 2>/dev/null | head -1 || true)"
    if [[ "$ver" == *"version 5"* ]] || [[ "$ver" == *"version 4"* ]]; then
      BASH5="$candidate"
      ok "bash 4+ at $candidate ($ver)"
      break
    fi
  fi
done
if [[ -z "$BASH5" ]]; then
  fail "Homebrew bash 5 not found — run: ./scripts/setup-macos.sh"
fi

for tool in ssh kubectl helm ansible; do
  if command -v "$tool" &>/dev/null; then
    ok "$tool in PATH ($(command -v "$tool"))"
  else
    warn "$tool not in PATH — install via ./scripts/setup-macos.sh (needed for deploy)"
  fi
done

APP="/Applications/Hypercluster.app"
if [[ -d "$APP" ]]; then
  ok "Hypercluster.app installed"
  if hc_macos_require_arm64_app "$APP" 2>/dev/null; then
    ok "App binary is arm64-native"
  else
    fail "App binary is not arm64 — reinstall the *-arm64.pkg from Zyvor"
  fi
  RUNTIME="${APP}/Contents/Resources/hypercluster-runtime/hypercluster"
  if [[ -x "$RUNTIME" ]]; then
    ok "Bundled hypercluster CLI present"
  else
    warn "Bundled CLI missing — rebuild with make desktop-pkg or set binary in Settings"
  fi
else
  warn "Hypercluster.app not in /Applications (dev mode or not installed yet)"
fi

if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  ok "SSH agent socket set (GUI deploy can use your keys)"
else
  warn "SSH_AUTH_SOCK unset — add keys to agent before remote deploy: ssh-add ~/.ssh/your_key"
fi

echo ""
echo "Summary: ${PASS} passed, ${WARN} warnings, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "See docs/guides/desktop-macos-apple-silicon.md for troubleshooting."
  exit 1
fi
exit 0
