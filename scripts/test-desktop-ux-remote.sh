#!/usr/bin/env bash
# End-to-end UX smoke: hypercluster CLI JSON surfaces + remote libvirt/machina host.
# Usage: ./scripts/test-desktop-ux-remote.sh [cluster.conf]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HC="$ROOT/hypercluster"
CONF="${1:-$ROOT/cluster.conf}"
REMOTE="${REMOTE_HOST:-sus@175.110.114.93}"
TMP="${TMPDIR:-/tmp}/hc-ux-smoke-$$"
PASS=0
FAIL=0

mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

ok() { echo "  ✅ $*"; PASS=$((PASS + 1)); }
bad() { echo "  ❌ $*"; FAIL=$((FAIL + 1)); }

run_json() {
  local label="$1"
  shift
  if "$@" >"$TMP/out.json" 2>"$TMP/err.txt"; then
    if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$TMP/out.json" 2>/dev/null; then
      ok "$label"
    else
      bad "${label}: invalid JSON"
      head -3 "$TMP/out.json" >&2 || true
    fi
  else
    bad "${label}: command failed"
    head -3 "$TMP/err.txt" >&2 || true
  fi
}

chmod +x "$HC"

echo "=== Hypercluster desktop UX smoke ==="
echo "Config: $CONF"
echo "Remote: $REMOTE"
echo ""

echo "→ Local CLI JSON surfaces"
run_json "status --json" "$HC" -c "$CONF" status --json
run_json "vms --json" "$HC" -c "$CONF" vms --json
run_json "workloads --json" "$HC" -c "$CONF" workloads --json

if "$HC" -c "$CONF" vm create --template ubuntu-22.04 --name ux-smoke --json >"$TMP/out.json" 2>"$TMP/err.txt"; then
  if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("status")=="stub"' "$TMP/out.json" 2>/dev/null; then
    ok "vm create --json stub validated"
  else
    bad "vm create --json: unexpected payload"
  fi
else
  bad "vm create --json"
fi

if "$HC" -c "$CONF" preflight >"$TMP/out.txt" 2>"$TMP/err.txt"; then
  if grep -q 'Preflight passed' "$TMP/out.txt"; then
    ok "preflight"
  else
    bad "preflight: no pass message"
  fi
else
  bad "preflight: command failed"
fi

echo ""
echo "→ Remote machina / libvirt host ($REMOTE)"
if ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE" 'curl -sk https://localhost:5092/api/v1/health' | grep -q healthy; then
  ok "machina daemon healthy"
else
  bad "machina daemon health"
fi

if ssh -o BatchMode=yes "$REMOTE" 'sudo virsh list --name 2>/dev/null | grep -q .'; then
  ok "libvirt VMs present"
else
  bad "no libvirt VMs on remote"
fi

ssh -o BatchMode=yes "$REMOTE" 'sudo virsh list --name' >"$TMP/vms.txt" || true
discover_count=0
while IFS= read -r vm_name; do
  [[ -n "$vm_name" ]] || continue
  ip="$(ssh -o BatchMode=yes "$REMOTE" "sudo virsh domifaddr '$vm_name' --source lease 2>/dev/null | awk '/ipv4/ {print \$4; exit}' | cut -d/ -f1" || true)"
  if [[ -n "$ip" ]]; then
    discover_count=$((discover_count + 1))
  fi
done <"$TMP/vms.txt"

if [[ "$discover_count" -ge 1 ]]; then
  ok "libvirt discover found $discover_count VM(s) with lease IP"
else
  bad "libvirt discover found no lease IPs"
fi

echo ""
echo "→ Desktop build checks"
if (cd "$ROOT/desktop" && npm run build >"$TMP/build.log" 2>&1); then
  ok "desktop npm build"
else
  bad "desktop npm build"
  tail -5 "$TMP/build.log" >&2 || true
fi

if (cd "$ROOT/desktop/src-tauri" && cargo check -q >"$TMP/cargo.log" 2>&1); then
  ok "desktop cargo check"
else
  bad "desktop cargo check"
  tail -5 "$TMP/cargo.log" >&2 || true
fi

if (cd "$ROOT/desktop" && npx --yes tsx scripts/test-spec-roundtrip.ts >"$TMP/rt.log" 2>&1); then
  ok "ClusterSpec roundtrip"
else
  bad "ClusterSpec roundtrip"
fi

echo ""
echo "UX smoke: ${PASS} passed, ${FAIL} failed"
[[ "$FAIL" -eq 0 ]]
