#!/usr/bin/env bash
# RKE2 cluster deployment over SSH

rke2::_key() { echo "${SSH_KEY/#\~/$HOME}"; }

rke2::_ssh_opts() {
  local -n _ref="$1"
  _ref=(
    -i "$(rke2::_key)"
    -o BatchMode=yes
    -o ConnectTimeout=20
    -o StrictHostKeyChecking=accept-new
  )
  [[ -n "${SSH_PORT:-}" && "${SSH_PORT}" != "22" ]] && _ref+=(-p "$SSH_PORT")
  [[ -n "${SSH_EXTRA_ARGS:-}" ]] && _ref+=(${SSH_EXTRA_ARGS})
}

rke2::_ssh() {
  local ip="$1" cmd="$2"
  local opts=()
  rke2::_ssh_opts opts
  # shellcheck disable=SC2029
  ssh "${opts[@]}" "$SSH_USER@$ip" "$cmd"
}

rke2::_first_cp() {
  echo "$CONTROL_PLANE_IPS" | awk '{print $1}'
}

rke2::deploy() {
  local first
  first="$(rke2::_first_cp)"
  [[ -n "$first" ]] || die "CONTROL_PLANE_IPS required for RKE2"
  local ver="${RKE2_VERSION:-${KUBE_VERSION:-}}"
  local install="curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_VERSION='${ver}' sh -"
  log::section "RKE2 server on $first"
  rke2::_ssh "$first" "$install"
  rke2::_ssh "$first" "sudo systemctl enable rke2-server && sudo systemctl start rke2-server"
  local token
  token="$(rke2::_ssh "$first" "sudo cat /var/lib/rancher/rke2/server/node-token")"
  local ip w
  for ip in $WORKER_IPS; do
    [[ -n "$ip" ]] || continue
    log::info "RKE2 agent on $ip"
    rke2::_ssh "$ip" "$install"
    rke2::_ssh "$ip" "sudo mkdir -p /etc/rancher/rke2 && echo \"server: https://${first}:9345\" | sudo tee /etc/rancher/rke2/config.yaml && echo \"token: ${token}\" | sudo tee -a /etc/rancher/rke2/config.yaml"
    rke2::_ssh "$ip" "sudo systemctl enable rke2-agent && sudo systemctl start rke2-agent"
  done
  for w in $(echo "$CONTROL_PLANE_IPS" | awk '{$1=""; print $0}'); do
    [[ -n "$w" ]] || continue
    log::info "RKE2 additional server $w"
    rke2::_ssh "$w" "$install"
    rke2::_ssh "$w" "sudo mkdir -p /etc/rancher/rke2 && echo \"server: https://${first}:9345\" | sudo tee /etc/rancher/rke2/config.yaml && echo \"token: ${token}\" | sudo tee -a /etc/rancher/rke2/config.yaml"
    rke2::_ssh "$w" "sudo systemctl enable rke2-server && sudo systemctl start rke2-server"
  done
  log::ok "RKE2 cluster bootstrap complete"
}

rke2::fetch_kubeconfig() {
  local first kc
  first="$(rke2::_first_cp)"
  kc="${KUBECONFIG_OUTPUT/#\~/$HOME}"
  mkdir -p "$(dirname "$kc")"
  rke2::_ssh "$first" "sudo cat /etc/rancher/rke2/rke2.yaml" | sed "s/127.0.0.1/${first}/g" >"$kc"
  log::ok "kubeconfig written to $kc"
}
