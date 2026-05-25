#!/usr/bin/env bash
# Unit-style tests for lib/inventory.sh — no SSH or Kubespray clone required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR="${TMPDIR:-/tmp}/hypercluster-test-$$"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

assert_contains() {
  local file="$1" pattern="$2" desc="$3"
  if grep -q "$pattern" "$file"; then
    echo "  PASS: $desc"
    (( PASS++ )) || true
  else
    echo "  FAIL: $desc (pattern '$pattern' not in $file)" >&2
    (( FAIL++ )) || true
  fi
}

assert_file_exists() {
  local file="$1" desc="$2"
  if [[ -f "$file" ]]; then
    echo "  PASS: $desc"
    (( PASS++ )) || true
  else
    echo "  FAIL: $desc (missing $file)" >&2
    (( FAIL++ )) || true
  fi
}

setup_fixture() {
  mkdir -p "$TMPDIR/inventory"
  # shellcheck source=/dev/null
  source "$REPO_DIR/lib/log.sh"
  # shellcheck source=/dev/null
  source "$REPO_DIR/lib/inventory.sh"

  CLUSTER_NAME="testcluster"
  KUBE_VERSION="v1.32.0"
  CONTAINER_MANAGER="podman"
  CNI_PLUGIN="cilium"
  KUBE_PODS_SUBNET="10.233.64.0/18"
  KUBE_SERVICE_ADDRESSES="10.233.0.0/18"
  SSH_USER="root"
  SSH_KEY="$HOME/.ssh/id_rsa"
  CONTROL_PLANE_IPS="10.0.0.1 10.0.0.2"
  WORKER_IPS="10.0.0.3 10.0.0.4"
  METRICS_SERVER_ENABLED="true"
  INGRESS_NGINX_ENABLED="false"
  DASHBOARD_ENABLED="false"
}

echo "Running inventory generation tests …"
setup_fixture

inventory::generate_hosts_yaml "$TMPDIR/inventory"
inventory::generate_group_vars "$TMPDIR/inventory"

HOSTS="$TMPDIR/inventory/hosts.yaml"
K8S_CLUSTER="$TMPDIR/inventory/group_vars/k8s_cluster/k8s-cluster.yml"
ADDONS="$TMPDIR/inventory/group_vars/k8s_cluster/addons.yml"
ALL_YML="$TMPDIR/inventory/group_vars/all/all.yml"

assert_file_exists "$HOSTS" "hosts.yaml generated"
assert_file_exists "$K8S_CLUSTER" "k8s-cluster.yml generated"
assert_file_exists "$ADDONS" "addons.yml generated"
assert_file_exists "$ALL_YML" "all.yml generated"

assert_contains "$HOSTS" "master1:" "control-plane master1 present"
assert_contains "$HOSTS" "master2:" "control-plane master2 present"
assert_contains "$HOSTS" "worker1:" "worker1 present"
assert_contains "$HOSTS" "worker2:" "worker2 present"
assert_contains "$HOSTS" "ansible_host: 10.0.0.1" "master1 IP set"
assert_contains "$HOSTS" "kube_control_plane:" "kube_control_plane group present"
assert_contains "$K8S_CLUSTER" "kube_version: v1.32.0" "kube version in group_vars"
assert_contains "$K8S_CLUSTER" "container_manager: podman" "container manager in group_vars"
assert_contains "$K8S_CLUSTER" "kube_network_plugin: cilium" "CNI plugin in group_vars"
assert_contains "$ADDONS" "metrics_server_enabled: true" "metrics-server addon enabled"
assert_contains "$ALL_YML" "ansible_user: root" "SSH user in all.yml"

# Non-standard SSH port
SSH_PORT=2222
inventory::generate_hosts_yaml "$TMPDIR/inventory"
assert_contains "$HOSTS" "ansible_port: 2222" "custom SSH port emitted"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]] || exit 1
