#!/usr/bin/env bash
# Verify Hypercluster.app is arm64 (not Intel) before packaging.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=arch-check.sh
source "${ROOT}/scripts/macos/arch-check.sh"

APP="${1:-${ROOT}/desktop/src-tauri/target/release/bundle/macos/Hypercluster.app}"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: App not found: $APP" >&2
  exit 1
fi

hc_macos_require_arm64_app "$APP"
echo "✓ arm64 app OK: $(hc_macos_app_binary_arch "$APP")"
