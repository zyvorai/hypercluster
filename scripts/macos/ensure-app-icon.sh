#!/usr/bin/env bash
# Ensure Hypercluster.app has icon.icns and CFBundleIconFile (Launchpad / Spotlight).
set -euo pipefail

APP="${1:?usage: ensure-app-icon.sh /path/to/Hypercluster.app}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICON_SRC="${ROOT}/desktop/src-tauri/icons/icon.icns"
RES="${APP}/Contents/Resources"
PLIST="${APP}/Contents/Info.plist"

[[ -d "$APP" ]] || { echo "ERROR: not a .app bundle: $APP" >&2; exit 1; }
[[ -f "$ICON_SRC" ]] || { echo "ERROR: missing icon source: $ICON_SRC" >&2; exit 1; }

mkdir -p "$RES"
if [[ ! -f "${RES}/icon.icns" ]] || ! cmp -s "$ICON_SRC" "${RES}/icon.icns"; then
  cp "$ICON_SRC" "${RES}/icon.icns"
fi

if [[ ! -f "$PLIST" ]]; then
  echo "ERROR: missing Info.plist: $PLIST" >&2
  exit 1
fi

if /usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$PLIST" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile icon' "$PLIST"
else
  /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string icon' "$PLIST"
fi
