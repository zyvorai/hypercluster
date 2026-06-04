#!/usr/bin/env bash
# Preflight checks — source this file, do not execute directly.

preflight::check_command() {
  local cmd="$1"
  if ! command -v "$cmd" &>/dev/null; then
    log::error "Required command not found: $cmd"
    return 1
  fi
  log::debug "found $cmd at $(command -v "$cmd")"
}

preflight::check_python_module() {
  local mod="$1"
  if ! python3 -c "import $mod" &>/dev/null; then
    log::error "Required Python module not found: $mod   (pip3 install $mod)"
    return 1
  fi
}

preflight::check_ssh_key() {
  local key="${1/#\~/$HOME}"
  [[ -f "$key" ]] || die "SSH key not found: $key"
  local perms
  perms=$(stat -c %a "$key" 2>/dev/null || stat -f %Lp "$key")
  if [[ "$perms" != "600" ]]; then
    log::warn "SSH key permissions are $perms — fixing to 600: $key"
    chmod 600 "$key"
  fi
}

preflight::check_ssh_connectivity() {
  local user="$1" key="$2"
  shift 2
  local ips=("$@")
  local failed=0

  for ip in "${ips[@]}"; do
    log::info "Testing SSH → $user@$ip …"
    local ssh_opts=(-i "$key" -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)
    [[ -n "${SSH_PORT:-}" && "${SSH_PORT}" != "22" ]] && ssh_opts+=(-p "$SSH_PORT")
    [[ -n "${SSH_EXTRA_ARGS:-}" ]] && ssh_opts+=(${SSH_EXTRA_ARGS})
    # shellcheck disable=SC2086
    if ! ssh "${ssh_opts[@]}" "$user@$ip" "echo ok" &>/dev/null; then
      log::error "Cannot reach $user@$ip"
      (( failed++ )) || true
    else
      log::ok "$user@$ip reachable"
    fi
  done

  [[ "$failed" -eq 0 ]] || die "SSH connectivity check failed for $failed node(s)."
}

preflight::_ssh_first_cp() {
  local key="${SSH_KEY/#\~/$HOME}" ip
  ip=$(echo "$CONTROL_PLANE_IPS" | awk '{print $1}')
  local opts=(-i "$key" -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)
  [[ -n "${SSH_PORT:-}" && "${SSH_PORT}" != "22" ]] && opts+=(-p "$SSH_PORT")
  [[ -n "${SSH_EXTRA_ARGS:-}" ]] && opts+=(${SSH_EXTRA_ARGS})
  # shellcheck disable=SC2029
  ssh "${opts[@]}" "$SSH_USER@$ip" "$@"
}

preflight::check_k3s_remote() {
  log::info "Checking passwordless sudo on control plane …"
  if ! preflight::_ssh_first_cp "sudo -n true" 2>/dev/null; then
    die "Passwordless sudo required on remote nodes for k3s deploy.
       On the server run: echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${SSH_USER}-hypercluster"
  fi
  log::ok "Passwordless sudo OK"

  if [[ "${METALLB_ENABLED:-true}" == "true" && -z "${METALLB_IP_POOL:-}" ]]; then
    die "METALLB_ENABLED=true but METALLB_IP_POOL is empty.
       Set METALLB_IP_POOL=\"192.168.1.240-192.168.1.250\" in cluster.conf"
  fi
  if [[ -n "${METALLB_IP_POOL:-}" ]]; then
    log::ok "MetalLB pool configured: ${METALLB_IP_POOL}"
  fi

  if [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    log::info "Checking /dev/kvm on control plane …"
    if ! preflight::_ssh_first_cp "test -e /dev/kvm" 2>/dev/null; then
      log::warn "/dev/kvm not present — KubeVirt VMs may fail unless useEmulation is enabled"
    else
      log::ok "/dev/kvm present"
    fi
  fi
}

preflight::run() {
  log::section "Preflight checks"

  local required_cmds=(ssh scp git kubectl curl)
  local failed=0
  local distro="${K8S_DISTRO:-kubespray}"

  if [[ "$distro" == "kubespray" ]]; then
    required_cmds+=(ansible ansible-playbook python3)
  elif [[ "$distro" == "k3s" ]]; then
    required_cmds+=(helm)
    if [[ "${CILIUM_HUBBLE_ENABLED:-true}" == "true" ]] && ! command -v cilium &>/dev/null; then
      log::warn "cilium CLI not found — Hubble UI commands will be unavailable (brew install cilium-cli)"
    fi
  else
    die "Unknown K8S_DISTRO: $distro (use kubespray or k3s)"
  fi

  for cmd in "${required_cmds[@]}"; do
    preflight::check_command "$cmd" || (( failed++ )) || true
  done

  if [[ "$distro" == "kubespray" ]]; then
    for mod in jinja2 netaddr; do
      preflight::check_python_module "$mod" || (( failed++ )) || true
    done
  fi

  [[ "$failed" -eq 0 ]] || die "Fix the $failed missing dependency/dependencies above, then re-run."
  log::ok "All required tools present."

  preflight::check_ssh_key "$SSH_KEY"

  local all_ips=($CONTROL_PLANE_IPS $WORKER_IPS)
  preflight::check_ssh_connectivity "$SSH_USER" "${SSH_KEY/#\~/$HOME}" "${all_ips[@]}"

  if [[ "$distro" == "k3s" ]]; then
    preflight::check_k3s_remote
  fi

  log::ok "Preflight passed. 🚀"
}
