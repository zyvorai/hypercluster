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

export HYPERCLUSTER_SCRIPT_DIR="$SCRIPT_DIR"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/platform-stack.sh"

# Cilium values generation — defaults
KUBE_PODS_SUBNET="10.42.0.0/16"
CILIUM_K8S_SERVICE_HOST="127.0.0.1"
unset CILIUM_KUBE_PROXY_REPLACEMENT CILIUM_HUBBLE_ENABLED CILIUM_BGP_ENABLED
unset CILIUM_GATEWAY_API_ENABLED CILIUM_WIREGUARD_ENABLED

out="$TMPDIR/cilium-values-default.yaml"
platform::_gen_cilium_values "$out"
assert_contains "$out" "kubevirt:" "cilium values has kubevirt block"
assert_contains "$out" "10.42.0.0/16" "cilium values has pod CIDR"
assert_contains "$out" "127.0.0.1" "cilium values has k8s service host"
assert_contains "$out" "kubeProxyReplacement: true" "default kube-proxy replacement enabled"
assert_contains "$out" "enabled: true" "default hubble enabled"

# Hubble disabled
CILIUM_HUBBLE_ENABLED="false"
out="$TMPDIR/cilium-values-no-hubble.yaml"
platform::_gen_cilium_values "$out"
assert_contains "$out" "enabled: false" "hubble disabled when CILIUM_HUBBLE_ENABLED=false"
unset CILIUM_HUBBLE_ENABLED

# BGP disabled (default)
out="$TMPDIR/cilium-values-no-bgp.yaml"
platform::_gen_cilium_values "$out"
assert_contains "$out" "bgpControlPlane:" "cilium values has bgp block"
assert_contains "$out" "  enabled: false" "bgp disabled by default"

# Gateway API disabled (default)
out="$TMPDIR/cilium-values-no-gateway.yaml"
platform::_gen_cilium_values "$out"
grep -A1 'gatewayAPI:' "$out" | grep -q 'enabled: false' && {
  echo "  PASS: gateway API disabled by default"
  (( PASS++ )) || true
} || {
  echo "  FAIL: gateway API disabled by default" >&2
  (( FAIL++ )) || true
}

# Explicit toggles on
CILIUM_BGP_ENABLED="true"
CILIUM_GATEWAY_API_ENABLED="true"
CILIUM_WIREGUARD_ENABLED="true"
out="$TMPDIR/cilium-values-all-on.yaml"
platform::_gen_cilium_values "$out"
assert_contains "$out" "bgpControlPlane:" "cilium values has bgp when enabled"
grep -A1 'bgpControlPlane:' "$out" | grep -q 'enabled: true' && {
  echo "  PASS: bgp enabled when CILIUM_BGP_ENABLED=true"
  (( PASS++ )) || true
} || {
  echo "  FAIL: bgp enabled when CILIUM_BGP_ENABLED=true" >&2
  (( FAIL++ )) || true
}
grep -A1 'encryption:' "$out" | grep -q 'enabled: true' && {
  echo "  PASS: encryption enabled when CILIUM_WIREGUARD_ENABLED=true"
  (( PASS++ )) || true
} || {
  echo "  FAIL: encryption enabled when CILIUM_WIREGUARD_ENABLED=true" >&2
  (( FAIL++ )) || true
}

# cluster.conf.example k3s vars present
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'K8S_DISTRO=' "example has K8S_DISTRO"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'METALLB_IP_POOL=' "example has METALLB_IP_POOL"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'PLATFORM_STACK_ENABLED=' "example has PLATFORM_STACK_ENABLED"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'disable-kube-proxy' "example disables kube-proxy for Cilium"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'CILIUM_KUBE_PROXY_REPLACEMENT=' "example has CILIUM_KUBE_PROXY_REPLACEMENT"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'CILIUM_BGP_ENABLED=' "example has CILIUM_BGP_ENABLED"
assert_contains "$SCRIPT_DIR/config/cluster.conf.example" 'CILIUM_GATEWAY_API_ENABLED=' "example has CILIUM_GATEWAY_API_ENABLED"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
