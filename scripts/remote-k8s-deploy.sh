#!/usr/bin/env bash
# Re-exec with Homebrew bash 5 on macOS (system bash is 3.2, missing declare -A)
if [[ "$(uname)" == "Darwin" && "${BASH_VERSINFO[0]:-3}" -lt 4 ]]; then
  _b="$(brew --prefix 2>/dev/null)/bin/bash"
  [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
  echo "bash 4+ required — run: brew install bash" >&2; exit 1
fi
# remote-k8s-deploy.sh — lightweight standalone Kubernetes deployer (k3s or kubeadm).
#
# Simpler alternative to the full hypercluster/Kubespray workflow.
# Supports k3s (lightweight) or kubeadm (upstream), with Podman or Docker.
# Also installs KVM/virt host dependencies via scripts/install-deps.sh.
#
# Usage:
#   Edit the CONFIGURATION section below, then:
#     chmod +x scripts/remote-k8s-deploy.sh
#     ./scripts/remote-k8s-deploy.sh
#
#   ./scripts/remote-k8s-deploy.sh --help     show this message
#   ./scripts/remote-k8s-deploy.sh --verify   check SSH connectivity only

# ============================================
# CONFIGURATION — EDIT THESE VALUES
# ============================================

# Cluster identity (used to name the kubeconfig file)
CLUSTER_NAME="mycluster"

# --- Master Node ---
MASTER_IP="192.168.1.100"
MASTER_USER="root"
MASTER_SSH_KEY="~/.ssh/id_rsa"

# --- Worker Nodes  (format: "IP|USER|SSH_KEY_PATH") ---
# Note: uses | as separator so SSH key paths with colons are safe
WORKERS=(
    "192.168.1.101|root|~/.ssh/id_rsa"
    "192.168.1.102|root|~/.ssh/id_rsa"
)

# --- Kubernetes Distribution ---
# "k3s" (lightweight) or "kubeadm" (upstream)
K8S_DISTRO="k3s"

# --- Container Runtime ---
# "podman" (preferred), "docker", or "none"
CONTAINER_RUNTIME="podman"

# --- Install kubectl / helm locally? ---
INSTALL_LOCAL_KUBECTL=true
INSTALL_LOCAL_HELM=false

# --- SSH port (default 22; set to e.g. 2222 when nodes are containers with port forwarding) ---
SSH_PORT=22

# --- K3s Extra Arguments ---
K3S_EXTRA_ARGS="--disable traefik --disable servicelb"

# --- kubeadm: Kubernetes minor version (used to select the package repo) ---
# Format: "v1.32"  — must match pkgs.k8s.io channel naming
KUBEADM_VERSION="v1.32"

# --- Pod network CIDR (Calico default; kubeadm only) ---
POD_NETWORK_CIDR="10.244.0.0/16"

# --- hyper2kvm host dependencies ---
# Installs libvirt, qemu, govc, pyvmomi, etc. on the deployer machine.
# Set to false to skip (already installed, or non-KVM environment).
INSTALL_HYPER2KVM_DEPS=true
HYPER2KVM_DEPS_SCRIPT="./install-deps.sh"   # relative to this script's directory

# ============================================
# SCRIPT LOGIC — DO NOT EDIT BELOW
# ============================================
set -euo pipefail

# Allow an external config file to override the CONFIGURATION section above.
# Set HC_CONFIG=/path/to/file before running to use an external config.
[[ -n "${HC_CONFIG:-}" && -f "$HC_CONFIG" ]] && source "$HC_CONFIG"

# ── logging ──────────────────────────────────────────────────────────────────
_ts() { date '+%H:%M:%S'; }
log_info()    { printf "[%s] ✅  %s\n"  "$(_ts)" "$*"; }
log_warn()    { printf "[%s] ⚠️   %s\n" "$(_ts)" "$*" >&2; }
log_error()   { printf "[%s] ❌  %s\n"  "$(_ts)" "$*" >&2; exit 1; }
log_section() { printf "\n🔷  %s\n%s\n\n" "$*" "$(printf '─%.0s' {1..60})"; }

# ── help / verify mode ────────────────────────────────────────────────────────
case "${1:-}" in
  --help|-h)
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 0 ;;
  --verify)
    VERIFY_ONLY=true ;;
  *)
    VERIFY_ONLY=false ;;
esac

# ── SSH helper ────────────────────────────────────────────────────────────────
ssh_cmd() {
  local ip="$1" user="$2" key="${3/#\~/$HOME}" cmd="$4"
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -o BatchMode=yes \
      -p "${SSH_PORT:-22}" \
      -i "$key" \
      "$user@$ip" "$cmd"
}

ssh_ok() {
  ssh_cmd "$1" "$2" "$3" "true" &>/dev/null
}

# ── OS detection (cached per IP) ─────────────────────────────────────────────
declare -A _OS_CACHE

detect_os() {
  local ip="$1" user="$2" key="$3"
  if [[ -n "${_OS_CACHE[$ip]+set}" ]]; then
    echo "${_OS_CACHE[$ip]}"
    return
  fi
  local os_info result
  os_info=$(ssh_cmd "$ip" "$user" "$key" "cat /etc/os-release 2>/dev/null || echo unknown")
  if   echo "$os_info" | grep -qi "ubuntu\|debian";                       then result="debian"
  elif echo "$os_info" | grep -qi "rhel\|centos\|fedora\|rocky\|almalinux"; then result="redhat"
  elif echo "$os_info" | grep -qi "suse";                                  then result="suse"
  else result="unknown"; fi
  _OS_CACHE[$ip]="$result"
  echo "$result"
}

# ── parallel worker helper ────────────────────────────────────────────────────
# Usage: run_parallel <func> <master_ip> <master_user> <master_key> [extra_args...]
# Calls func for every worker in $WORKERS in background, waits, reports failures.
_run_on_workers_parallel() {
  local func="$1"; shift
  local extra=("$@")
  local pids=() labels=() failed=0

  for entry in "${WORKERS[@]}"; do
    IFS='|' read -r ip user key <<< "$entry"
    "$func" "$ip" "$user" "$key" "${extra[@]}" &
    pids+=($!)
    labels+=("$ip")
  done

  for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || { log_warn "Failed on ${labels[$i]}"; (( failed++ )) || true; }
  done

  [[ "$failed" -eq 0 ]] || log_error "$failed worker(s) failed in $func."
}

# ── connectivity check ────────────────────────────────────────────────────────
check_connectivity() {
  log_section "Connectivity checks"
  local failed=0

  local master_key="${MASTER_SSH_KEY/#\~/$HOME}"
  log_info "Testing SSH → $MASTER_USER@$MASTER_IP …"
  if ssh_ok "$MASTER_IP" "$MASTER_USER" "$master_key"; then
    log_info "$MASTER_USER@$MASTER_IP  reachable ✅"
  else
    log_warn "Cannot reach $MASTER_USER@$MASTER_IP"
    (( failed++ )) || true
  fi

  for entry in "${WORKERS[@]}"; do
    IFS='|' read -r ip user key <<< "$entry"
    key="${key/#\~/$HOME}"
    log_info "Testing SSH → $user@$ip …"
    if ssh_ok "$ip" "$user" "$key"; then
      log_info "$user@$ip  reachable ✅"
    else
      log_warn "Cannot reach $user@$ip"
      (( failed++ )) || true
    fi
  done

  [[ "$failed" -eq 0 ]] || log_error "SSH connectivity failed for $failed node(s)."
  log_info "All nodes reachable. 🚀"
}

# ── host dependency installer ─────────────────────────────────────────────────
install_host_deps() {
  [[ "$INSTALL_HYPER2KVM_DEPS" == true ]] || return 0

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local deps_script
  deps_script="$(realpath "$script_dir/$HYPER2KVM_DEPS_SCRIPT" 2>/dev/null || echo "")"

  if [[ -z "$deps_script" || ! -f "$deps_script" ]]; then
    log_warn "install-deps.sh not found at: $script_dir/$HYPER2KVM_DEPS_SCRIPT"
    log_warn "Skipping host deps. Set INSTALL_HYPER2KVM_DEPS=false to suppress."
    return 0
  fi

  log_section "Host dependencies (hyper2kvm)"
  if [[ "$(id -u)" -ne 0 ]]; then
    log_warn "Not root — invoking install-deps.sh with sudo."
    sudo bash "$deps_script" --all
  else
    bash "$deps_script" --all
  fi
  log_info "Host dependencies installed."
}

# ── container runtime ─────────────────────────────────────────────────────────
install_podman() {
  local ip="$1" user="$2" key="$3"
  if ssh_cmd "$ip" "$user" "$key" "command -v podman" &>/dev/null; then
    log_info "Podman already installed on $ip — skipping."
    return
  fi
  log_info "Installing Podman on $ip …"
  local os; os=$(detect_os "$ip" "$user" "$key")
  case "$os" in
    debian)  ssh_cmd "$ip" "$user" "$key" "sudo apt-get update -qq && sudo apt-get install -y podman" ;;
    redhat)  ssh_cmd "$ip" "$user" "$key" "sudo dnf install -y podman" ;;
    suse)    ssh_cmd "$ip" "$user" "$key" "sudo zypper install -y podman" ;;
    *)       log_error "Unsupported OS for Podman on $ip: $os" ;;
  esac
}

install_docker() {
  local ip="$1" user="$2" key="$3"
  if ssh_cmd "$ip" "$user" "$key" "command -v docker" &>/dev/null; then
    log_info "Docker already installed on $ip — skipping."
    return
  fi
  log_info "Installing Docker on $ip …"
  ssh_cmd "$ip" "$user" "$key" "curl -fsSL https://get.docker.com | sh"
  ssh_cmd "$ip" "$user" "$key" "sudo usermod -aG docker $user"
}

install_runtime_on_node() {
  local ip="$1" user="$2" key="$3"
  case "$CONTAINER_RUNTIME" in
    podman) install_podman "$ip" "$user" "$key" ;;
    docker) install_docker "$ip" "$user" "$key" ;;
  esac
}

install_runtimes() {
  [[ "$CONTAINER_RUNTIME" == "none" ]] && return 0
  log_section "Container runtime: $CONTAINER_RUNTIME"

  # master first (sequential), workers in parallel
  install_runtime_on_node "$MASTER_IP" "$MASTER_USER" "$MASTER_SSH_KEY"
  _run_on_workers_parallel install_runtime_on_node
}

# ── k3s ───────────────────────────────────────────────────────────────────────
install_k3s_master() {
  local ip="$1" user="$2" key="$3"
  if ssh_cmd "$ip" "$user" "$key" "command -v k3s" &>/dev/null; then
    log_info "K3s already installed on $ip — skipping master install."
    return
  fi
  log_info "Installing K3s server on $ip …"
  local exec_args="server $K3S_EXTRA_ARGS"
  [[ "$CONTAINER_RUNTIME" == "docker" ]] && exec_args="server --docker $K3S_EXTRA_ARGS"
  ssh_cmd "$ip" "$user" "$key" \
    "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='$exec_args' sh -"

  log_info "Waiting for K3s API to become ready on $ip …"
  local i
  for i in $(seq 1 30); do
    if ssh_cmd "$ip" "$user" "$key" "sudo k3s kubectl get nodes" &>/dev/null; then
      log_info "K3s ready after $((i * 3))s."
      return
    fi
    sleep 3
  done
  log_error "K3s did not become ready on $ip after 90s."
}

install_k3s_worker() {
  local ip="$1" user="$2" key="$3" master_ip="$4" token="$5"
  if ssh_cmd "$ip" "$user" "$key" "command -v k3s" &>/dev/null; then
    log_info "K3s already installed on $ip — skipping worker join."
    return
  fi
  log_info "Joining K3s worker $ip …"
  local extra=""
  [[ "$CONTAINER_RUNTIME" == "docker" ]] && extra="INSTALL_K3S_EXEC='--docker'"
  ssh_cmd "$ip" "$user" "$key" \
    "curl -sfL https://get.k3s.io | K3S_URL=https://$master_ip:6443 K3S_TOKEN=$token $extra sh -"
}

deploy_k3s() {
  log_section "K3s deployment"
  install_k3s_master "$MASTER_IP" "$MASTER_USER" "$MASTER_SSH_KEY"
  local token
  token=$(ssh_cmd "$MASTER_IP" "$MASTER_USER" "$MASTER_SSH_KEY" \
            "sudo cat /var/lib/rancher/k3s/server/node-token")

  local pids=() labels=() failed=0
  for entry in "${WORKERS[@]}"; do
    IFS='|' read -r ip user key <<< "$entry"
    install_k3s_worker "$ip" "$user" "$key" "$MASTER_IP" "$token" &
    pids+=($!)
    labels+=("$ip")
  done
  for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || { log_warn "Worker ${labels[$i]} join failed"; (( failed++ )) || true; }
  done
  [[ "$failed" -eq 0 ]] || log_error "$failed K3s worker(s) failed to join."
  log_info "All K3s workers joined. ✅"
}

# ── kubeadm ───────────────────────────────────────────────────────────────────
install_kubeadm_deps() {
  local ip="$1" user="$2" key="$3"
  if ssh_cmd "$ip" "$user" "$key" "command -v kubeadm" &>/dev/null; then
    log_info "kubeadm already installed on $ip — skipping."
    return
  fi
  log_info "Installing kubeadm dependencies on $ip …"
  local os; os=$(detect_os "$ip" "$user" "$key")

  # Kernel / sysctl prerequisites
  ssh_cmd "$ip" "$user" "$key" "sudo swapoff -a && sudo sed -i '/swap/d' /etc/fstab"
  ssh_cmd "$ip" "$user" "$key" "sudo modprobe overlay && sudo modprobe br_netfilter"
  ssh_cmd "$ip" "$user" "$key" \
    "printf 'net.bridge.bridge-nf-call-iptables=1\nnet.bridge.bridge-nf-call-ip6tables=1\nnet.ipv4.ip_forward=1\n' \
     | sudo tee /etc/sysctl.d/k8s.conf && sudo sysctl --system"

  # containerd — use detected OS, not a fallback chain
  case "$os" in
    debian)  ssh_cmd "$ip" "$user" "$key" "sudo apt-get update -qq && sudo apt-get install -y containerd" ;;
    redhat)  ssh_cmd "$ip" "$user" "$key" "sudo dnf install -y containerd" ;;
    suse)    ssh_cmd "$ip" "$user" "$key" "sudo zypper install -y containerd" ;;
    *)       log_error "Unsupported OS for containerd on $ip: $os" ;;
  esac
  ssh_cmd "$ip" "$user" "$key" \
    "sudo mkdir -p /etc/containerd \
     && containerd config default | sudo tee /etc/containerd/config.toml \
     && sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml \
     && sudo systemctl restart containerd"

  # kubeadm / kubelet / kubectl — use KUBEADM_VERSION for the repo channel
  case "$os" in
    debian)
      ssh_cmd "$ip" "$user" "$key" \
        "sudo apt-get update -qq && sudo apt-get install -y apt-transport-https ca-certificates curl"
      ssh_cmd "$ip" "$user" "$key" \
        "curl -fsSL https://pkgs.k8s.io/core:/stable:/${KUBEADM_VERSION}/deb/Release.key \
         | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg"
      ssh_cmd "$ip" "$user" "$key" \
        "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
               https://pkgs.k8s.io/core:/stable:/${KUBEADM_VERSION}/deb/ /' \
         | sudo tee /etc/apt/sources.list.d/kubernetes.list"
      ssh_cmd "$ip" "$user" "$key" \
        "sudo apt-get update -qq \
         && sudo apt-get install -y kubelet kubeadm kubectl \
         && sudo apt-mark hold kubelet kubeadm kubectl"
      ;;
    redhat)
      ssh_cmd "$ip" "$user" "$key" "sudo tee /etc/yum.repos.d/kubernetes.repo <<'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/${KUBEADM_VERSION}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${KUBEADM_VERSION}/rpm/repodata/repomd.xml.key
EOF"
      ssh_cmd "$ip" "$user" "$key" \
        "sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes"
      ;;
    suse)
      ssh_cmd "$ip" "$user" "$key" \
        "sudo zypper addrepo https://download.opensuse.org/repositories/devel:/kubic/standard/devel:kubic.repo \
         && sudo zypper refresh \
         && sudo zypper install -y kubernetes-kubeadm kubernetes-kubelet kubernetes-client"
      ;;
    *)
      log_error "Unsupported OS for kubeadm on $ip: $os"
      ;;
  esac
  ssh_cmd "$ip" "$user" "$key" "sudo systemctl enable kubelet"
}

init_kubeadm_master() {
  local ip="$1" user="$2" key="$3"
  log_info "Initializing kubeadm control plane on $ip …"
  ssh_cmd "$ip" "$user" "$key" "sudo kubeadm init --pod-network-cidr=$POD_NETWORK_CIDR"
  ssh_cmd "$ip" "$user" "$key" \
    "mkdir -p \$HOME/.kube \
     && sudo cp /etc/kubernetes/admin.conf \$HOME/.kube/config \
     && sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
  ssh_cmd "$ip" "$user" "$key" \
    "kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26/manifests/calico.yaml"
}

join_kubeadm_worker() {
  local ip="$1" user="$2" key="$3" join_cmd="$4"
  if ssh_cmd "$ip" "$user" "$key" "command -v kubeadm && sudo kubeadm version" &>/dev/null \
      && ssh_cmd "$ip" "$user" "$key" "systemctl is-active kubelet" &>/dev/null; then
    log_info "Node $ip already joined — skipping."
    return
  fi
  log_info "Joining kubeadm worker $ip …"
  ssh_cmd "$ip" "$user" "$key" "sudo $join_cmd"
}

deploy_kubeadm() {
  log_section "kubeadm deployment ($KUBEADM_VERSION)"

  # Install deps on all nodes in parallel
  local pids=() labels=() failed=0
  for entry in "${WORKERS[@]}"; do
    IFS='|' read -r ip user key <<< "$entry"
    install_kubeadm_deps "$ip" "$user" "$key" &
    pids+=($!)
    labels+=("$ip")
  done
  install_kubeadm_deps "$MASTER_IP" "$MASTER_USER" "$MASTER_SSH_KEY" &
  pids+=($!)
  labels+=("$MASTER_IP (master)")
  for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || { log_warn "${labels[$i]} deps failed"; (( failed++ )) || true; }
  done
  [[ "$failed" -eq 0 ]] || log_error "kubeadm dependency install failed on $failed node(s)."

  init_kubeadm_master "$MASTER_IP" "$MASTER_USER" "$MASTER_SSH_KEY"

  local join_cmd
  join_cmd=$(ssh_cmd "$MASTER_IP" "$MASTER_USER" "$MASTER_SSH_KEY" \
               "sudo kubeadm token create --print-join-command")

  pids=(); labels=(); failed=0
  for entry in "${WORKERS[@]}"; do
    IFS='|' read -r ip user key <<< "$entry"
    join_kubeadm_worker "$ip" "$user" "$key" "$join_cmd" &
    pids+=($!)
    labels+=("$ip")
  done
  for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || { log_warn "${labels[$i]} join failed"; (( failed++ )) || true; }
  done
  [[ "$failed" -eq 0 ]] || log_error "$failed kubeadm worker(s) failed to join."
  log_info "All kubeadm workers joined. ✅"
}

# ── local CLI tools ───────────────────────────────────────────────────────────
install_local_cli() {
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  [[ "$arch" == "x86_64" ]]  && arch="amd64"
  [[ "$arch" == "aarch64" ]] && arch="arm64"

  if [[ "$INSTALL_LOCAL_KUBECTL" == true ]]; then
    if command -v kubectl &>/dev/null; then
      log_info "kubectl already installed — skipping."
    else
      log_info "Installing kubectl …"
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$os/$arch/kubectl"
      chmod +x kubectl && sudo mv kubectl /usr/local/bin/
      log_info "kubectl installed."
    fi
  fi

  if [[ "$INSTALL_LOCAL_HELM" == true ]]; then
    if command -v helm &>/dev/null; then
      log_info "helm already installed — skipping."
    else
      log_info "Installing helm …"
      curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      log_info "helm installed."
    fi
  fi
}

# ── kubeconfig ────────────────────────────────────────────────────────────────
fetch_kubeconfig() {
  log_section "Fetching kubeconfig"
  local key="${MASTER_SSH_KEY/#\~/$HOME}"
  local dest="$HOME/.kube/config-${CLUSTER_NAME}"
  mkdir -p "$HOME/.kube"

  if [[ "$K8S_DISTRO" == "k3s" ]]; then
    ssh_cmd "$MASTER_IP" "$MASTER_USER" "$key" "sudo cat /etc/rancher/k3s/k3s.yaml" > "$dest"
  else
    ssh_cmd "$MASTER_IP" "$MASTER_USER" "$key" "sudo cat /etc/kubernetes/admin.conf" > "$dest"
  fi

  # Patch 127.0.0.1 → actual master IP
  sed -i.bak \
    -e "s|https://127.0.0.1:|https://${MASTER_IP}:|g" \
    -e "s|https://localhost:|https://${MASTER_IP}:|g" \
    "$dest"
  rm -f "${dest}.bak"
  chmod 600 "$dest"
  log_info "kubeconfig saved → $dest"

  # Merge into ~/.kube/config
  if [[ -f "$HOME/.kube/config" ]]; then
    local backup="$HOME/.kube/config.bak.$(date +%Y%m%d%H%M%S)"
    cp "$HOME/.kube/config" "$backup"
    KUBECONFIG="$HOME/.kube/config:$dest" kubectl config view --flatten > "$HOME/.kube/config.tmp"
    mv "$HOME/.kube/config.tmp" "$HOME/.kube/config"
    log_info "Merged into ~/.kube/config (backup: $backup)"
  else
    cp "$dest" "$HOME/.kube/config"
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  [[ -n "$MASTER_IP" ]] || log_error "MASTER_IP is not set."

  check_connectivity
  [[ "$VERIFY_ONLY" == true ]] && exit 0

  install_host_deps
  install_runtimes

  case "$K8S_DISTRO" in
    k3s)    deploy_k3s ;;
    kubeadm) deploy_kubeadm ;;
    *)      log_error "Invalid K8S_DISTRO '$K8S_DISTRO'. Choose 'k3s' or 'kubeadm'." ;;
  esac

  if [[ "$INSTALL_LOCAL_KUBECTL" == true || "$INSTALL_LOCAL_HELM" == true ]]; then
    install_local_cli
  fi

  fetch_kubeconfig

  log_section "Done"
  log_info "🎉 Cluster '$CLUSTER_NAME' deployed. Nodes:"
  KUBECONFIG="$HOME/.kube/config-${CLUSTER_NAME}" kubectl get nodes -o wide
}

main
