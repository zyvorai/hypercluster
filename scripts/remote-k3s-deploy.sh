#!/usr/bin/env bash
# Full single-node stack: k3s + Cilium CNI + KubeVirt + CDI + tooling.
# Remote host needs sudo without password (or interactive sudo will hang).
set -euo pipefail

usage() {
  cat <<'USAGE'
Deploy k3s + Cilium + KubeVirt + CDI + CLI tooling on a remote Linux host (single-node).

Usage: remote-k3s-deploy.sh [options] user@host

Options:
  -h, --help     Show this help
  -i, --identity PATH   SSH private key (or set SSH_IDENTITY)
  -y, --yes      Accept host SSH key non-interactively (default: yes)
  -k, --strict   Require SSH host key verification (more secure)

Environment (forwarded to the remote — set when invoking this script):
  SKIP_SWAP_OFF=1           Do not disable swap (not recommended for Kubernetes)
  SKIP_HELM=1               Skip Helm 3 install
  SKIP_DISKS_PROVIDER=1     Skip KubeVirt disks-images-provider (sample images)
  SKIP_KVM_CHECK=1          Skip warning when /dev/kvm is missing

Example:
  ./remote-k3s-deploy.sh sus@192.0.2.1
USAGE
}

STRICT_HOSTKEY=0
ACCEPT_HOSTKEY=1
SSH_IDENTITY="${SSH_IDENTITY:-}"
TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -i|--identity)
      [[ $# -ge 2 ]] || { echo "Missing argument for $1" >&2; exit 1; }
      SSH_IDENTITY="$2"
      shift 2
      ;;
    -y|--yes) ACCEPT_HOSTKEY=1; shift ;;
    -k|--strict) STRICT_HOSTKEY=1; ACCEPT_HOSTKEY=0; shift ;;
    *)
      if [[ -z "$TARGET" && "$1" != -* ]]; then
        TARGET="$1"
        shift
      else
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "${TARGET}" ]]; then
  usage >&2
  exit 1
fi

SSH_OPTS=( -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 )
if [[ -n "$SSH_IDENTITY" ]]; then
  SSH_OPTS+=( -i "$SSH_IDENTITY" -o IdentitiesOnly=yes )
fi
if [[ "$STRICT_HOSTKEY" -eq 1 ]]; then
  SSH_OPTS+=( -o StrictHostKeyChecking=yes )
elif [[ "$ACCEPT_HOSTKEY" -eq 1 ]]; then
  SSH_OPTS+=( -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null )
fi

echo "Deploying full stack to ${TARGET}"

# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$TARGET" \
  env \
  "DEPLOY_TARGET=${TARGET}" \
  "SKIP_SWAP_OFF=${SKIP_SWAP_OFF:-}" \
  "SKIP_HELM=${SKIP_HELM:-}" \
  "SKIP_DISKS_PROVIDER=${SKIP_DISKS_PROVIDER:-}" \
  "SKIP_KVM_CHECK=${SKIP_KVM_CHECK:-}" \
  'bash -s' <<'REMOTE'
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }

log() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1 (install it and re-run)"
}

retry() {
  local attempt max=5 delay=3
  for attempt in $(seq 1 "$max"); do
    if "$@"; then return 0; fi
    warn "retry ${attempt}/${max}: $*"
    sleep "$delay"
  done
  die "giving up after ${max} attempts: $*"
}

# Prefer jq/python for GitHub JSON; fall back to sed.
gh_latest_tag() {
  local url json tag
  url="https://api.github.com/repos/$1/releases/latest"
  json=$(curl -fsSL -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$url") || return 1
  if command -v jq >/dev/null 2>&1; then
    tag=$(printf '%s' "$json" | jq -r '.tag_name // empty' | tr -d '\r\n')
  elif command -v python3 >/dev/null 2>&1; then
    tag=$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("tag_name") or "")' | tr -d '\r\n')
  else
    tag=$(printf '%s' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  fi
  tag=$(printf '%s' "$tag" | tr -d '\r\n')
  [[ -n "$tag" && "$tag" != "null" ]] || return 1
  printf '%s' "$tag"
}

K3S_BIN="/usr/local/bin/k3s"
KUBECTL="/usr/local/bin/kubectl"
VIRTCTL="/usr/local/bin/virtctl"
HELM="/usr/local/bin/helm"
CILIUM_BIN="/usr/local/bin/cilium"
KCFG="/etc/rancher/k3s/k3s.yaml"

export PATH="/usr/local/bin:/usr/local/sbin:${PATH:-}"
export KUBECONFIG="$KCFG"

kube_admin() { sudo env KUBECONFIG="$KCFG" "$@"; }

case "$(uname -m)" in
  x86_64)  KUBE_ARCH=amd64 ;;
  aarch64) KUBE_ARCH=arm64 ;;
  arm64)   KUBE_ARCH=arm64 ;;
  *)       die "unsupported architecture: $(uname -m)" ;;
esac

need_cmd curl
need_cmd sudo
need_cmd sha256sum

install_kubectl_release() {
  local ver arch="${KUBE_ARCH}"
  local tmp=/tmp/kubectl.tmp sha256_expected
  ver=$(curl -fsSL https://dl.k8s.io/release/stable.txt | tr -d '\r\n')
  [[ -n "$ver" ]] || die "could not read Kubernetes stable version"
  retry curl -fsSL "https://dl.k8s.io/release/${ver}/bin/linux/${arch}/kubectl" -o "$tmp"
  sha256_expected=$(curl -fsSL "https://dl.k8s.io/release/${ver}/bin/linux/${arch}/kubectl.sha256" | tr -d ' \r\n')
  [[ -n "$sha256_expected" ]] || die "kubectl checksum download failed"
  echo "${sha256_expected}  ${tmp}" | sha256sum -c - >/dev/null || die "kubectl SHA256 mismatch"
  sudo install -m 0755 "$tmp" "$KUBECTL"
  rm -f "$tmp"
  printf '%s' "$ver"
}

# Official tarball from get.helm.sh (avoids get-helm-3, which shells out to `helm`
# and breaks when /usr/local/bin is missing from sudo/non-interactive PATH).
install_helm_binary() {
  local ver arch="${KUBE_ARCH}"
  local tgz=/tmp/helm-linux.tgz extract_dir sum_url expected got
  ver="$(gh_latest_tag helm/helm)" || die "could not resolve Helm release"
  retry curl -fsSL "https://get.helm.sh/helm-${ver}-linux-${arch}.tar.gz" -o "$tgz"
  sum_url="https://get.helm.sh/helm-${ver}-linux-${arch}.tar.gz.sha256sum"
  if expected=$(curl -fsSL "$sum_url" 2>/dev/null | awk '{print $1}'); then
    got=$(sha256sum "$tgz" | awk '{print $1}')
    [[ "$got" == "$expected" ]] || die "Helm tarball SHA256 mismatch"
  else
    warn "could not fetch Helm checksum — proceeding without verify"
  fi
  extract_dir=$(mktemp -d)
  tar xzf "$tgz" -C "$extract_dir"
  sudo install -m 0755 "${extract_dir}/linux-${arch}/helm" "$HELM"
  rm -rf "$extract_dir" "$tgz"
  [[ -x "$HELM" ]] || die "helm binary missing after install"
  printf '%s' "$ver"
}

# --- 1. Host prep (Kubernetes + KVM guests) ---------------------------------
log "1 — Host prep (kernel, sysctl, swap, KVM)"

sudo mkdir -p /data/k3s

sudo modprobe br_netfilter 2>/dev/null || true
sudo modprobe overlay 2>/dev/null || true
sudo modprobe kvm 2>/dev/null || true
if [[ "$(uname -m)" == x86_64 ]]; then
  if grep -qi intel /proc/cpuinfo 2>/dev/null; then sudo modprobe kvm_intel 2>/dev/null || true
  elif grep -qi amd /proc/cpuinfo 2>/dev/null; then sudo modprobe kvm_amd 2>/dev/null || true
  fi
fi

if [[ ! -e /dev/kvm && "${SKIP_KVM_CHECK:-0}" != "1" ]]; then
  warn "/dev/kvm not present — nested virtualization may be off or bios settings block VMs."
fi

if [[ "${SKIP_SWAP_OFF:-0}" != "1" ]]; then
  if command -v swapon >/dev/null 2>&1 && sudo swapon --show 2>/dev/null | grep -q .; then
    log "Disabling swap (recommended for kubelet / scheduling)"
    sudo swapoff -a || true
    if [[ -f /etc/fstab ]]; then
      sudo cp -a /etc/fstab "/etc/fstab.bak.$(date +%s)" 2>/dev/null || true
      sudo sed -i '/[[:space:]]swap[[:space:]]/s/^/# /' /etc/fstab || true
    fi
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

# Common RPM/Apt hint only — do not fail if package manager missing packages.
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y qemu-kvm libvirt-client 2>/dev/null || warn "dnf install qemu-kvm skipped or failed — ensure virtualization packages exist if VMs fail to start"
elif command -v apt-get >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive sudo apt-get update -qq 2>/dev/null || true
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y qemu-kvm qemu-utils 2>/dev/null || warn "apt install qemu-kvm skipped or failed"
fi

# --- 2. k3s ------------------------------------------------------------------
log "2 — Install / upgrade k3s (latest stable channel)"

retry curl -sfL https://get.k3s.io -o /tmp/k3s-install.sh
sudo INSTALL_K3S_EXEC="\
--data-dir /data/k3s \
--flannel-backend=none \
--disable-network-policy \
--disable traefik" sh /tmp/k3s-install.sh
rm -f /tmp/k3s-install.sh

# --- 3. kubectl (verified) ---------------------------------------------------
log "3 — kubectl client (latest stable, SHA256 verified)"

KUBECTL_VERSION="$(install_kubectl_release)"

# --- 4. Wait for API ---------------------------------------------------------
log "4 — Wait for API server (node Ready comes after Cilium — flannel is disabled)"

for _ in $(seq 1 60); do
  if kube_admin "$KUBECTL" get nodes &>/dev/null; then break; fi
  sleep 2
done
kube_admin "$KUBECTL" get nodes &>/dev/null || die "API server not reachable after 120s"

sudo mkdir -p /root/.kube
sudo cp -f "$KCFG" /root/.kube/config

# --- 5. Default storage (k3s usually ships local-path) -----------------------
log "5 — Storage classes"

_default_sc=$(kube_admin "$KUBECTL" get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null || true)
if [[ -z "${_default_sc}" ]]; then
  warn "No default StorageClass — installing rancher local-path-provisioner"
  LP_VER="$(gh_latest_tag rancher/local-path-provisioner 2>/dev/null)" || true
  [[ -n "${LP_VER}" ]] || LP_VER="v0.0.30"
  retry kube_admin "$KUBECTL" apply -f "https://raw.githubusercontent.com/rancher/local-path-provisioner/${LP_VER}/deploy/local-path-storage.yaml"
  kube_admin "$KUBECTL" annotate storageclass local-path storageclass.kubernetes.io/is-default-class=true --overwrite 2>/dev/null || true
fi

# --- 6. Helm 3 (optional) ----------------------------------------------------
HELM_VERSION=""
if [[ "${SKIP_HELM:-0}" != "1" ]]; then
  log "6 — Helm 3 (latest release tarball → ${HELM})"
  HELM_VERSION="$(install_helm_binary)"
else
  log "6 — Helm 3 (skipped: SKIP_HELM=1)"
fi

# --- 7. Cilium CLI + dataplane ----------------------------------------------
log "7 — Cilium CLI (stable)"

CILIUM_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt | tr -d '\r\n')
retry curl -fsSL \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-${KUBE_ARCH}.tar.gz" \
  -o /tmp/cilium.tar.gz
sudo tar xzf /tmp/cilium.tar.gz -C /usr/local/bin
rm -f /tmp/cilium.tar.gz
[[ -x "$CILIUM_BIN" ]] || die "cilium CLI missing after extract"

log "8 — Cilium CNI (kube-proxy replacement + Hubble)"

cilium_helm_sets=(
  --wait
  --wait-duration 20m
  --set kubeProxyReplacement=true
  --set hubble.enabled=true
  --set hubble.relay.enabled=true
  --set hubble.ui.enabled=true
)
# Detect existing Helm release without requiring the helm CLI (works with SKIP_HELM=1).
if kube_admin "$KUBECTL" get secret -n kube-system 2>/dev/null | grep -qE 'sh\.helm\.release\.v1\.cilium\.'; then
  log "Cilium Helm release already exists — upgrade (not fresh install)"
  kube_admin "$CILIUM_BIN" upgrade "${cilium_helm_sets[@]}"
else
  kube_admin "$CILIUM_BIN" install "${cilium_helm_sets[@]}"
fi

kube_admin "$CILIUM_BIN" status --wait --wait-duration 25m --ignore-warnings

log "8b — Wait for Ready node (CNI now installed)"
kube_admin "$KUBECTL" wait --for=condition=Ready node --all --timeout=600s

# --- 9. KubeVirt + virtctl ----------------------------------------------------
log "9 — KubeVirt operator / CR + virtctl"

KV_VER="$(gh_latest_tag kubevirt/kubevirt)" || die "could not resolve KubeVirt release"
retry curl -fsSL "https://github.com/kubevirt/kubevirt/releases/download/${KV_VER}/virtctl-${KV_VER}-linux-${KUBE_ARCH}" -o /tmp/virtctl.bin
sudo install -m 0755 /tmp/virtctl.bin "$VIRTCTL"
rm -f /tmp/virtctl.bin

retry kube_admin "$KUBECTL" apply -f "https://github.com/kubevirt/kubevirt/releases/download/${KV_VER}/kubevirt-operator.yaml"
retry kube_admin "$KUBECTL" apply -f "https://github.com/kubevirt/kubevirt/releases/download/${KV_VER}/kubevirt-cr.yaml"

log "Waiting for KubeVirt CR (this may take several minutes)"
kube_admin "$KUBECTL" -n kubevirt wait kv kubevirt --for condition=Available --timeout=600s || warn "KubeVirt condition Available not reached — check: kubectl -n kubevirt describe kv kubevirt"

if [[ "${SKIP_DISKS_PROVIDER:-0}" != "1" ]]; then
  log "10 — Sample containerdisk images (disks-images-provider)"
  retry kube_admin "$KUBECTL" apply -f "https://github.com/kubevirt/kubevirt/releases/download/${KV_VER}/disks-images-provider.yaml" || warn "disks-images-provider apply failed (optional)"
else
  log "10 — disks-images-provider skipped (SKIP_DISKS_PROVIDER=1)"
fi

# --- 11. CDI ------------------------------------------------------------------
log "11 — CDI (containerized-data-importer)"

CDI_VER="$(gh_latest_tag kubevirt/containerized-data-importer)" || die "could not resolve CDI release"
retry kube_admin "$KUBECTL" apply -f "https://github.com/kubevirt/containerized-data-importer/releases/download/${CDI_VER}/cdi-operator.yaml"
retry kube_admin "$KUBECTL" apply -f "https://github.com/kubevirt/containerized-data-importer/releases/download/${CDI_VER}/cdi-cr.yaml"

log "Waiting for CDI"
kube_admin "$KUBECTL" -n cdi wait cdi cdi --for condition=Available --timeout=600s || warn "CDI not Available in time — check: kubectl -n cdi describe cdi cdi"

# --- 12. Helpers & UX ---------------------------------------------------------
log "12 — Helper scripts + summary files"

sudo tee /usr/local/bin/hubble-ui >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
exec kubectl port-forward -n kube-system svc/hubble-ui 12000:80
SCRIPT
sudo chmod +x /usr/local/bin/hubble-ui

sudo tee /usr/local/bin/cluster-info >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
echo "=== Nodes ==="
kubectl get nodes -o wide
echo ""
echo "=== StorageClass ==="
kubectl get storageclass
echo ""
echo "=== KubeVirt ==="
kubectl get kv -n kubevirt 2>/dev/null || true
echo ""
echo "=== CDI ==="
kubectl get cdi -n cdi 2>/dev/null || true
echo ""
echo "=== Cilium ==="
command -v cilium >/dev/null && cilium status 2>/dev/null | head -40 || true
SCRIPT
sudo chmod +x /usr/local/bin/cluster-info

sudo tee /root/k8s-env.sh >/dev/null <<ENV
# Source on the server:  source /root/k8s-env.sh
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export PATH="/usr/local/bin:\$PATH"
ENV

# --- 13. Verification --------------------------------------------------------
log "13 — Verification"

echo "--- Versions ---"
kube_admin "$KUBECTL" version --client
"$VIRTCTL" version --client 2>/dev/null || true
[[ -x "$CILIUM_BIN" ]] && "$CILIUM_BIN" version --client 2>/dev/null || true
[[ -x "$HELM" ]] && "$HELM" version --short 2>/dev/null || true

echo ""
echo "--- Cluster ---"
kube_admin "$KUBECTL" get nodes -o wide
echo ""
kube_admin "$KUBECTL" get storageclass
echo ""
kube_admin "$KUBECTL" get pods -n kube-system -l app.kubernetes.io/part-of=cilium 2>/dev/null | head -20 || true
echo ""
kube_admin "$KUBECTL" get pods -n kubevirt 2>/dev/null | head -15 || true
echo ""
kube_admin "$KUBECTL" get pods -n cdi 2>/dev/null | head -15 || true

if kube_admin "$KUBECTL" get apiservice v1beta1.metrics.k8s.io &>/dev/null; then
  echo ""
  echo "--- Metrics (metrics-server) ---"
  kube_admin "$KUBECTL" get deploy -n kube-system -l k8s-app=metrics-server 2>/dev/null || true
  kube_admin "$KUBECTL" top nodes 2>/dev/null || true
fi

log "14 — Done"

cat <<SUMMARY

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Stack summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  kubectl (client)     ${KUBECTL_VERSION}
  k3s                  (see: sudo k3s --version)
  Cilium CLI           ${CILIUM_VERSION}
  KubeVirt / virtctl   ${KV_VER}
  CDI                  ${CDI_VER}
  Helm                 ${HELM_VERSION:-skipped}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 On this server:
   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
   source /root/k8s-env.sh   # same exports
   cluster-info              # nodes, storage, kubevirt, CDI, cilium snippet
   hubble-ui                 # then open http://localhost:12000
   virtctl image-upload      # disk import to PVCs (CDI); see CDI docs

 From your laptop (same SSH target you used for this script):
   mkdir -p ~/.kube && scp ${DEPLOY_TARGET}:/etc/rancher/k3s/k3s.yaml ~/.kube/k3s-remote.yaml
   export KUBECONFIG=~/.kube/k3s-remote.yaml
   kubectl get nodes

 Docs:
   KubeVirt   https://kubevirt.io/user-guide/
   CDI        https://github.com/kubevirt/containerized-data-importer
   Cilium     https://docs.cilium.io/
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SUMMARY

REMOTE

echo "Finished deploying on ${TARGET}"
