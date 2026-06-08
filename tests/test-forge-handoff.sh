#!/usr/bin/env bash
# Unit tests for forge-handoff JSON emission (no live cluster required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

assert_json_field() {
  local json="$1" field="$2" expected="$3" desc="$4"
  if python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
actual = data
for part in '''$field'''.split('.'):
    if part:
        actual = actual.get(part) if isinstance(actual, dict) else None
assert actual == '''$expected''', (actual, '''$expected''')
" <<< "$json"; then
    echo "  PASS: $desc"
    (( PASS++ )) || true
  else
    echo "  FAIL: $desc" >&2
    (( FAIL++ )) || true
  fi
}

echo "Running forge-handoff tests …"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/forge-handoff.sh"

export CLUSTER_NAME="test-lab"
export K8S_DISTRO="k3s"
export KUBE_VERSION="v1.35.4"
export CONTROL_PLANE_IPS="10.0.0.5"
export WORKER_IPS="10.0.0.6"
export CNI_PLUGIN="cilium"
export PLATFORM_STACK_ENABLED="true"
export CERT_MANAGER_ENABLED="true"
export METALLB_ENABLED="true"
export KUBEVIRT_ENABLED="false"
export METRICS_SERVER_ENABLED="true"
export HC_API_ENDPOINT="https://10.0.0.5:6443"
export HC_KUBECONFIG="/tmp/test-kubeconfig.yaml"
export HC_STACK_FLAGS="platform_stack cilium cert_manager metallb metrics_server"

json="$(forge_handoff::emit_json)"

assert_json_field "$json" "product" "hypercluster" "product is hypercluster"
assert_json_field "$json" "clusterName" "test-lab" "clusterName from env"
assert_json_field "$json" "k8sDistro" "k3s" "k8sDistro from env"
assert_json_field "$json" "apiEndpoint" "https://10.0.0.5:6443" "apiEndpoint from env"
assert_json_field "$json" "forge.provider" "hypercluster" "forge provider"
assert_json_field "$json" "forge.importPath" "/api/k8s/clusters/import/hypercluster" "forge import path"

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
stack = data.get('stackComponents') or []
for item in ['platform_stack', 'cilium', 'cert_manager', 'metallb', 'metrics_server']:
    assert item in stack, stack
profiles = data.get('forge', {}).get('recommendedProfiles') or []
for item in ['velero', 'observability', 'vectorStore']:
    assert item in profiles, profiles
print('  PASS: stackComponents and recommendedProfiles')
" <<< "$json" && (( PASS++ )) || (( FAIL++ ))

# CLI help mentions forge-handoff
if grep -q 'forge-handoff' "$SCRIPT_DIR/hypercluster"; then
  echo "  PASS: hypercluster CLI documents forge-handoff"
  (( PASS++ )) || true
else
  echo "  FAIL: hypercluster CLI missing forge-handoff" >&2
  (( FAIL++ )) || true
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
