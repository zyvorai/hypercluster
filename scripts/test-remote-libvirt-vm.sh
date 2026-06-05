#!/usr/bin/env bash
# Create a tiny libvirt VM on a remote hypervisor for hypercluster discover UX tests.
# Usage: ./scripts/test-remote-libvirt-vm.sh [user@host]
set -euo pipefail

TARGET="${1:-sus@175.110.114.93}"
VM_NAME="${VM_NAME:-hc-ux-libvirt-test}"

ssh -o BatchMode=yes "$TARGET" "VM_NAME='$VM_NAME' bash -s" <<'REMOTE'
set -euo pipefail
VM_NAME="${VM_NAME:-hc-ux-libvirt-test}"
IMG="/var/lib/libvirt/images/${VM_NAME}.qcow2"
BASE="/var/lib/libvirt/images/fedora-cloud-base.qcow2"
URL="https://download.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-41-1.4.x86_64.qcow2"

if ! sudo virsh dominfo "$VM_NAME" >/dev/null 2>&1; then
  if [[ ! -f "$BASE" ]]; then
    echo "→ Downloading Fedora cloud base image…"
    sudo curl -fsSL "$URL" -o "$BASE"
  fi
  echo "→ Creating VM $VM_NAME…"
  sudo qemu-img create -f qcow2 -F qcow2 -b "$BASE" "$IMG" 8G
  sudo virt-install \
    --name "$VM_NAME" \
    --memory 1024 \
    --vcpus 1 \
    --disk path="$IMG",format=qcow2 \
    --import \
    --os-variant fedora41 \
    --network network=default \
    --graphics none \
    --noautoconsole
fi

echo "→ Waiting for guest IP (up to 120s)…"
ip=""
for _ in $(seq 1 24); do
  ip="$(sudo virsh domifaddr "$VM_NAME" --source lease 2>/dev/null | awk '/ipv4/ {print $4; exit}' | cut -d/ -f1 || true)"
  [[ -n "$ip" ]] && break
  sleep 5
done

sudo virsh list --all
echo "VM=$VM_NAME IP=${ip:-pending}"

if [[ -n "$ip" ]]; then
  echo "→ hypercluster discover (libvirt) on hypervisor…"
  if command -v hypercluster >/dev/null 2>&1; then
    hypercluster discover --json --source libvirt --uri qemu:///system || true
  elif [[ -x /opt/hypercluster/hypercluster ]]; then
    /opt/hypercluster/hypercluster discover --json --source libvirt --uri qemu:///system || true
  else
    echo "(hypercluster not installed on host — skip discover)"
  fi
fi
REMOTE
