#!/usr/bin/env bash
# Re-exec with Homebrew bash 5 on macOS (system bash is 3.2, missing bash 4+ features)
if [[ "$(uname)" == "Darwin" && "${BASH_VERSINFO[0]:-3}" -lt 4 ]]; then
  _b="$(brew --prefix 2>/dev/null)/bin/bash"
  [[ -x "$_b" ]] && exec "$_b" "$0" "$@"
  echo "bash 4+ required — run: brew install bash" >&2; exit 1
fi
# test-podman.sh — Test hypercluster end-to-end using Podman containers as SSH nodes.
#
# Creates 3 rootless Podman containers (1 control-plane + 2 workers) with sshd,
# maps unique host ports for SSH, deploys k3s via k8s-deploy.sh, and verifies
# the cluster is healthy. No sudo required.
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

# ── container names and port mapping ─────────────────────────────────────────
CTR_MASTER="hc-master"
CTR_WORKERS=("hc-worker1" "hc-worker2")

PORT_MASTER=2222
PORT_WORKERS=(2223 2224)
PORT_API=6443                 # k3s API server forwarded from master to host

SSH_KEY="$HOME/.ssh/id_hc_podman"
TEST_CONF="$REPO_DIR/cluster-podman.conf"
IMAGE_NAME="hc-node:test"

# ── logging ───────────────────────────────────────────────────────────────────
_ts()    { date '+%H:%M:%S'; }
info()   { printf "[%s] ✅  %s\n"  "$(_ts)" "$*"; }
warn()   { printf "[%s] ⚠️   %s\n" "$(_ts)" "$*" >&2; }
die()    { printf "[%s] ❌  %s\n"  "$(_ts)" "$*" >&2; exit 1; }
section(){ printf "\n🔷  %s\n%s\n\n" "$*" "$(printf '─%.0s' {1..55})"; }

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

# ── k3s deploy ────────────────────────────────────────────────────────────────
write_deploy_conf() {
  section "Writing $TEST_CONF"
  # k8s-deploy.sh does not support per-node ports — all nodes must share SSH_PORT.
  # Since containers have unique host ports, we can only test 1-node k3s here
  # (master only) or use the same port trick: put all workers at 127.0.0.1
  # but differentiate via the WORKERS array entries.
  # For the full test we use SSH_PORT=22 and connect via the PODMAN NETWORK IP
  # rather than port forwarding. Fall back to master-only if network IP unavailable.

  local master_net_ip
  master_net_ip=$(podman inspect "$CTR_MASTER" \
    --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")

  # On macOS, container IPs live inside the Podman VM and are never reachable from the host.
  # Test actual reachability rather than trusting the IP string.
  local net_reachable=false
  if [[ -n "$master_net_ip" && "$master_net_ip" != "127.0.0.1" ]]; then
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes \
        -i "$SSH_KEY" "root@$master_net_ip" "true" &>/dev/null && net_reachable=true || true
  fi

  if [[ "$net_reachable" == true ]]; then
    # Container IPs reachable directly (Linux host or bridged network)
    local w1_ip w2_ip
    w1_ip=$(podman inspect "${CTR_WORKERS[0]}" \
      --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)
    w2_ip=$(podman inspect "${CTR_WORKERS[1]}" \
      --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null)

    info "Using container network IPs: master=$master_net_ip workers=$w1_ip $w2_ip"
    cat > "$TEST_CONF" <<EOF
# Auto-generated by test-podman.sh
CLUSTER_NAME="hc-podman"
MASTER_IP="$master_net_ip"
MASTER_USER="root"
MASTER_SSH_KEY="$SSH_KEY"
WORKERS=("$w1_ip|root|$SSH_KEY" "$w2_ip|root|$SSH_KEY")
K8S_DISTRO="k3s"
CONTAINER_RUNTIME="none"
SSH_PORT=22
INSTALL_LOCAL_KUBECTL=true
INSTALL_LOCAL_HELM=false
INSTALL_HYPER2KVM_DEPS=false
K3S_EXTRA_ARGS="--disable traefik --disable servicelb --snapshotter=native"
EOF
  else
    # macOS / Podman machine: container IPs not reachable from host — single-node via port forwarding
    info "Container network IPs not directly reachable from host — single-node k3s on master"
    cat > "$TEST_CONF" <<EOF
# Auto-generated by test-podman.sh (single-node, port-forwarded)
CLUSTER_NAME="hc-podman"
MASTER_IP="127.0.0.1"
MASTER_USER="root"
MASTER_SSH_KEY="$SSH_KEY"
WORKERS=()
K8S_DISTRO="k3s"
CONTAINER_RUNTIME="none"
SSH_PORT=$PORT_MASTER
INSTALL_LOCAL_KUBECTL=true
INSTALL_LOCAL_HELM=false
INSTALL_HYPER2KVM_DEPS=false
K3S_EXTRA_ARGS="--disable traefik --disable servicelb --node-external-ip=127.0.0.1 --snapshotter=native"
EOF
    warn "Deploying single-node k3s (master only) — worker join requires direct container IPs."
  fi

  info "Config written: $TEST_CONF"
}

verify() {
  section "Verifying cluster"
  local kc="$HOME/.kube/config-hc-podman"
  [[ -f "$kc" ]] || die "kubeconfig not found: $kc"
  info "Nodes:"
  KUBECONFIG="$kc" kubectl get nodes -o wide
  info "System pods:"
  KUBECONFIG="$kc" kubectl get pods -A 2>/dev/null | head -20 || true
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
  local kc="$HOME/.kube/config-hc-podman"
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
    write_deploy_conf
    HC_CONFIG="$TEST_CONF" bash "$SCRIPT_DIR/k8s-deploy.sh"
    verify
    section "Done"
    info "🎉 k3s cluster running in Podman containers!"
    printf "\n    export KUBECONFIG=\$HOME/.kube/config-hc-podman\n"
    printf "    kubectl get nodes\n"
    printf "    # API also reachable at https://127.0.0.1:%s\n\n" "$PORT_API"
    info "Tear down:  ./scripts/test-podman.sh --clean"
    ;;
  *)
    die "Unknown argument: $1  (try --help)" ;;
esac
