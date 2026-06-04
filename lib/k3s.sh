#!/usr/bin/env bash
# k3s cluster deployment over SSH — source this file.

k3s::_key() { echo "${SSH_KEY/#\~/$HOME}"; }

k3s::_ssh_opts() {
  local -n _ref="$1"
  _ref=(
    -i "$(k3s::_key)"
    -o BatchMode=yes
    -o ConnectTimeout=20
    -o ServerAliveInterval=15
    -o StrictHostKeyChecking=accept-new
  )
  [[ -n "${SSH_PORT:-}" && "${SSH_PORT}" != "22" ]] && _ref+=(-p "$SSH_PORT")
  [[ -n "${SSH_EXTRA_ARGS:-}" ]] && _ref+=(${SSH_EXTRA_ARGS})
}

k3s::_ssh() {
  local ip="$1" cmd="$2"
  local opts=()
  k3s::_ssh_opts opts
  # shellcheck disable=SC2086,SC2029
  ssh "${opts[@]}" "$SSH_USER@$ip" "$cmd"
}

k3s::_first_cp_ip() {
  echo "$CONTROL_PLANE_IPS" | awk '{print $1}'
}

k3s::_exec_args() {
  local args="${K3S_EXEC_ARGS:---flannel-backend=none --disable-network-policy --disable traefik --disable servicelb --disable-kube-proxy}"
  [[ -n "${K3S_DATA_DIR:-}" ]] && args="--data-dir ${K3S_DATA_DIR} ${args}"
  echo "$args"
}

k3s::_all_ips() {
  echo "$CONTROL_PLANE_IPS $WORKER_IPS"
}

k3s::host_prep() {
  local ip
  log::section "k3s host prep"
  for ip in $(k3s::_all_ips); do
    [[ -n "$ip" ]] || continue
    log::info "Preparing $SSH_USER@$ip …"
    # shellcheck disable=SC2029
    k3s::_ssh "$ip" "K3S_DATA_DIR='${K3S_DATA_DIR:-}' bash -s" <<'REMOTE'
set -euo pipefail
sudo modprobe br_netfilter 2>/dev/null || true
sudo modprobe overlay 2>/dev/null || true
sudo modprobe kvm 2>/dev/null || true
if [[ "$(uname -m)" == x86_64 ]]; then
  if grep -qi intel /proc/cpuinfo 2>/dev/null; then sudo modprobe kvm_intel 2>/dev/null || true
  elif grep -qi amd /proc/cpuinfo 2>/dev/null; then sudo modprobe kvm_amd 2>/dev/null || true
  fi
fi
if command -v swapon >/dev/null 2>&1 && sudo swapon --show 2>/dev/null | grep -q .; then
  sudo swapoff -a || true
  if [[ -f /etc/fstab ]]; then
    sudo sed -i '/[[:space:]]swap[[:space:]]/s/^/# /' /etc/fstab || true
  fi
fi
cat <<'SYSCTL' | sudo tee /etc/sysctl.d/99-kubernetes.conf >/dev/null
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=8192
SYSCTL
sudo sysctl --system >/dev/null 2>&1 || sudo sysctl -p /etc/sysctl.d/99-kubernetes.conf >/dev/null
if systemctl is-active firewalld &>/dev/null; then
  sudo systemctl stop firewalld || true
  sudo systemctl disable firewalld || true
fi
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y qemu-kvm libvirt-client 2>/dev/null || true
elif command -v apt-get >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive sudo apt-get update -qq 2>/dev/null || true
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y qemu-kvm qemu-utils 2>/dev/null || true
fi
[[ -n "${K3S_DATA_DIR:-}" ]] && sudo mkdir -p "${K3S_DATA_DIR}"
REMOTE
    log::ok "$ip prepared"
  done
}

k3s::_install_env() {
  local exec_args="$1"
  local parts=()
  [[ -n "${K3S_VERSION:-}" ]] && parts+=("INSTALL_K3S_VERSION='${K3S_VERSION}'")
  [[ -n "${K3S_CHANNEL:-}" ]] && parts+=("INSTALL_K3S_CHANNEL='${K3S_CHANNEL}'")
  parts+=("INSTALL_K3S_EXEC='server ${exec_args}'")
  (IFS=' '; echo "${parts[*]}")
}

k3s::server_running() {
  local ip="$1"
  k3s::_ssh "$ip" "sudo /usr/local/bin/k3s kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type==\"Ready\")].status}'" 2>/dev/null | grep -q True
}

k3s::install_server() {
  local ip exec_args install_env
  ip=$(k3s::_first_cp_ip)
  exec_args=$(k3s::_exec_args)
  log::section "k3s server on $ip"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — skipping k3s install."
    return 0
  fi
  if [[ "${FORCE_K3S_REINSTALL:-0}" != "1" ]] && k3s::server_running "$ip"; then
    log::ok "k3s already running on $ip — skipping reinstall (set FORCE_K3S_REINSTALL=1 to replace)"
    return 0
  fi
  install_env=$(k3s::_install_env "$exec_args")
  # shellcheck disable=SC2029
  k3s::_ssh "$ip" "curl -sfL https://get.k3s.io | sudo ${install_env} sh -"
  log::info "Waiting for k3s API on $ip …"
  local i
  for i in $(seq 1 60); do
    if k3s::_ssh "$ip" "sudo /usr/local/bin/k3s kubectl get nodes" &>/dev/null; then
      log::ok "k3s API ready on $ip"
      return 0
    fi
    sleep 2
  done
  die "k3s API not ready on $ip after 120s"
}

k3s::join_workers() {
  local workers=($WORKER_IPS)
  [[ ${#workers[@]} -gt 0 && -n "${workers[0]}" ]] || {
    log::info "No worker nodes — single-node cluster."
    return 0
  }
  local master_ip token
  master_ip=$(k3s::_first_cp_ip)
  token=$(k3s::_ssh "$master_ip" "sudo cat /var/lib/rancher/k3s/server/node-token")
  [[ -n "$token" ]] || die "Could not read k3s node token from $master_ip"

  log::section "Joining ${#workers[@]} worker(s) to k3s"
  local ip
  for ip in "${workers[@]}"; do
    [[ -n "$ip" ]] || continue
    log::info "Joining $ip …"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log::warn "DRY RUN — skip join $ip"
      continue
    fi
    k3s::_ssh "$ip" \
      "curl -sfL https://get.k3s.io | sudo K3S_URL=https://${master_ip}:6443 K3S_TOKEN='${token}' sh -"
    log::ok "$ip joined"
  done
}

k3s::install_remote_kubeconfig() {
  local ip
  ip=$(k3s::_first_cp_ip)
  log::section "Remote kubeconfig → ${SSH_USER}@${ip}:~/.kube/config"
  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — skipping remote kubeconfig."
    return 0
  fi
  k3s::_ssh "$ip" 'bash -s' <<'REMOTE'
set -euo pipefail
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config
grep -q 'KUBECONFIG=.*\.kube/config' ~/.bashrc 2>/dev/null || \
  echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
REMOTE
  log::ok "Remote kubeconfig installed for ${SSH_USER}@${ip}"
}

k3s::wait_api() {
  local ip kc
  ip=$(k3s::_first_cp_ip)
  kc="${KUBECONFIG_OUTPUT/#\~/$HOME}"
  [[ -f "$kc" ]] || return 0
  log::info "Waiting for Kubernetes API (kubeconfig) …"
  local i
  for i in $(seq 1 60); do
    if KUBECONFIG="$kc" kubectl get nodes &>/dev/null; then
      log::ok "API reachable via kubeconfig"
      return 0
    fi
    sleep 2
  done
  die "API not reachable via $kc after 120s"
}

# Legacy wrapper — platform-stack installs Cilium via Helm.
k3s::install_cilium() {
  platform::install_cilium
}

k3s::deploy() {
  k3s::host_prep
  k3s::install_server
  k3s::join_workers
}

k3s::destroy_platform() {
  [[ "${FORCE:-0}" == "1" ]] || return 0
  local kc="${KUBECONFIG_OUTPUT/#\~/$HOME}"
  [[ -f "$kc" ]] || return 0
  log::section "Removing Helm platform releases"
  export KUBECONFIG="$kc"
  local releases=(
    "kubevirt:kubevirt"
    "cdi:cdi"
    "kubevirt-csi:kubevirt"
    "cnao:cluster-network-addons"
    "ssp:kubevirt"
    "cilium:kube-system"
    "metallb:metallb-system"
    "cert-manager:cert-manager"
    "snapshot-controller:snapshot-system"
    "longhorn:longhorn-system"
  )
  local entry ns name
  for entry in "${releases[@]}"; do
    name="${entry%%:*}"
    ns="${entry##*:}"
    helm uninstall "$name" -n "$ns" 2>/dev/null || true
  done
}

k3s::destroy() {
  k3s::destroy_platform
  log::section "Removing k3s from all nodes"
  local ip
  for ip in $(k3s::_all_ips); do
    [[ -n "$ip" ]] || continue
    log::info "Uninstalling k3s on $ip …"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
      log::warn "DRY RUN — skip uninstall on $ip"
      continue
    fi
    k3s::_ssh "$ip" "sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || sudo k3s-uninstall.sh 2>/dev/null || true"
    log::ok "k3s removed from $ip"
  done
}
