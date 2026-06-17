#!/usr/bin/env bash
# Remote libvirt helpers for scripts/deploy-remote.sh (source only).

deploy_remote_libvirt::ssh_opts() {
  local -n _ref="$1"
  _ref=(
    -o BatchMode=yes
    -o ConnectTimeout=30
    -o StrictHostKeyChecking=accept-new
    -o ServerAliveInterval=15
  )
  if [[ -n "${DEPLOY_REMOTE_SSH_KEY:-}" && -f "${DEPLOY_REMOTE_SSH_KEY}" ]]; then
    _ref+=(-i "${DEPLOY_REMOTE_SSH_KEY}" -o IdentitiesOnly=yes)
  fi
}

deploy_remote_libvirt::ssh() {
  local target="$1"
  shift
  local opts=()
  deploy_remote_libvirt::ssh_opts opts
  ssh "${opts[@]}" "$target" "$@"
}

deploy_remote_libvirt::check_hypervisor() {
  local target="$1"
  deploy_remote_libvirt::ssh "$target" 'bash -s' <<'REMOTE'
set -euo pipefail
systemctl is-active libvirtd >/dev/null 2>&1 || { echo "libvirtd not active" >&2; exit 1; }
sudo virsh net-list --name 2>/dev/null | grep -qx default || { echo "libvirt default network missing" >&2; exit 1; }
command -v virt-install >/dev/null 2>&1 || { echo "virt-install not found" >&2; exit 1; }
command -v qemu-img >/dev/null 2>&1 || { echo "qemu-img not found" >&2; exit 1; }
echo ok
REMOTE
}

# stdout: METALLB pool e.g. 192.168.122.240-192.168.122.250
deploy_remote_libvirt::detect_metallb_pool() {
  local target="$1"
  deploy_remote_libvirt::ssh "$target" 'bash -s' <<'REMOTE'
set -euo pipefail
subnet=""
if xml="$(sudo virsh net-dumpxml default 2>/dev/null)"; then
  subnet="$(printf '%s' "$xml" | awk -F"'" '/<ip address=/ {print $2; exit}')"
fi
if [[ -z "$subnet" ]]; then
  lease="$(sudo virsh net-dhcp-leases default 2>/dev/null | awk '/192\.168\./ {print $5; exit}' | cut -d/ -f1 || true)"
  if [[ -n "$lease" ]]; then
    prefix="${lease%.*}"
    echo "${prefix}.240-${prefix}.250"
    exit 0
  fi
  exit 1
fi
prefix="${subnet%.*}"
echo "${prefix}.240-${prefix}.250"
REMOTE
}

# args: target vm_name pubkey_b64 vcpus mem_mb disk_gb
deploy_remote_libvirt::ensure_vm() {
  local target="$1" vm_name="$2" pubkey="$3" vcpus="$4" mem_mb="$5" disk_gb="$6"
  deploy_remote_libvirt::ssh "$target" \
    "VM_NAME=$(printf '%q' "$vm_name")" \
    "SSH_PUBKEY=$(printf '%q' "$pubkey")" \
    "VM_CPUS=$(printf '%q' "$vcpus")" \
    "VM_MEM_MB=$(printf '%q' "$mem_mb")" \
    "VM_DISK_GB=$(printf '%q' "$disk_gb")" \
    'bash -s' <<'REMOTE'
set -euo pipefail
VM_NAME="${VM_NAME:?}"
SSH_PUBKEY="${SSH_PUBKEY:?}"
VM_CPUS="${VM_CPUS:-2}"
VM_MEM_MB="${VM_MEM_MB:-3072}"
VM_DISK_GB="${VM_DISK_GB:-20}"

IMG_DIR="/var/lib/libvirt/images"
BASE="${IMG_DIR}/ubuntu-22.04-server-cloudimg-amd64.img"
URL="https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
DISK="${IMG_DIR}/${VM_NAME}.qcow2"
SEED="${IMG_DIR}/${VM_NAME}-seed.iso"
USER_DATA="${IMG_DIR}/${VM_NAME}-user-data.yaml"
META_DATA="${IMG_DIR}/${VM_NAME}-meta-data.yaml"

log() { printf '→ %s\n' "$*"; }

if sudo virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
  state="$(sudo virsh domstate "$VM_NAME" 2>/dev/null || true)"
  if [[ "$state" != "running" ]]; then
    log "Starting existing VM $VM_NAME"
    sudo virsh start "$VM_NAME" >/dev/null
  else
    log "VM $VM_NAME already running"
  fi
  exit 0
fi

if [[ ! -f "$BASE" ]]; then
  log "Downloading Ubuntu 22.04 cloud image"
  sudo curl -fsSL "$URL" -o "$BASE"
fi

log "Creating VM $VM_NAME (${VM_CPUS} vCPU, ${VM_MEM_MB} MiB, ${VM_DISK_GB}G)"
sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE" "$DISK" "${VM_DISK_GB}G"

sudo tee "$USER_DATA" >/dev/null <<EOF
#cloud-config
hostname: ${VM_NAME}
manage_etc_hosts: true
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users
    shell: /bin/bash
    ssh_authorized_keys:
      - ${SSH_PUBKEY}
package_update: true
packages:
  - curl
  - python3
  - qemu-guest-agent
runcmd:
  - swapoff -a
  - sed -i '/ swap / d' /etc/fstab
  - systemctl enable --now qemu-guest-agent || true
EOF

sudo tee "$META_DATA" >/dev/null <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

if command -v cloud-localds >/dev/null 2>&1; then
  sudo cloud-localds "$SEED" "$USER_DATA" "$META_DATA"
  sudo virt-install \
    --name "$VM_NAME" \
    --memory "$VM_MEM_MB" \
    --vcpus "$VM_CPUS" \
    --disk path="$DISK",format=qcow2 \
    --disk path="$SEED",device=cdrom \
    --import \
    --os-variant ubuntu22.04 \
    --network network=default \
    --graphics none \
    --noautoconsole
else
  sudo virt-install \
    --name "$VM_NAME" \
    --memory "$VM_MEM_MB" \
    --vcpus "$VM_CPUS" \
    --disk path="$DISK",format=qcow2 \
    --import \
    --os-variant ubuntu22.04 \
    --network network=default \
    --graphics none \
    --noautoconsole \
    --cloud-init "user-data=${USER_DATA},meta-data=${META_DATA}"
fi
REMOTE
}

# stdout: guest IPv4
deploy_remote_libvirt::wait_vm_ip() {
  local target="$1" vm_name="$2" timeout="${3:-300}"
  deploy_remote_libvirt::ssh "$target" \
    "VM_NAME=$(printf '%q' "$vm_name")" \
    "WAIT_TIMEOUT=$(printf '%q' "$timeout")" \
    'bash -s' <<'REMOTE'
set -euo pipefail
VM_NAME="${VM_NAME:?}"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-300}"
deadline=$((SECONDS + WAIT_TIMEOUT))
ip=""

while (( SECONDS < deadline )); do
  ip="$(sudo virsh domifaddr "$VM_NAME" --source lease 2>/dev/null | awk '/ipv4/ {print $4; exit}' | cut -d/ -f1 || true)"
  if [[ -z "$ip" ]]; then
    ip="$(sudo virsh domifaddr "$VM_NAME" --source agent 2>/dev/null | awk '/ipv4/ && $4 !~ /^127\./ {print $4; exit}' | cut -d/ -f1 || true)"
  fi
  if [[ -z "$ip" ]]; then
    ip="$(sudo virsh net-dhcp-leases default 2>/dev/null | awk -v n="$VM_NAME" '$6==n {print $5; exit}' | cut -d/ -f1 || true)"
  fi
  [[ -n "$ip" ]] && break
  sleep 5
done

[[ -n "$ip" ]] || { echo "timeout waiting for IP on $VM_NAME" >&2; exit 1; }
printf '%s\n' "$ip"
REMOTE
}

deploy_remote_libvirt::restart_vm() {
  local target="$1" vm_name="$2"
  deploy_remote_libvirt::ssh "$target" \
    "VM_NAME=$(printf '%q' "$vm_name")" \
    'bash -s' <<'REMOTE'
set -euo pipefail
VM_NAME="${VM_NAME:?}"
if ! sudo virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "VM $VM_NAME not found" >&2
  exit 1
fi
sudo virsh destroy "$VM_NAME" 2>/dev/null || true
sleep 2
sudo virsh start "$VM_NAME" >/dev/null
echo "restarted $VM_NAME"
REMOTE
}

# args: guest_ip guest_user [jump]
deploy_remote_libvirt::probe_guest_ssh() {
  local ip="$1" user="${2:-ubuntu}" jump="${3:-${HYPERVISOR_JUMP:-}}"
  local opts=()
  ssh::guest_opts opts "${DEPLOY_REMOTE_SSH_KEY:-}" "$jump"
  ssh "${opts[@]}" "${user}@${ip}" 'echo ok' >/dev/null 2>&1
}

# Reboot guest VM on hypervisor when SSH is hung; then wait for SSH.
deploy_remote_libvirt::wait_guest_ssh() {
  local ip="$1" user="${2:-ubuntu}" vm_name="${3:-}" jump="${4:-${HYPERVISOR_JUMP:-}}"
  local target="${5:-${HYPERVISOR:-$jump}}"
  local tries=0 reboots=0 max_tries=36 max_reboots=2
  local opts=()
  ssh::guest_opts opts "${DEPLOY_REMOTE_SSH_KEY:-}" "$jump"

  log::info "Waiting for SSH on ${user}@${ip} (via ${jump}) …"
  while (( tries < max_tries )); do
    if ssh "${opts[@]}" "${user}@${ip}" 'echo ok' >/dev/null 2>&1; then
      log::ok "SSH ready on $ip"
      return 0
    fi
    if (( tries > 0 && tries % 12 == 0 && reboots < max_reboots && -n "$vm_name" )); then
      log::warn "SSH still down on $ip — restarting VM $vm_name on hypervisor …"
      deploy_remote_libvirt::restart_vm "$target" "$vm_name" || true
      reboots=$((reboots + 1))
      sleep 15
    fi
    (( tries++ )) || true
    sleep 5
  done
  die "SSH not reachable on ${user}@${ip} (via ${jump}) after ${max_reboots} VM restart(s)"
}

deploy_remote_libvirt::wait_api_ready() {
  local kc="$1" port="${2:-16443}" timeout="${3:-300}"
  local deadline=$((SECONDS + timeout))
  export KUBECONFIG="$kc"
  log::info "Waiting for Kubernetes API on 127.0.0.1:${port} …"
  while (( SECONDS < deadline )); do
    if kubectl get nodes --request-timeout=10s &>/dev/null; then
      log::ok "Kubernetes API reachable"
      return 0
    fi
    sleep 5
  done
  die "Kubernetes API not reachable via 127.0.0.1:${port} after ${timeout}s"
}

# Restart Multus/CNAO pods after guest VM reboot (common source of Cilium/Hubble flake).
deploy_remote_libvirt::heal_cluster_network() {
  local kc="$1"
  export KUBECONFIG="$kc"
  kubectl get ns cluster-network-addons &>/dev/null || return 0
  log::info "Recycling Multus/CNAO pods (post-reboot network heal) …"
  kubectl delete pods -n cluster-network-addons -l app=multus --force --grace-period=0 &>/dev/null || true
  kubectl delete pods -n cluster-network-addons -l name=cluster-network-addons-operator \
    --force --grace-period=0 &>/dev/null || true
  kubectl rollout status deployment/cluster-network-addons-operator \
    -n cluster-network-addons --timeout=180s &>/dev/null || true
  kubectl -n kube-system rollout restart deployment/hubble-relay deployment/hubble-ui &>/dev/null || true
}

deploy_remote_libvirt::stop_api_tunnel() {
  local port="${1:-16443}" cp_ip="${2:-}"
  local pattern="127\\.0\\.0\\.1:${port}:"
  [[ -n "$cp_ip" ]] && pattern="${pattern}${cp_ip}:6443"
  local pid
  pid="$(pgrep -f "$pattern" 2>/dev/null | head -1 || true)"
  [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
}

deploy_remote_libvirt::start_api_tunnel() {
  local cp_ip="$1" jump="$2" port="${3:-16443}"
  local attempt
  for attempt in 1 2 3 4 5; do
    if curl -sk --connect-timeout 3 "https://127.0.0.1:${port}/version" >/dev/null 2>&1; then
      echo "ok"
      return 0
    fi
    deploy_remote_libvirt::stop_api_tunnel "$port" "$cp_ip"
    local opts=()
    deploy_remote_libvirt::ssh_opts opts
    ssh -f -N "${opts[@]}" -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
      -L "127.0.0.1:${port}:${cp_ip}:6443" \
      "$jump" 2>/dev/null || true
    sleep 3
    if curl -sk --connect-timeout 8 "https://127.0.0.1:${port}/version" >/dev/null 2>&1; then
      echo "ok"
      return 0
    fi
    log::warn "API tunnel attempt $attempt/5 failed — retrying …"
    sleep 5
  done
  return 1
}

deploy_remote_libvirt::destroy_vms() {
  local target="$1"
  shift
  local names=("$@")
  local joined
  joined="$(printf '%s ' "${names[@]}")"
  deploy_remote_libvirt::ssh "$target" "VM_NAMES=$(printf '%q' "$joined")" 'bash -s' <<'REMOTE'
set -euo pipefail
read -r -a VM_NAMES <<< "${VM_NAMES:-}"
for vm in "${VM_NAMES[@]}"; do
  [[ -n "$vm" ]] || continue
  if sudo virsh dominfo "$vm" >/dev/null 2>&1; then
    sudo virsh destroy "$vm" 2>/dev/null || true
    sudo virsh undefine "$vm" --remove-all-storage 2>/dev/null || sudo virsh undefine "$vm" 2>/dev/null || true
    echo "removed $vm"
  fi
  sudo rm -f "/var/lib/libvirt/images/${vm}-seed.iso" \
    "/var/lib/libvirt/images/${vm}-user-data.yaml" \
    "/var/lib/libvirt/images/${vm}-meta-data.yaml" 2>/dev/null || true
done
REMOTE
}
