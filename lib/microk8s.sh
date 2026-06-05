#!/usr/bin/env bash
# MicroK8s deployment over SSH (snap)

microk8s::_key() { echo "${SSH_KEY/#\~/$HOME}"; }

microk8s::_ssh_opts() {
  local -n _ref="$1"
  _ref=(
    -i "$(microk8s::_key)"
    -o BatchMode=yes
    -o ConnectTimeout=20
    -o StrictHostKeyChecking=accept-new
  )
  [[ -n "${SSH_PORT:-}" && "${SSH_PORT}" != "22" ]] && _ref+=(-p "$SSH_PORT")
  [[ -n "${SSH_EXTRA_ARGS:-}" ]] && _ref+=(${SSH_EXTRA_ARGS})
}

microk8s::_ssh() {
  local ip="$1" cmd="$2"
  local opts=()
  microk8s::_ssh_opts opts
  # shellcheck disable=SC2029
  ssh "${opts[@]}" "$SSH_USER@$ip" "$cmd"
}

microk8s::_first_cp() {
  echo "$CONTROL_PLANE_IPS" | awk '{print $1}'
}

microk8s::deploy() {
  local ip first
  first="$(microk8s::_first_cp)"
  [[ -n "$first" ]] || die "CONTROL_PLANE_IPS required for MicroK8s"
  local channel="${MICROK8S_CHANNEL:-1.30/stable}"
  for ip in $CONTROL_PLANE_IPS $WORKER_IPS; do
    [[ -n "$ip" ]] || continue
    log::info "Installing MicroK8s on $ip ($channel)"
    microk8s::_ssh "$ip" "sudo snap install microk8s --classic --channel=${channel} || sudo snap refresh microk8s --channel=${channel}"
    microk8s::_ssh "$ip" "sudo usermod -aG microk8s ${SSH_USER} 2>/dev/null || true"
  done
  microk8s::_ssh "$first" "sudo microk8s status --wait-ready"
  local join
  join="$(microk8s::_ssh "$first" "sudo microk8s add-node" | grep -oE 'microk8s join [^ ]+ [^ ]+' | head -1)"
  for ip in $WORKER_IPS; do
    [[ -n "$ip" ]] || continue
    [[ "$ip" == "$first" ]] && continue
    log::info "Joining worker $ip"
    microk8s::_ssh "$ip" "sudo $join"
  done
  log::ok "MicroK8s cluster ready"
}

microk8s::fetch_kubeconfig() {
  local first kc
  first="$(microk8s::_first_cp)"
  kc="${KUBECONFIG_OUTPUT/#\~/$HOME}"
  mkdir -p "$(dirname "$kc")"
  microk8s::_ssh "$first" "sudo microk8s config" >"$kc"
  log::ok "kubeconfig written to $kc"
}
