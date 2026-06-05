#!/usr/bin/env bash
# Uninstall Hypercluster Desktop from macOS.
set -euo pipefail

PURGE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge)
      PURGE=true
      shift
      ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--purge]

Removes Hypercluster.app from /Applications.

  --purge   Also delete app data and license acceptance record:
            ~/Library/Application Support/Hypercluster
            ~/.hypercluster/
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: macOS only." >&2
  exit 1
fi

APP="/Applications/Hypercluster.app"
REMOVED=0

if [[ -d "$APP" ]]; then
  echo "→ Removing ${APP}…"
  if rm -rf "$APP" 2>/dev/null; then
    :
  elif [[ "$(uname -s)" == "Darwin" ]] && sudo -n true 2>/dev/null; then
    sudo rm -rf "$APP"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "  Root-owned app (installed via .pkg) — using sudo…"
    sudo rm -rf "$APP"
  else
    echo "ERROR: Could not remove ${APP} (permission denied)." >&2
    exit 1
  fi
  REMOVED=1
else
  echo "  Hypercluster.app not found in /Applications."
fi

if $PURGE; then
  DATA="${HOME}/Library/Application Support/Hypercluster"
  META="${HOME}/.hypercluster"
  if [[ -d "$DATA" ]]; then
    echo "→ Removing ${DATA}…"
    rm -rf "$DATA"
    REMOVED=1
  fi
  if [[ -d "$META" ]]; then
    echo "→ Removing ${META}…"
    rm -rf "$META"
    REMOVED=1
  fi
fi

if [[ "$REMOVED" -eq 1 ]]; then
  echo "✅ Hypercluster uninstalled."
else
  echo "Nothing to remove."
fi

if ! $PURGE; then
  echo ""
  echo "App data preserved. To remove clusters registry and license record:"
  echo "  $0 --purge"
fi
