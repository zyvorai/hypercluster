#!/usr/bin/env bash
# Generate Tauri app icons from desktop/src/assets/brand/app-icon.svg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICON="${ROOT}/desktop/src/assets/brand/app-icon.svg"
OUT="${ROOT}/desktop/src-tauri/icons"

[[ -f "$ICON" ]] || { echo "ERROR: missing $ICON" >&2; exit 1; }

echo "→ Generating Hypercluster Desktop icons from app-icon.svg…"
(cd "${ROOT}/desktop" && npx tauri icon "$ICON" -o src-tauri/icons)

echo "✅ Icons written to ${OUT}"
