#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/hypercluster"
chmod +x "$HC"

out="$("$HC" discover --json --source csv --csv "$ROOT/tests/fixtures/discover-nodes.csv")"
echo "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert "nodes" in d
assert len(d["nodes"]) >= 2
assert d["nodes"][0]["source"] == "csv"
print("discover json ok")
'
