#!/usr/bin/env bash
# Read-only workload inventory via kubectl — JSON output for Desktop cockpit.

workloads::_kubeconfig() {
  echo "${KUBECONFIG_OUTPUT/#\~/$HOME}"
}

workloads::json() {
  local kc
  kc="$(workloads::_kubeconfig)"
  if [[ ! -f "$kc" ]] || ! command -v kubectl >/dev/null 2>&1; then
    echo '{"pods":[],"services":[]}'
    return 0
  fi
  KUBECONFIG="$kc" kubectl get pods,svc -A -o json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    data = {'items': []}
pods, services = [], []
for item in data.get('items', []):
    kind = item.get('kind', '')
    meta = item.get('metadata', {})
    status = item.get('status', {})
    ns = meta.get('namespace', 'default')
    name = meta.get('name', '')
    if kind == 'Pod':
        pods.append({
            'namespace': ns,
            'name': name,
            'phase': status.get('phase', 'Unknown'),
            'node': status.get('hostIP', '') or (status.get('podIP', '') or ''),
            'ready': sum(1 for c in (status.get('containerStatuses') or []) if c.get('ready')),
            'containers': len(status.get('containerStatuses') or []),
        })
    elif kind == 'Service':
        spec = item.get('spec', {})
        services.append({
            'namespace': ns,
            'name': name,
            'type': spec.get('type', 'ClusterIP'),
            'clusterIp': spec.get('clusterIP', ''),
        })
print(json.dumps({'pods': pods, 'services': services}))
"
}
