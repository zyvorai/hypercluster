#!/usr/bin/env bash
# Re-exec with Homebrew bash 5 on macOS (system bash is 3.2, missing bash 4+ features)
if [[ "$(uname)" == "Darwin" && "${BASH_VERSINFO[0]:-3}" -lt 4 ]]; then
  _b="$(brew --prefix 2>/dev/null)/bin/bash"
  [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
  echo "bash 4+ required — run: brew install bash" >&2; exit 1
fi
# test-podman.sh — Fast integration test using Podman containers as SSH nodes.
#
# Creates rootless Podman containers with sshd, deploys via hypercluster k3s path,
# and runs platform smoke tests. No sudo required on the deployer.
#
# Usage:
#   chmod +x scripts/test-podman.sh
#   ./scripts/test-podman.sh              # full test
#   ./scripts/test-podman.sh --preflight  # SSH connectivity check only
#   ./scripts/test-podman.sh --clean      # remove containers and test config
#   ./scripts/test-podman.sh --help
#
# Prerequisites:
#   brew install podman          (or: ./scripts/setup-macos.sh)
#   podman machine init && podman machine start

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"

# ── container names and port mapping ─────────────────────────────────────────
CTR_MASTER="hc-master"
CTR_WORKERS=("hc-worker1" "hc-worker2")

PORT_MASTER=2222
PORT_WORKERS=(2223 2224)
PORT_API=6443                 # k3s API server forwarded from master to host

SSH_KEY="$HOME/.ssh/id_hc_podman"
TEST_CONF="$REPO_DIR/cluster-podman.conf"
HC="$REPO_DIR/hypercluster"
IMAGE_NAME="hc-node:test"

# ── helpers ───────────────────────────────────────────────────────────────────
ctr_running() { podman ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"; }
ctr_exists()  { podman ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$1"; }

ssh_node() {
  local port="$1" cmd="$2"
  ssh -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=5 \
      -o BatchMode=yes \
      -p "$port" \
      -i "$SSH_KEY" \
      "root@127.0.0.1" "$cmd"
}

# ── prerequisites ─────────────────────────────────────────────────────────────
check_prereqs() {
  section "Prerequisites"
  command -v podman &>/dev/null || die "podman not found — run: brew install podman"
  info "podman: $(podman --version)"

  # Ensure Podman machine is running (macOS only)
  if [[ "$(uname)" == "Darwin" ]]; then
    if ! podman machine list --format '{{.LastUp}}' 2>/dev/null | grep -qi "running"; then
      warn "No running Podman machine found."
      info "Initialising and starting Podman machine (one-time, takes ~2 min) …"
      podman machine init --cpus 2 --memory 2048 --disk-size 20 2>/dev/null || true
      podman machine start 2>/dev/null || true
    fi
    info "Podman machine: $(podman machine list --format '{{.Name}} {{.LastUp}}' 2>/dev/null | head -1)"
  fi
}

# ── SSH key ───────────────────────────────────────────────────────────────────
ensure_ssh_key() {
  section "SSH key"
  if [[ -f "$SSH_KEY" ]]; then
    info "Key already exists: $SSH_KEY"
    return
  fi
  ssh-keygen -t ed25519 -f "$SSH_KEY" -C "hc-podman-test" -N ""
  chmod 600 "$SSH_KEY"
  info "Key created: $SSH_KEY"
}

# ── container image ───────────────────────────────────────────────────────────
build_image() {
  section "Building node image"
  if podman image exists "$IMAGE_NAME" 2>/dev/null; then
    info "Image already built: $IMAGE_NAME"
    return
  fi
  info "Building $IMAGE_NAME from $SCRIPT_DIR/Dockerfile.node …"
  podman build \
    --file "$SCRIPT_DIR/Dockerfile.node" \
    --tag "$IMAGE_NAME" \
    "$SCRIPT_DIR"
  info "Image built: $IMAGE_NAME"
}

# ── containers ────────────────────────────────────────────────────────────────
start_container() {
  local name="$1" port="$2" extra_ports="${3:-}"

  if ctr_running "$name"; then
    info "Container already running: $name (port $port)"
    return
  fi

  if ctr_exists "$name"; then
    info "Restarting existing container: $name"
    podman start "$name" >/dev/null
    return
  fi

  info "Starting container: $name → 127.0.0.1:$port:22"
  local publish_args=("--publish" "127.0.0.1:${port}:22")
  for ep in $extra_ports; do
    publish_args+=("--publish" "$ep")
  done
  podman run -d \
    --name "$name" \
    --privileged \
    --cgroupns=host \
    --device /dev/kmsg \
    "${publish_args[@]}" \
    "$IMAGE_NAME" >/dev/null
}

inject_ssh_key() {
  local name="$1"
  local pubkey
  pubkey=$(cat "${SSH_KEY}.pub")
  # Inject key and fix /dev/kmsg permissions (needed by kubelet)
  podman exec "$name" bash -c \
    "mkdir -p /root/.ssh && chmod 700 /root/.ssh && \
     echo '$pubkey' > /root/.ssh/authorized_keys && \
     chmod 600 /root/.ssh/authorized_keys && \
     chmod 666 /dev/kmsg 2>/dev/null || true"
}

start_containers() {
  section "Starting containers"
  start_container "$CTR_MASTER" "$PORT_MASTER" "127.0.0.1:${PORT_API}:6443"
  for i in "${!CTR_WORKERS[@]}"; do
    start_container "${CTR_WORKERS[$i]}" "${PORT_WORKERS[$i]}"
  done

  info "Waiting for systemd + sshd to start …"
  local attempts=0
  # Wait for sshd socket to be ready (systemd needs a few extra seconds vs direct sshd)
  until podman exec "$CTR_MASTER" systemctl is-active ssh &>/dev/null; do
    (( attempts++ ))
    [[ "$attempts" -lt 30 ]] || die "sshd on master didn't start after 30s"
    sleep 1
  done

  # Inject SSH keys into all containers now that sshd is up
  inject_ssh_key "$CTR_MASTER"
  for name in "${CTR_WORKERS[@]}"; do
    inject_ssh_key "$name"
  done

  info "systemd + sshd ready, SSH keys injected."
}

# ── connectivity check ────────────────────────────────────────────────────────
check_connectivity() {
  section "SSH connectivity"
  local failed=0

  for port in "$PORT_MASTER" "${PORT_WORKERS[@]}"; do
    if ssh_node "$port" "hostname" &>/dev/null; then
      info "127.0.0.1:$port  reachable ✅  ($(ssh_node "$port" "hostname"))"
    else
      warn "127.0.0.1:$port  FAILED"
      (( failed++ )) || true
    fi
  done

  [[ "$failed" -eq 0 ]] || die "SSH failed on $failed container(s)."
  info "All nodes reachable."
}

# ── hypercluster deploy config ────────────────────────────────────────────────
write_hypercluster_conf() {
  section "Writing $TEST_CONF"
  local master_ip="$1" ssh_port="${2:-22}"

  cat > "$TEST_CONF" <<EOF
# Auto-generated by test-podman.sh
CLUSTER_NAME="hc-podman"

K8S_DISTRO="k3s"
K3S_DATA_DIR="/data/k3s"
K3S_EXEC_ARGS="--flannel-backend=none --disable-network-policy --disable traefik --disable servicelb --disable-kube-proxy --snapshotter=native"
CILIUM_K8S_SERVICE_HOST="127.0.0.1"

PLATFORM_STACK_ENABLED="true"
METALLB_ENABLED="false"
CERT_MANAGER_ENABLED="true"
KUBEVIRT_ENABLED="true"
KUBEVIRT_DISKS_PROVIDER="true"
SNAPSHOT_CONTROLLER_ENABLED="true"
CNAO_ENABLED="false"
SSP_ENABLED="false"

KUBE_PODS_SUBNET="10.42.0.0/16"
KUBE_SERVICE_ADDRESSES="10.43.0.0/16"
CNI_PLUGIN="cilium"

SSH_USER="root"
SSH_KEY="$SSH_KEY"
SSH_PORT=$ssh_port
SSH_EXTRA_ARGS="-o StrictHostKeyChecking=no"

CONTROL_PLANE_IPS="$master_ip"
WORKER_IPS=""

KUBEVIRT_VERSION="v1.8.3"
CDI_VERSION="v1.65.0"
METRICS_SERVER_ENABLED="true"

KUBECONFIG_OUTPUT="\$HOME/.kube/config-hc-podman.yaml"
KUBECONFIG_MERGE_DEFAULT="false"
EOF
  info "Config written: $TEST_CONF"
}

deploy_hypercluster() {
  section "Deploy via hypercluster (k3s platform path)"
  chmod +x "$HC"
  "$HC" -c "$TEST_CONF" preflight
  "$HC" -c "$TEST_CONF" deploy
}

verify() {
  section "Platform smoke tests"
  "$HC" -c "$TEST_CONF" test
  local kc="$HOME/.kube/config-hc-podman.yaml"
  [[ -f "$kc" ]] || die "kubeconfig not found: $kc"
  info "Nodes:"
  KUBECONFIG="$kc" kubectl get nodes -o wide
}

# ── clean ─────────────────────────────────────────────────────────────────────
clean() {
  section "Cleaning up"
  for ctr in "$CTR_MASTER" "${CTR_WORKERS[@]}"; do
    if ctr_exists "$ctr"; then
      podman rm -f "$ctr" >/dev/null && info "Removed container: $ctr"
    fi
  done
  if podman image exists "$IMAGE_NAME" 2>/dev/null; then
    podman rmi "$IMAGE_NAME" >/dev/null && info "Removed image: $IMAGE_NAME"
  fi
  [[ -f "$TEST_CONF" ]] && { rm -f "$TEST_CONF"; info "Removed $TEST_CONF"; }
  local kc="$HOME/.kube/config-hc-podman.yaml"
  [[ -f "$kc" ]]        && { rm -f "$kc";        info "Removed $kc"; }
  info "Clean done."
}

# ── main ──────────────────────────────────────────────────────────────────────
case "${1:-}" in
  --clean)
    clean; exit 0 ;;
  --preflight)
    check_prereqs
    ensure_ssh_key
    build_image
    start_containers
    check_connectivity
    info "Preflight passed. ✅"
    exit 0 ;;
  --help|-h)
    grep '^#' "$0" | grep -v '^#!/' | sed 's/^# \{0,1\}//'
    exit 0 ;;
  "")
    check_prereqs
    ensure_ssh_key
    build_image
    start_containers
    check_connectivity
    write_hypercluster_conf "127.0.0.1" "$PORT_MASTER"
    deploy_hypercluster
    verify
    section "Done"
    info "k3s platform cluster running in Podman containers!"
    printf "\n    export KUBECONFIG=\$HOME/.kube/config-hc-podman.yaml\n"
    printf "    kubectl get nodes\n"
    printf "    # API also reachable at https://127.0.0.1:%s\n\n" "$PORT_API"
    info "Tear down:  ./scripts/test-podman.sh --clean"
    ;;
  *)
    die "Unknown argument: $1  (try --help)" ;;
esac
