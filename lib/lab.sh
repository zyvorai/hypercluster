#!/usr/bin/env bash
# lab.sh — single-node k3s lab tuning: secondary disk for KubeVirt PVCs, memory relief.
# Source from hypercluster after cluster.conf is loaded.

lab::_kc() {
  echo "${KUBECONFIG_OUTPUT/#\~/$HOME}"
}

lab::_kubectl() {
  local kc
  kc="$(lab::_kc)"
  [[ -f "$kc" ]] || die "kubeconfig not found: $kc (run deploy or fetch-kubeconfig first)"
  KUBECONFIG="$kc" kubectl "$@"
}

lab::_first_cp() {
  k3s::_first_cp_ip
}

lab::_mount() {
  echo "${LAB_KUBEVIRT_VOLUME_MOUNT:-/data/kubevirt-volumes}"
}

lab::_pvc_path() {
  echo "${LAB_KUBEVIRT_VOLUME_SUBPATH:-$(lab::_mount)/pvc}"
}

lab::_storage_class() {
  echo "${LAB_KUBEVIRT_STORAGE_CLASS:-kubevirt-sdb}"
}

lab::_primary_storage_path() {
  if [[ -n "${K3S_DATA_DIR:-}" ]]; then
    echo "${K3S_DATA_DIR}/storage"
  else
    echo "/var/lib/rancher/k3s/storage"
  fi
}

lab::memory_tune() {
  local mode="${1:-apply}"
  [[ "${K8S_DISTRO:-kubespray}" == "k3s" ]] || die "lab tune is for K8S_DISTRO=k3s only"

  lab::_scale_deploy() {
    local ns="$1" dep="$2" replicas="$3"
    if lab::_kubectl get deploy "$dep" -n "$ns" &>/dev/null; then
      lab::_kubectl scale deployment "$dep" -n "$ns" --replicas="$replicas"
      log::ok "scaled $ns/$dep -> $replicas"
    else
      log::info "skip $ns/$dep (not installed)"
    fi
  }

  log::section "Lab memory tune ($mode)"
  if [[ "$mode" == "restore" ]]; then
    lab::_scale_deploy forge forge-ui 2
    lab::_scale_deploy ironwolf-system ironwolf-controller-manager 2
    lab::_scale_deploy kubevirt virt-operator 2
    lab::_scale_deploy kubevirt virt-controller 2
    lab::_scale_deploy kube-system snapshot-controller 2
  else
    lab::_scale_deploy forge forge-ui 1
    lab::_scale_deploy ironwolf-system ironwolf-controller-manager 1
    lab::_scale_deploy kubevirt virt-operator 1
    lab::_scale_deploy kubevirt virt-controller 1
    lab::_scale_deploy kube-system snapshot-controller 1
  fi

  log::info "KubeVirt may restore virt-controller replicas on reconcile (HA default)."
  lab::_kubectl top nodes 2>/dev/null || log::info "metrics-server not ready for kubectl top"
}

lab::storage_patch_local_path() {
  local primary secondary
  primary="$(lab::_primary_storage_path)"
  secondary="$(lab::_pvc_path)"

  if ! KC="$(lab::_kc)" PRIMARY="$primary" SECONDARY="$secondary" python3 - <<'PY'
import json, os, subprocess, sys

kc = os.environ["KC"]
primary = os.environ["PRIMARY"]
secondary = os.environ["SECONDARY"]

def kubectl(*args):
    return subprocess.run(["kubectl", "--kubeconfig", kc, *args], capture_output=True, text=True)

raw = kubectl("get", "cm", "local-path-config", "-n", "kube-system",
              "-o", "jsonpath={.data.config\\.json}")
if raw.returncode != 0:
    print(raw.stderr or raw.stdout, file=sys.stderr)
    sys.exit(1)

cfg = json.loads(raw.stdout or "{}")
if not cfg.get("nodePathMap"):
    cfg["nodePathMap"] = [{"node": "DEFAULT_PATH_FOR_NON_LISTED_NODES", "paths": [primary]}]

paths = list(cfg["nodePathMap"][0].setdefault("paths", []))
changed = False
for p in (primary, secondary):
    if p and p not in paths:
        paths.append(p)
        changed = True
cfg["nodePathMap"][0]["paths"] = paths

if not changed:
    print("local-path already includes:", paths)
    sys.exit(0)

patch = json.dumps({"data": {"config.json": json.dumps(cfg, indent=2)}})
r = kubectl("patch", "cm", "local-path-config", "-n", "kube-system",
            "--type", "merge", "-p", patch)
if r.returncode != 0:
    print(r.stderr or r.stdout, file=sys.stderr)
    sys.exit(1)
print("local-path paths:", paths)
PY
  then
    die "failed to patch local-path-config"
  fi

  if lab::_kubectl get deploy local-path-provisioner -n kube-system &>/dev/null; then
    lab::_kubectl rollout restart deployment/local-path-provisioner -n kube-system
    lab::_kubectl rollout status deployment/local-path-provisioner -n kube-system --timeout=120s 2>/dev/null \
      || log::warn "local-path-provisioner restart still rolling"
  fi
  log::ok "local-path-config updated"
}

lab::storage_apply_class() {
  local sc desc mount
  sc="$(lab::_storage_class)"
  mount="$(lab::_mount)"
  desc="KubeVirt VM disks on secondary volume ($mount)"

  lab::_kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ${sc}
  annotations:
    storageclass.kubernetes.io/description: "${desc}"
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
  log::ok "StorageClass ${sc} ready (use storageClassName: ${sc} on DataVolumes / PVCs)"
}

lab::storage_remote_mount() {
  local ip disk mount subpath format
  ip="$(lab::_first_cp)"
  disk="${LAB_SECONDARY_DISK:-}"
  mount="$(lab::_mount)"
  subpath="$(lab::_pvc_path)"
  format="${LAB_STORAGE_FORMAT:-0}"

  [[ -n "$disk" ]] || die "LAB_SECONDARY_DISK is empty — set it in cluster.conf (e.g. /dev/sdb)"

  log::section "Lab storage: mount $disk on $ip"
  log::info "Mount point: $mount  PVC subpath: $subpath"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — skip remote disk setup on $ip"
    return 0
  fi

  # shellcheck disable=SC2029
  k3s::_ssh "$ip" "DISK='${disk}' MOUNT='${mount}' SUBPATH='${subpath}' FORMAT='${format}' bash -s" <<'REMOTE'
set -euo pipefail
if [[ ! -b "$DISK" ]]; then
  echo "ERROR: $DISK is not a block device" >&2
  exit 1
fi
sudo mkdir -p "$MOUNT"
if mountpoint -q "$MOUNT"; then
  echo "already mounted: $MOUNT"
else
  if ! sudo blkid "$DISK" >/dev/null 2>&1; then
    if [[ "$FORMAT" != "1" ]]; then
      echo "ERROR: $DISK has no filesystem — set LAB_STORAGE_FORMAT=1 in cluster.conf to mkfs" >&2
      exit 1
    fi
    echo "Formatting $DISK (xfs)..."
    sudo mkfs.xfs -f "$DISK"
  fi
  sudo mount "$DISK" "$MOUNT"
fi
UUID=$(sudo blkid -s UUID -o value "$DISK")
if ! grep -q "$MOUNT" /etc/fstab 2>/dev/null; then
  echo "UUID=$UUID  $MOUNT  xfs  defaults,noatime  0  2" | sudo tee -a /etc/fstab >/dev/null
fi
sudo mkdir -p "$SUBPATH"
sudo chmod 777 "$SUBPATH"
df -h "$MOUNT"
lsblk "$DISK"
REMOTE
  log::ok "secondary disk mounted at $mount on $ip"
}

lab::storage_status() {
  local ip mount sc
  ip="$(lab::_first_cp)"
  mount="$(lab::_mount)"
  sc="$(lab::_storage_class)"

  log::section "Lab storage status"
  printf "  node:           %s@%s\n" "${SSH_USER:-root}" "$ip"
  printf "  disk:           %s\n" "${LAB_SECONDARY_DISK:-(unset)}"
  printf "  mount:          %s\n" "$mount"
  printf "  storage class:  %s\n" "$sc"
  echo ""

  if [[ -n "${LAB_SECONDARY_DISK:-}" ]]; then
    # shellcheck disable=SC2029
    k3s::_ssh "$ip" "MOUNT='${mount}' DISK='${LAB_SECONDARY_DISK}' bash -s" <<'REMOTE' || true
set -euo pipefail
if mountpoint -q "$MOUNT" 2>/dev/null; then
  df -h "$MOUNT"
else
  echo "  mount: not mounted ($MOUNT)"
fi
if [[ -b "$DISK" ]]; then
  sudo blkid "$DISK" 2>/dev/null || echo "  disk: $DISK (no fstype)"
fi
REMOTE
  fi

  echo ""
  lab::_kubectl get storageclass "$(lab::_storage_class)" 2>/dev/null \
    || log::info "StorageClass $(lab::_storage_class) not created yet"
  echo ""
  lab::_kubectl get cm local-path-config -n kube-system \
    -o jsonpath='{.data.config.json}{"\n"}' 2>/dev/null \
    || log::info "local-path-config not found"
}

lab::storage_setup() {
  [[ "${K8S_DISTRO:-kubespray}" == "k3s" ]] || die "lab storage is for K8S_DISTRO=k3s only"
  [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]] || log::warn "KUBEVIRT_ENABLED is not true — storage still usable for PVCs"

  lab::storage_remote_mount
  lab::storage_patch_local_path
  lab::storage_apply_class
  log::ok "lab storage setup complete"
}

lab::setup() {
  log::section "Lab setup (cluster.conf)"
  if [[ -n "${LAB_SECONDARY_DISK:-}" ]]; then
    lab::storage_setup
  else
    log::info "LAB_SECONDARY_DISK unset — skip storage (set in cluster.conf to enable)"
  fi
  if [[ "${LAB_MEMORY_TUNE_ENABLED:-false}" == "true" ]]; then
    lab::memory_tune apply
  else
    log::info "LAB_MEMORY_TUNE_ENABLED not true — skip memory tune (or: hypercluster lab tune)"
  fi
  log::ok "lab setup finished"
}

lab::run() {
  local sub="${1:-}"
  shift || true
  case "$sub" in
    tune)
      local mode="apply"
      for arg in "$@"; do
        case "$arg" in
          --restore) mode="restore" ;;
          --apply) mode="apply" ;;
          -h|--help)
            cat <<'EOF'
lab tune — scale down HA replicas on single-node labs

  hypercluster lab tune           # apply (default)
  hypercluster lab tune --restore # restore HA replica counts
EOF
            return 0
            ;;
          *) die "unknown lab tune arg: $arg" ;;
        esac
      done
      lab::memory_tune "$mode"
      ;;
    storage)
      local action="setup"
      for arg in "$@"; do
        case "$arg" in
          --status) action="status" ;;
          --setup) action="setup" ;;
          -h|--help)
            cat <<'EOF'
lab storage — secondary disk for KubeVirt PVCs (local-path)

  hypercluster lab storage            # mount disk + patch local-path + StorageClass
  hypercluster lab storage --status   # show mount and StorageClass state

  cluster.conf:
    LAB_SECONDARY_DISK="/dev/sdb"
    LAB_KUBEVIRT_VOLUME_MOUNT="/data/kubevirt-volumes"
    LAB_KUBEVIRT_STORAGE_CLASS="kubevirt-sdb"
    LAB_STORAGE_FORMAT="1"            # allow mkfs on empty disk (destructive)
EOF
            return 0
            ;;
          *) die "unknown lab storage arg: $arg" ;;
        esac
      done
      if [[ "$action" == "status" ]]; then
        lab::storage_status
      else
        lab::storage_setup
      fi
      ;;
    setup)
      lab::setup
      ;;
    ""|-h|--help)
      cat <<'EOF'
lab — single-node k3s lab operations

  hypercluster lab setup              # storage (if LAB_SECONDARY_DISK) + tune (if enabled)
  hypercluster lab storage [--status] # secondary disk + kubevirt StorageClass
  hypercluster lab tune [--restore]   # reduce replica counts to save RAM

See config/cluster.conf.example (Lab operations section).
EOF
      ;;
    *)
      die "unknown lab subcommand: $sub (try: lab setup | storage | tune)"
      ;;
  esac
}
