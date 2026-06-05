#!/usr/bin/env bash
# Unit test for preflight JSON output (no cluster required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/preflight.sh"

PREFLIGHT_CHECKS=(
  "pass:Command ssh:/usr/bin/ssh"
  "fail:SSH connectivity user@1.2.3.4:"
  "pass:MetalLB IP pool:192.168.1.240-192.168.1.250"
)
PREFLIGHT_FAILED=1

out=$(preflight::emit_json)

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert data['ok'] is False, data
assert len(data['checks']) == 3, data
assert data['checks'][0]['name'] == 'Command ssh'
assert data['checks'][0]['passed'] is True
assert data['checks'][0]['detail'] == '/usr/bin/ssh'
assert data['checks'][1]['passed'] is False
print('  PASS: preflight JSON output')
" <<< "$out"

echo "preflight JSON tests passed"
