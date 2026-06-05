#!/usr/bin/env bash
# VM inventory and KubeVirt template catalog — JSON output

vms::_kubeconfig() {
  echo "${KUBECONFIG_OUTPUT/#\~/$HOME}"
}

vms::_catalog_path() {
  echo "${HYPERCLUSTER_SCRIPT_DIR}/config/kubevirt-templates.json"
}

vms::list_json() {
  local kc catalog
  kc="$(vms::_kubeconfig)"
  catalog="$(vms::_catalog_path)"
  if [[ ! -f "$catalog" ]]; then
    echo '{"vms":[],"templates":[]}'
    return 0
  fi
  if [[ ! -f "$kc" ]] || ! command -v kubectl >/dev/null 2>&1; then
    python3 - <<PY
import json
with open("$catalog") as f:
    cat = json.load(f)
print(json.dumps({"vms": [], "templates": cat.get("templates", [])}))
PY
    return 0
  fi
  KUBECONFIG="$kc" kubectl get virtualmachineinstance -A -o json 2>/dev/null | python3 -c "
import json, sys
with open('$catalog') as f:
    cat = json.load(f)
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    data = {'items': []}
vms = []
for item in data.get('items', []):
    meta = item.get('metadata', {})
    status = item.get('status', {})
    ip = ''
    for iface in status.get('interfaces', []) or []:
        if iface.get('ipAddress'):
            ip = iface['ipAddress']
            break
    vms.append({
        'name': meta.get('name', ''),
        'namespace': meta.get('namespace', 'default'),
        'phase': status.get('phase', 'Unknown'),
        'node': status.get('nodeName', ''),
        'ip': ip,
    })
print(json.dumps({'vms': vms, 'templates': cat.get('templates', [])}))
"
}

vms::create_json() {
  local template="${1:-}" name="${2:-}" namespace="${3:-default}"
  if [[ -z "$template" || -z "$name" ]]; then
    echo '{"status":"error","message":"--template and --name are required"}'
    return 1
  fi
  local kc catalog
  kc="$(vms::_kubeconfig)"
  catalog="$(vms::_catalog_path)"
  python3 - <<PY
import json
with open("$catalog") as f:
    cat = json.load(f)
templates = {t["id"]: t for t in cat.get("templates", [])}
tpl = templates.get("$template")
if not tpl:
    print(json.dumps({"status":"error","message":"Unknown template: $template"}))
    raise SystemExit(1)
print(json.dumps({
    "status": "stub",
    "message": "VM create from template is not yet implemented — catalog entry validated",
    "template": tpl,
    "name": "$name",
    "namespace": "$namespace",
    "kubeconfig": "$kc",
}))
PY
}
