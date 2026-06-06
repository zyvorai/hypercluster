#!/usr/bin/env bash
# Unit test for health JSON output (no live cluster required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/workloads.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/vms.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/platform-test.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/health.sh"

export CLUSTER_NAME="fixture-lab"
export KUBECONFIG_OUTPUT="/tmp/nonexistent-kubeconfig-for-health-test.yaml"

out=$(HC_JSON=1 health::report_json)

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert data['cluster'] == 'fixture-lab', data
assert data['connected'] is False, data
assert data['state'] == 'unreachable', data
assert 'kubeconfig' in data, data
assert data['summary']['pods_total'] == 0, data
assert data['tests'] is None, data
print('  PASS: health unreachable JSON')
" <<< "$out"

out2=$(health::emit_json "ok-cluster" "/tmp/kc.yaml" "1" "0" \
  '{"ready":2,"total":2,"nodes":[]}' \
  '{"pods":[{"namespace":"default","name":"a","phase":"Running"}],"services":[{"namespace":"default","name":"svc","type":"ClusterIP"}]}' \
  '{"vms":[],"templates":[]}' \
  "")

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert data['state'] == 'healthy', data
assert data['summary']['pods_running'] == 1, data
assert data['summary']['services'] == 1, data
print('  PASS: health healthy JSON')
" <<< "$out2"

out3=$(health::emit_json "bad-cluster" "/tmp/kc.yaml" "1" "0" \
  '{"ready":1,"total":2,"nodes":[]}' \
  '{"pods":[{"namespace":"default","name":"bad","phase":"Failed"}],"services":[]}' \
  '{"vms":[],"templates":[]}' \
  '{"pass":10,"fail":1,"checks":[{"name":"x","passed":false}]}')

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert data['state'] == 'degraded', data
assert len(data['issues']) >= 1, data
print('  PASS: health degraded JSON')
" <<< "$out3"

echo "health JSON tests passed"
