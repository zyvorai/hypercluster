#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/hypercluster"
chmod +x "$HC"

out="$("$HC" -c "$ROOT/config/cluster.conf.example" workloads --json)"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "pods" in d
assert "services" in d
print("workloads json ok")
'

out2="$("$HC" -c "$ROOT/config/cluster.conf.example" vm create --template ubuntu-22.04 --name test-vm --json)"
echo "$out2" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d.get("status") in ("stub", "error")
print("vm create json ok")
'
