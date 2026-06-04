#!/usr/bin/env bash
# Unit tests for k3s platform config generation (no cluster required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}/hypercluster-platform-test-$$"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

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

echo "Running platform config tests …"
mkdir -p "$TMPDIR"

# Cilium values generation
KUBE_PODS_SUBNET="10.42.0.0/16"
CILIUM_K8S_SERVICE_HOST="127.0.0.1"
export HYPERCLUSTER_SCRIPT_DIR="$SCRIPT_DIR"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/platform-stack.sh"

out="$TMPDIR/cilium-values.yaml"
platform::_gen_cilium_values "$out"
assert_contains "$out" "kubevirt:" "cilium values has kubevirt block"
assert_contains "$out" "10.42.0.0/16" "cilium values has pod CIDR"
assert_contains "$out" "127.0.0.1" "cilium values has k8s service host"

# cluster.conf.example k3s vars present
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'K8S_DISTRO=' "example has K8S_DISTRO"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'METALLB_IP_POOL=' "example has METALLB_IP_POOL"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'PLATFORM_STACK_ENABLED=' "example has PLATFORM_STACK_ENABLED"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'disable-kube-proxy' "example disables kube-proxy for Cilium"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
