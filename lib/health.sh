#!/usr/bin/env bash
# Unified cluster health report — status, workloads, VMs, optional platform tests.

health::_kubeconfig() {
  echo "${KUBECONFIG_OUTPUT/#\~/$HOME}"
}

health::_json_mode() { [[ "${HC_JSON:-0}" == "1" ]]; }

health::_status_json() {
  local kc="$1"
  KUBECONFIG="$kc" kubectl get nodes -o json 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    print(json.dumps({"ready": 0, "total": 0, "nodes": []}))
    sys.exit(0)
nodes = []
ready = 0
for item in data.get("items", []):
    name = item["metadata"]["name"]
    conds = item.get("status", {}).get("conditions", [])
    is_ready = any(c.get("type") == "Ready" and c.get("status") == "True" for c in conds)
    if is_ready:
        ready += 1
    roles = item["metadata"].get("labels", {}).get("node-role.kubernetes.io/control-plane", "")
    nodes.append({"name": name, "ready": is_ready, "roles": roles or "worker"})
print(json.dumps({"ready": ready, "total": len(nodes), "nodes": nodes}))
'
}

health::emit_json() {
  python3 -c '
import json, sys
cluster = sys.argv[1]
kc = sys.argv[2]
connected = sys.argv[3] == "1"
with_test = sys.argv[4] == "1"
status = json.loads(sys.argv[5])
workloads = json.loads(sys.argv[6])
vms = json.loads(sys.argv[7])
tests = json.loads(sys.argv[8]) if sys.argv[8] else None

pods = workloads.get("pods", [])
running = sum(1 for p in pods if p.get("phase") == "Running")
pending = sum(1 for p in pods if p.get("phase") == "Pending")
failed = sum(
    1 for p in pods
    if p.get("phase") in ("Failed", "Unknown", "Error")
)
vm_list = vms.get("vms", [])
vms_running = sum(1 for v in vm_list if v.get("phase") == "Running")
issues = []

if not connected:
    state = "unreachable"
    issues.append("kubeconfig missing or cluster API unreachable")
else:
    nodes_total = status.get("total", 0)
    nodes_ready = status.get("ready", 0)
    if nodes_total == 0:
        state = "unreachable"
        issues.append("no nodes returned from API")
    elif nodes_ready < nodes_total:
        state = "degraded"
        issues.append(f"{nodes_total - nodes_ready} node(s) not Ready")
    elif failed > 0:
        state = "degraded"
        issues.append(f"{failed} pod(s) failed or unknown")
    elif pending > 0:
        state = "degraded"
        issues.append(f"{pending} pod(s) pending")
    elif tests and tests.get("fail", 0) > 0:
        state = "degraded"
        issues.append(f"{tests['fail']} platform test(s) failed")
    else:
        state = "healthy"

out = {
    "cluster": cluster,
    "connected": connected,
    "state": state,
    "kubeconfig": kc,
    "issues": issues,
    "status": status,
    "workloads": workloads,
    "vms": vms,
    "summary": {
        "nodes_ready": status.get("ready", 0),
        "nodes_total": status.get("total", 0),
        "pods_running": running,
        "pods_total": len(pods),
        "pods_pending": pending,
        "pods_failed": failed,
        "services": len(workloads.get("services", [])),
        "vms_running": vms_running,
        "vms_total": len(vm_list),
    },
    "tests": tests,
}
print(json.dumps(out))
' "$@"
}

health::report_json() {
  local with_test=0 kc cluster_name status_json workloads_json vms_json tests_json=""
  cluster_name="${CLUSTER_NAME:-unknown}"
  for arg in "$@"; do
    case "$arg" in
      --with-test) with_test=1 ;;
    esac
  done

  kc="$(health::_kubeconfig)"
  if [[ ! -f "$kc" ]] || ! command -v kubectl >/dev/null 2>&1; then
    health::emit_json "$cluster_name" "$kc" "0" "$with_test" \
      '{"ready":0,"total":0,"nodes":[]}' \
      '{"pods":[],"services":[]}' \
      '{"vms":[],"templates":[]}' \
      ""
    return 0
  fi

  if ! status_json="$(health::_status_json "$kc")"; then
    status_json='{"ready":0,"total":0,"nodes":[]}'
  fi
  workloads_json="$(workloads::json)"
  vms_json="$(vms::list_json)"

  if [[ "$with_test" == "1" && "${K8S_DISTRO:-kubespray}" == "k3s" ]]; then
    tests_json="$(HC_JSON=1 platform_test::run 2>/dev/null || true)"
  fi

  health::emit_json "$cluster_name" "$kc" "1" "$with_test" \
    "$status_json" "$workloads_json" "$vms_json" "$tests_json"
}

health::run() {
  local json=0 with_test=0
  for arg in "$@"; do
    case "$arg" in
      --json) json=1 ;;
      --with-test) with_test=1 ;;
    esac
  done

  if [[ "$json" == "1" ]]; then
    if [[ "$with_test" == "1" ]]; then
      HC_JSON=1 health::report_json --with-test
    else
      HC_JSON=1 health::report_json
    fi
    return 0
  fi

  log::section "Cluster health: $CLUSTER_NAME"
  local report
  if [[ "$with_test" == "1" ]]; then
    report="$(HC_JSON=1 health::report_json --with-test)"
  else
    report="$(HC_JSON=1 health::report_json)"
  fi
  echo "$report" | python3 -c "
import json, sys
d = json.load(sys.stdin)
state = d.get('state', 'unknown').upper()
print(f'State: {state}')
if d.get('issues'):
    print('Issues:')
    for i in d['issues']:
        print(f'  - {i}')
s = d.get('summary', {})
print(f\"Nodes: {s.get('nodes_ready', 0)}/{s.get('nodes_total', 0)} ready\")
print(f\"Pods: {s.get('pods_running', 0)} running / {s.get('pods_total', 0)} total\")
print(f\"Services: {s.get('services', 0)}\")
print(f\"VMs: {s.get('vms_running', 0)}/{s.get('vms_total', 0)} running\")
tests = d.get('tests')
if tests:
    print(f\"Platform tests: {tests.get('pass', 0)} pass, {tests.get('fail', 0)} fail\")
"
}
