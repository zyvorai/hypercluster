#!/usr/bin/env bash
# Remote node CLI tools and kubeconfig helpers for k3s platform deploys.

platform_tools::_first_cp_ip() {
  echo "$CONTROL_PLANE_IPS" | awk '{print $1}'
}

platform_tools::install_remote() {
  local ip ver arch
  ip=$(platform_tools::_first_cp_ip)
  ver="${KUBEVIRT_VERSION:-v1.8.3}"
  log::section "Remote CLI tools on ${SSH_USER}@${ip}"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — skipping remote CLI install."
    return 0
  fi

  # shellcheck disable=SC2029
  k3s::_ssh "$ip" "KV_VER='${ver}' bash -s" <<'REMOTE'
set -euo pipefail
case "$(uname -m)" in
  x86_64)  arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac
export PATH="/usr/local/bin:${PATH}"

if ! command -v kubectl >/dev/null 2>&1; then
  kver=$(curl -fsSL https://dl.k8s.io/release/stable.txt | tr -d '\r\n')
  curl -fsSL "https://dl.k8s.io/release/${kver}/bin/linux/${arch}/kubectl" -o /tmp/kubectl
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
fi

if ! command -v virtctl >/dev/null 2>&1; then
  curl -fsSL "https://github.com/kubevirt/kubevirt/releases/download/${KV_VER}/virtctl-${KV_VER}-linux-${arch}" \
    -o /tmp/virtctl
  sudo install -m 0755 /tmp/virtctl /usr/local/bin/virtctl
  rm -f /tmp/virtctl
fi

sudo tee /usr/local/bin/cluster-info >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
echo "=== Nodes ==="
kubectl get nodes -o wide 2>/dev/null || true
echo ""
echo "=== KubeVirt ==="
kubectl get kv -n kubevirt 2>/dev/null || true
echo ""
echo "=== CDI ==="
kubectl get cdi -n cdi 2>/dev/null || true
echo ""
echo "=== Cilium ==="
kubectl get pods -n kube-system -l app.kubernetes.io/part-of=cilium 2>/dev/null | head -10 || true
SCRIPT
sudo chmod +x /usr/local/bin/cluster-info
REMOTE
  log::ok "Remote CLI tools installed"
}

platform_tools::merge_laptop_kubeconfig() {
  [[ "${KUBECONFIG_MERGE_DEFAULT:-false}" == "true" ]] || return 0
  kubeconfig::merge_into_default
}
