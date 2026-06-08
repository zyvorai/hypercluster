#!/usr/bin/env bash
# Unit tests for lib/python-resolve.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HYPERCLUSTER_SCRIPT_DIR="$SCRIPT_DIR"
# shellcheck source=lib/python-resolve.sh
source "$SCRIPT_DIR/lib/python-resolve.sh"

py="$(python::resolve 2>/dev/null || true)"
if [[ -n "$py" ]]; then
  if ! "$py" -c 'import sys; assert sys.version_info >= (3, 11)'; then
    echo "FAIL: resolved python too old: $py" >&2
    exit 1
  fi
  echo "  PASS: python::resolve -> $py"
else
  echo "  SKIP: no Python 3.11+ on PATH (expected in CI without brew python)"
fi

bin="$(python::bin)"
[[ -n "$bin" ]] || { echo "FAIL: python::bin empty"; exit 1; }
echo "  PASS: python::bin -> $bin"

python::configure_path
[[ -n "${HYPERCLUSTER_PYTHON:-}" ]] || [[ "$bin" == "python3" ]] || {
  echo "FAIL: configure_path did not set HYPERCLUSTER_PYTHON"
  exit 1
}
echo "  PASS: python::configure_path"

echo "python-resolve tests passed"
