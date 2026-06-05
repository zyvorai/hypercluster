#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/hypercluster"
chmod +x "$HC"

out="$("$HC" -c "$ROOT/config/cluster.conf.example" vms --json)"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "templates" in d
assert len(d["templates"]) >= 4
assert "vms" in d
print("vms json ok")
'
