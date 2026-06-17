#!/usr/bin/env bash
# End-to-end smoke tests for k3s platform stack.

platform_test::_kc() {
  echo "${KUBECONFIG_OUTPUT/#\~/$HOME}"
}

platform_test::_export_kc() {
  export KUBECONFIG
  KUBECONFIG="$(platform_test::_kc)"
  [[ -f "$KUBECONFIG" ]] || die "kubeconfig not found: $KUBECONFIG — run deploy first"
}

platform_test::_json_mode() { [[ "${HC_JSON:-0}" == "1" ]]; }

platform_test::_pass() {
  if platform_test::_json_mode; then
    echo "  PASS: $*" >&2
  else
    echo "  PASS: $*"
  fi
  PLATFORM_TEST_PASS=$(( PLATFORM_TEST_PASS + 1 ))
  PLATFORM_TEST_CHECKS+=("pass:$*")
}
platform_test::_fail() { echo "  FAIL: $*" >&2; PLATFORM_TEST_FAIL=$(( PLATFORM_TEST_FAIL + 1 )); PLATFORM_TEST_CHECKS+=("fail:$*"); }

platform_test::_check() {
  local desc="$1"
  shift
  if "$@"; then
    platform_test::_pass "$desc"
  else
    platform_test::_fail "$desc"
  fi
}

platform_test::run() {
  local full="${1:-}"
  PLATFORM_TEST_PASS=0
  PLATFORM_TEST_FAIL=0
  PLATFORM_TEST_CHECKS=()
  platform_test::_export_kc

  if platform_test::_json_mode; then
    exec 3>&1
    exec 1>&2
  fi

  log::section "Platform smoke tests"

  platform_test::_check "All nodes Ready" \
    kubectl wait --for=condition=Ready node --all --timeout=120s

  platform_test::_check "Node count matches cluster.conf" platform_test::_node_count_match

  if [[ "${CNI_PLUGIN:-cilium}" == "cilium" ]]; then
    if command -v cilium &>/dev/null; then
      platform_test::_check "Cilium healthy" platform_test::_cilium_healthy
    else
      platform_test::_check "Cilium pods Running" \
        bash -c 'out=$(kubectl get pods -n kube-system -l app.kubernetes.io/part-of=cilium --no-headers 2>/dev/null); [[ -n "$out" ]] && ! echo "$out" | awk "{print \$3}" | grep -qv Running'
    fi
  fi

  if [[ "${CERT_MANAGER_ENABLED:-true}" == "true" ]]; then
    platform_test::_check "cert-manager pods Running" \
      bash -c 'kubectl get ns cert-manager &>/dev/null && out=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null); [[ -n "$out" ]] && ! echo "$out" | awk "{print \$3}" | grep -qvE "Running|Completed"'
  fi

  if [[ "${METALLB_ENABLED:-true}" == "true" ]]; then
    platform_test::_check "MetalLB controller Running" \
      bash -c 'kubectl get ns metallb-system &>/dev/null && kubectl get pods -n metallb-system --no-headers 2>/dev/null | grep -q Running'
    platform_test::_check "MetalLB IPAddressPool exists" \
      kubectl get ipaddresspool -n metallb-system default &>/dev/null
  fi

  if [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    platform_test::_check "KubeVirt Available" \
      bash -c 'kubectl -n kubevirt get kv kubevirt -o jsonpath="{.status.phase}" 2>/dev/null | grep -qE "Deployed|Available"'
    if [[ "${CDI_ENABLED:-true}" == "true" ]]; then
      platform_test::_check "CDI Available" \
        bash -c 'kubectl -n cdi get cdi cdi -o jsonpath="{.status.phase}" 2>/dev/null | grep -q Deployed'
    fi
    platform_test::_check "VirtualMachineSnapshot API" \
      kubectl api-resources 2>/dev/null | grep -q VirtualMachineSnapshot
  fi

  if [[ "${METRICS_SERVER_ENABLED:-true}" == "true" ]]; then
    platform_test::_check "metrics-server (kubectl top nodes)" \
      bash -c 'timeout 45 kubectl top nodes &>/dev/null'
  fi

  if [[ "${LONGHORN_ENABLED:-false}" == "true" ]]; then
    platform_test::_check "Longhorn pods Running" \
      bash -c 'kubectl get ns longhorn-system &>/dev/null && out=$(kubectl get pods -n longhorn-system --no-headers 2>/dev/null); [[ -n "$out" ]] && ! echo "$out" | awk "{print \$3}" | grep -qvE "Running|Completed"'
  fi

  if [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    platform_test::_check "VM smoke (cirros)" platform_test::_vm_smoke
  fi

  platform_test::_check "Remote SSH kubectl" platform_test::_remote_kubectl

  if [[ "$full" == "--full" && "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    platform_test::_check "VolumeSnapshot API" \
      kubectl api-resources 2>/dev/null | grep -q volumesnapshots
  fi

  echo ""
  log::section "Test results: ${PLATFORM_TEST_PASS} passed, ${PLATFORM_TEST_FAIL} failed"
  if platform_test::_json_mode; then
    exec 1>&3
    exec 3>&-
    platform_test::emit_json
    [[ "$PLATFORM_TEST_FAIL" -eq 0 ]] || exit 1
    return 0
  fi
  [[ "$PLATFORM_TEST_FAIL" -eq 0 ]] || die "Platform tests failed."
  log::ok "All platform tests passed ✅"
}

platform_test::emit_json() {
  CHECKS="$(printf '%s\n' "${PLATFORM_TEST_CHECKS[@]}")" \
    PASS="$PLATFORM_TEST_PASS" \
    FAIL="$PLATFORM_TEST_FAIL" \
    python3 <<'PY'
import json, os
checks = []
for line in os.environ.get("CHECKS", "").splitlines():
    if not line:
        continue
    status, desc = line.split(":", 1)
    checks.append({"name": desc, "passed": status == "pass"})
print(json.dumps({"pass": int(os.environ["PASS"]), "fail": int(os.environ["FAIL"]), "checks": checks}))
PY
}

platform_test::_vm_smoke() {
  kubectl apply -f - <<'YAML'
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: hc-smoke-testvm
  namespace: default
spec:
  runStrategy: Always
  template:
    metadata:
      labels:
        kubevirt.io/vm: hc-smoke-testvm
    spec:
      domain:
        devices:
          disks:
            - name: containerdisk
              disk:
                bus: virtio
          interfaces:
            - name: default
              masquerade: {}
        resources:
          requests:
            memory: 512Mi
      networks:
        - name: default
          pod: {}
      volumes:
        - name: containerdisk
          containerDisk:
            image: quay.io/kubevirt/cirros-container-disk-demo
YAML
  kubectl wait --for=condition=Ready vm/hc-smoke-testvm --timeout=180s
  kubectl delete vm hc-smoke-testvm --wait=true
}

platform_test::_cilium_pods_running() {
  local out
  out=$(kubectl get pods -n kube-system -l app.kubernetes.io/part-of=cilium --no-headers 2>/dev/null) || return 1
  [[ -n "$out" ]] || return 1
  ! echo "$out" | awk '{print $3}' | grep -qv Running
}

platform_test::_cilium_healthy() {
  if timeout 4m cilium status --wait --wait-duration 3m --ignore-warnings >/dev/null 2>&1; then
    return 0
  fi
  log::warn "cilium status --wait timed out or reported errors — falling back to Cilium pod check"
  platform_test::_cilium_pods_running
}

platform_test::_node_count_match() {
  local expected=0 actual
  expected=$(( $(echo "$CONTROL_PLANE_IPS" | wc -w | tr -d ' ') + $(echo "$WORKER_IPS" | wc -w | tr -d ' ') ))
  [[ "$expected" -gt 0 ]] || return 0
  actual=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [[ "$actual" -eq "$expected" ]]
}

platform_test::_remote_kubectl() {
  local ip key opts out
  ip=$(echo "$CONTROL_PLANE_IPS" | awk '{print $1}')
  key="${SSH_KEY/#\~/$HOME}"
  opts=(-i "$key" -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)
  [[ -n "${SSH_PORT:-}" && "${SSH_PORT}" != "22" ]] && opts+=(-p "$SSH_PORT")
  [[ -n "${SSH_EXTRA_ARGS:-}" ]] && opts+=(${SSH_EXTRA_ARGS})
  # shellcheck disable=SC2029
  out=$(timeout 30 ssh "${opts[@]}" "$SSH_USER@$ip" bash -s <<'REMOTE'
set -euo pipefail
if [[ -f "$HOME/.kube/config" ]]; then
  export KUBECONFIG="$HOME/.kube/config"
  kubectl get nodes --no-headers
elif command -v k3s >/dev/null 2>&1; then
  sudo /usr/local/bin/k3s kubectl get nodes --no-headers
else
  exit 1
fi
REMOTE
  ) || return 1
  echo "$out" | grep -q Ready
}
