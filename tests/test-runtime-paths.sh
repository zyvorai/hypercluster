#!/usr/bin/env bash
# Unit tests for lib/runtime-paths.sh (bundled Mac app data dir).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HYPERCLUSTER_SCRIPT_DIR="$SCRIPT_DIR"
# shellcheck source=lib/runtime-paths.sh
source "$SCRIPT_DIR/lib/runtime-paths.sh"

anchor="$(runtime::anchor_dir)"
[[ "$anchor" == "$SCRIPT_DIR" ]] || { echo "FAIL: dev checkout should anchor to repo: $anchor"; exit 1; }
echo "  PASS: dev anchor is repo root"

export HYPERCLUSTER_SCRIPT_DIR="/Applications/Hypercluster.app/Contents/Resources/hypercluster-runtime"
# shellcheck source=lib/runtime-paths.sh
source "$SCRIPT_DIR/lib/runtime-paths.sh"

if [[ "$(uname -s)" == "Darwin" ]]; then
  runtime::bundled_macos_app || { echo "FAIL: should detect bundled runtime"; exit 1; }
  echo "  PASS: bundled runtime detected"
  expected="${HOME}/Library/Application Support/Hypercluster"
  [[ "$(runtime::data_dir)" == "$expected" ]] || {
    echo "FAIL: data dir expected $expected got $(runtime::data_dir)"
    exit 1
  }
  echo "  PASS: bundled data dir"
else
  echo "  SKIP: bundled macOS paths (not Darwin)"
fi

echo "runtime-paths tests passed"
