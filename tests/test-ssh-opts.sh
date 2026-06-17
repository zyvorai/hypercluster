#!/usr/bin/env bash
# Unit tests for lib/ssh.sh option building.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/ssh.sh"

export SSH_KEY="/tmp/test-key"
export SSH_PROXY_JUMP="user@jump"
export SSH_EXTRA_ARGS="-o StrictHostKeyChecking=accept-new -o ProxyJump=ignored@jump"

opts=()
ssh::node_opts opts "$SSH_KEY" 22

OPTS_JSON="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${opts[@]}")"
export OPTS_JSON
python3 -c "
import json, os
opts = json.loads(os.environ['OPTS_JSON'])
joined = ' '.join(opts)
assert joined.count('ProxyJump=') == 1, joined
assert 'ProxyJump=user@jump' in joined, joined
assert 'ignored@jump' not in joined, joined
assert 'StrictHostKeyChecking=accept-new' in joined, joined
print('  PASS: ssh::node_opts dedupes ProxyJump')
"

unset SSH_PROXY_JUMP
export SSH_EXTRA_ARGS="-o StrictHostKeyChecking=accept-new -o ProxyJump=only@jump"
opts=()
ssh::node_opts opts "$SSH_KEY" 22
OPTS_JSON="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "${opts[@]}")"
export OPTS_JSON
python3 -c "
import json, os
opts = json.loads(os.environ['OPTS_JSON'])
joined = ' '.join(opts)
assert 'ProxyJump=only@jump' in joined, joined
print('  PASS: ssh::node_opts uses ProxyJump from SSH_EXTRA_ARGS')
"

echo "ssh opts tests passed"
