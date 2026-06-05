#!/bin/bash
# Double-click uninstaller for Hypercluster Desktop (macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/macos/uninstall-hypercluster-app.sh"

choice=$(osascript <<'APPLESCRIPT'
display dialog "Remove Hypercluster from /Applications?

Your trial record stays on this Mac so reinstalling does not start a new trial.

• Remove App — uninstall Hypercluster.app only
• Full Removal — also delete cluster data and license acceptance (trial is kept)" buttons {"Cancel", "Remove App", "Full Removal"} default button "Remove App" with title "Uninstall Hypercluster"
button returned of result
APPLESCRIPT
)

case "$choice" in
  "Remove App")
    exec "$SCRIPT"
    ;;
  "Full Removal")
    exec "$SCRIPT" --purge
    ;;
  *)
    exit 0
    ;;
esac
