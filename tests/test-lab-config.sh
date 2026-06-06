#!/usr/bin/env bash
# Unit tests for lab ops config and library presence.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

assert_contains() {
  local file="$1" pattern="$2" desc="$3"
  if grep -q "$pattern" "$file"; then
    echo "  PASS: $desc"
    (( PASS++ )) || true
  else
    echo "  FAIL: $desc (pattern '$pattern' not in $file)" >&2
    (( FAIL++ )) || true
  fi
}

echo "Running lab config tests …"

assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'LAB_SECONDARY_DISK=' "example has LAB_SECONDARY_DISK"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'LAB_AUTO_SETUP=' "example has LAB_AUTO_SETUP"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'LAB_MEMORY_TUNE_ENABLED=' "example has LAB_MEMORY_TUNE_ENABLED"
assert_contains "$SCRIPT_DIR/lib/lab.sh" 'lab::storage_setup' "lib/lab.sh defines storage setup"
assert_contains "$SCRIPT_DIR/lib/lab.sh" 'lab::memory_tune' "lib/lab.sh defines memory tune"
assert_contains "$SCRIPT_DIR/hypercluster" 'lab setup' "hypercluster help mentions lab setup"
assert_contains "$SCRIPT_DIR/hypercluster" 'cmd_lab' "hypercluster dispatches lab command"
assert_contains "$SCRIPT_DIR/config/manifests/lab/kubevirt-sdb-storageclass.yaml" 'name: kubevirt-sdb' "kubevirt-sdb manifest present"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
