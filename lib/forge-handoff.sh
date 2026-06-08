#!/usr/bin/env bash
# Forge Day-2 handoff payload — JSON for forge import after hypercluster deploy.

forge_handoff::_first_cp_ip() {
  echo "${CONTROL_PLANE_IPS:-}" | awk '{print $1}'
}

forge_handoff::_api_endpoint() {
  local ip
  ip="$(forge_handoff::_first_cp_ip)"
  [[ -n "$ip" ]] && echo "https://${ip}:6443"
}

forge_handoff::_stack_flags() {
  local flags=()
  [[ "${PLATFORM_STACK_ENABLED:-false}" == "true" ]] && flags+=("platform_stack")
  [[ "${CNI_PLUGIN:-}" == "cilium" || "${K8S_DISTRO:-}" == "k3s" ]] && flags+=("cilium")
  [[ "${CERT_MANAGER_ENABLED:-false}" == "true" ]] && flags+=("cert_manager")
  [[ "${METALLB_ENABLED:-false}" == "true" ]] && flags+=("metallb")
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] && flags+=("kubevirt")
  [[ "${GPU_OPERATOR_ENABLED:-false}" == "true" ]] && flags+=("gpu_operator")
  [[ "${METRICS_SERVER_ENABLED:-true}" == "true" ]] && flags+=("metrics_server")
  printf '%s' "${flags[*]}"
}

forge_handoff::emit_json() {
  export HC_API_ENDPOINT="${HC_API_ENDPOINT:-$(forge_handoff::_api_endpoint)}"
  export HC_KUBECONFIG="${HC_KUBECONFIG:-$(postdeploy::_kc 2>/dev/null || echo "${KUBECONFIG_OUTPUT/#\~/$HOME}")}"
  export HC_STACK_FLAGS="${HC_STACK_FLAGS:-$(forge_handoff::_stack_flags)}"
  CLUSTER_NAME="${CLUSTER_NAME:-}" K8S_DISTRO="${K8S_DISTRO:-kubespray}" \
  KUBE_VERSION="${KUBE_VERSION:-}" CONTROL_PLANE_IPS="${CONTROL_PLANE_IPS:-}" \
  WORKER_IPS="${WORKER_IPS:-}" CNI_PLUGIN="${CNI_PLUGIN:-}" \
  PLATFORM_STACK_ENABLED="${PLATFORM_STACK_ENABLED:-false}" \
  python3 <<'PY'
import json, os
print(json.dumps({
    "product": "hypercluster",
    "clusterName": os.environ.get("CLUSTER_NAME", ""),
    "k8sDistro": os.environ.get("K8S_DISTRO", "kubespray"),
    "kubeVersion": os.environ.get("KUBE_VERSION", ""),
    "apiEndpoint": os.environ.get("HC_API_ENDPOINT", ""),
    "kubeconfigPath": os.environ.get("HC_KUBECONFIG", ""),
    "controlPlaneIps": [x for x in (os.environ.get("CONTROL_PLANE_IPS") or "").split() if x],
    "workerIps": [x for x in (os.environ.get("WORKER_IPS") or "").split() if x],
    "cniPlugin": os.environ.get("CNI_PLUGIN", ""),
    "platformStack": os.environ.get("PLATFORM_STACK_ENABLED", "false") == "true",
    "stackComponents": [x for x in (os.environ.get("HC_STACK_FLAGS") or "").split() if x],
    "forge": {
        "provider": "hypercluster",
        "importPath": "/api/k8s/clusters/import/hypercluster",
        "guide": "docs/guides/zyvor-platform-stack.md",
        "recommendedProfiles": ["velero", "observability", "vectorStore"],
    },
}, indent=2))
PY
}

forge_handoff::run() {
  local json_mode=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode=1; shift ;;
      *) shift ;;
    esac
  done

  export HC_API_ENDPOINT="$(forge_handoff::_api_endpoint)"
  export HC_KUBECONFIG="$(postdeploy::_kc 2>/dev/null || echo "${KUBECONFIG_OUTPUT/#\~/$HOME}")"
  export HC_STACK_FLAGS="$(forge_handoff::_stack_flags)"

  if [[ "$json_mode" == "1" ]]; then
    forge_handoff::emit_json
    return 0
  fi

  log::section "Forge handoff (Day 2)"
  echo ""
  printf "  Cluster: %s (%s)\n" "${CLUSTER_NAME:-}" "${K8S_DISTRO:-kubespray}"
  printf "  API:     %s\n" "$HC_API_ENDPOINT"
  printf "  Config:  %s\n" "$HC_KUBECONFIG"
  echo ""
  printf "  JSON for Forge import:\n"
  printf "    ./hypercluster -c %s forge-handoff --json\n" "${CONFIG_FILE:-./cluster.conf}"
  echo ""
  printf "  Forge repo (from laptop with forge checkout):\n"
  printf "    ./scripts/lib/hypercluster-handoff.sh --kubeconfig %s --name %s\n" "$HC_KUBECONFIG" "${CLUSTER_NAME:-mycluster}"
  echo ""
  printf "  Docs: docs/guides/zyvor-platform-stack.md\n"
  echo ""
}
