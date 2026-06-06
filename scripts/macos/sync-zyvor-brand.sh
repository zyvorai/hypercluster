#!/usr/bin/env bash
# Sync Zyvor brand assets from hypersdk-web into Hypercluster Desktop.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${HYPERSDK_WEB:-${ROOT}/../hypersdk-web}/static/img"
DESK="${ROOT}/desktop"

if [[ ! -d "$SRC" ]]; then
  echo "ERROR: hypersdk-web assets not found at $SRC" >&2
  echo "Set HYPERSDK_WEB to the hypersdk-web repo root." >&2
  exit 1
fi

mkdir -p "${DESK}/public/brand" "${DESK}/src/assets/brand"

for f in zavor-logo.webp zavor-favicon.png zavor-favicon.svg; do
  if [[ -f "${SRC}/${f}" ]]; then
    cp "${SRC}/${f}" "${DESK}/public/brand/${f}"
    cp "${SRC}/${f}" "${DESK}/src/assets/brand/${f}"
    echo "  synced ${f}"
  fi
done

echo "✅ Zyvor brand assets synced from ${SRC}"
