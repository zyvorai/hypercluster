#!/usr/bin/env bash
# Unit test for platform_test JSON output (no cluster required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/platform-test.sh"

PLATFORM_TEST_PASS=2
PLATFORM_TEST_FAIL=1
PLATFORM_TEST_CHECKS=("pass:Alpha check" "fail:Beta check" "pass:Gamma check")

out=$(platform_test::emit_json)

python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
assert data['pass'] == 2, data
assert data['fail'] == 1, data
assert len(data['checks']) == 3, data
assert data['checks'][0]['name'] == 'Alpha check'
assert data['checks'][0]['passed'] is True
assert data['checks'][1]['passed'] is False
print('  PASS: platform_test JSON output')
" <<< "$out"

echo "platform_test JSON tests passed"
