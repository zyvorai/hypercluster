#!/usr/bin/env bash
# Unit test for pip install hint / fallback helpers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HYPERCLUSTER_SCRIPT_DIR="$SCRIPT_DIR"
# shellcheck source=lib/python-pip.sh
source "$SCRIPT_DIR/lib/python-pip.sh"

hint=$(pip::module_install_hint netaddr)
[[ "$hint" == *"pip3 install"* ]] || { echo "FAIL: missing pip3 hint: $hint"; exit 1; }
[[ "$hint" == *"python3 -m pip install"* ]] || { echo "FAIL: missing python3 -m pip hint: $hint"; exit 1; }

if [[ "$(uname)" == "Darwin" ]]; then
  [[ "$hint" == *"setup-macos.sh"* ]] || { echo "FAIL: missing macOS setup hint: $hint"; exit 1; }
fi

echo "  PASS: pip install hint"
echo "python-pip tests passed"
