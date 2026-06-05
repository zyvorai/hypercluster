#!/usr/bin/env bash
# Install Hypercluster.app to /Applications after Zyvor license acceptance.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/hypercluster-license-accept.sh
source "${ROOT}/scripts/lib/hypercluster-license-accept.sh"
# shellcheck source=../lib/hypercluster-trial.sh
source "${ROOT}/scripts/lib/hypercluster-trial.sh"
# shellcheck source=arch-check.sh
source "${ROOT}/scripts/macos/arch-check.sh"

APP_SRC="${1:-}"
if [[ -z "$APP_SRC" ]]; then
  APP_SRC="$(find "${ROOT}/desktop/src-tauri/target" -path '*/bundle/macos/Hypercluster.app' -type d 2>/dev/null | head -1 || true)"
fi

if [[ -z "$APP_SRC" || ! -d "$APP_SRC" ]]; then
  echo "Usage: $0 [path/to/Hypercluster.app]" >&2
  echo "  Build first: make desktop-pkg  or  npm run desktop:build" >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS only." >&2
  exit 1
fi

if ! hc_macos_is_arm64_host; then
  cat >&2 <<'EOF'
ERROR: Hypercluster Desktop requires Apple Silicon (arm64).

Intel-based Mac support has ended. The distributed app is built for M-series Macs only.
EOF
  exit 1
fi

require_hypercluster_license_accept "$ROOT"
hc_trial_ensure_started

if hc_trial_is_expired; then
  cat >&2 <<EOF
ERROR: Your $(hc_trial_days)-day Hypercluster Desktop trial on this Mac has expired.

Reinstalling does not start a new trial. Contact $(hc_trial_sales_email) for a license.
EOF
  exit 1
fi

DEST="/Applications/Hypercluster.app"

echo "→ Installing Hypercluster to ${DEST}…"
if [[ -d "$DEST" ]]; then
  echo "  Removing existing installation…"
  if ! rm -rf "$DEST" 2>/dev/null; then
    echo "  (existing app is root-owned — using sudo)"
    sudo rm -rf "$DEST"
  fi
fi

# Ensure runtime bundle exists in source .app
RUNTIME="${APP_SRC}/Contents/Resources/hypercluster-runtime"
if [[ ! -x "${RUNTIME}/hypercluster" ]]; then
  mkdir -p "${RUNTIME}/lib" "${RUNTIME}/config"
  cp "${ROOT}/hypercluster" "${RUNTIME}/"
  chmod +x "${RUNTIME}/hypercluster"
  cp -R "${ROOT}/lib/." "${RUNTIME}/lib/"
  cp -R "${ROOT}/config/." "${RUNTIME}/config/"
  cp "${ROOT}/desktop/distribution/HYPERCLUSTER-EULA.txt" "${APP_SRC}/Contents/Resources/" 2>/dev/null || true
fi

if ! ditto "$APP_SRC" "$DEST" 2>/dev/null; then
  sudo ditto "$APP_SRC" "$DEST"
fi
if ! "${ROOT}/scripts/macos/ensure-app-icon.sh" "$DEST" 2>/dev/null; then
  sudo "${ROOT}/scripts/macos/ensure-app-icon.sh" "$DEST"
fi
hc_macos_require_arm64_app "$DEST" || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST" 2>/dev/null || sudo "$LSREGISTER" -f "$DEST" 2>/dev/null || true
fi

echo "✅ Installed ${DEST} (Apple Silicon / arm64)"
echo "   Finder: open /Applications — look for Hypercluster"
echo "   Launch: open -a Hypercluster   or Spotlight → Hypercluster"
echo "   Launch: open -a Hypercluster"
echo "   Uninstall: open ${ROOT}/scripts/macos/Uninstall-Hypercluster.command"
echo "   Or: ${ROOT}/scripts/macos/uninstall-hypercluster-app.sh"
