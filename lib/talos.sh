#!/usr/bin/env bash
# Talos Linux — machine config apply (preview / stub)

talos::deploy() {
  die "Talos deploy adapter is preview-only. Generate machine configs with talosctl and apply manually, or use k3s/Kubespray for SSH-based deploy."
}

talos::fetch_kubeconfig() {
  local kc="${KUBECONFIG_OUTPUT/#\~/$HOME}"
  if command -v talosctl >/dev/null 2>&1 && [[ -n "${TALOS_ENDPOINT:-}" ]]; then
    mkdir -p "$(dirname "$kc")"
    talosctl kubeconfig "$kc" --nodes "${TALOS_ENDPOINT}"
    log::ok "Talos kubeconfig written to $kc"
    return 0
  fi
  die "Talos kubeconfig fetch requires talosctl and TALOS_ENDPOINT in cluster.conf"
}
