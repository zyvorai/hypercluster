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
    # shellcheck disable=SC2086
    if ! ssh -i "$key" \
             -o ConnectTimeout=10 \
             -o BatchMode=yes \
             -o StrictHostKeyChecking=accept-new \
             ${SSH_EXTRA_ARGS:-} \
             "$user@$ip" "echo ok" &>/dev/null; then
      log::error "Cannot reach $user@$ip"
      (( failed++ )) || true
    else
      log::ok "$user@$ip reachable"
    fi
  done

  [[ "$failed" -eq 0 ]] || die "SSH connectivity check failed for $failed node(s)."
}

preflight::run() {
  log::section "Preflight checks"

  local required_cmds=(ansible ansible-playbook python3 ssh scp git kubectl)
  local failed=0

  for cmd in "${required_cmds[@]}"; do
    preflight::check_command "$cmd" || (( failed++ )) || true
  done

  for mod in jinja2 netaddr; do
    preflight::check_python_module "$mod" || (( failed++ )) || true
  done

  [[ "$failed" -eq 0 ]] || die "Fix the $failed missing dependency/dependencies above, then re-run."
  log::ok "All required tools present."

  preflight::check_ssh_key "$SSH_KEY"

  local all_ips=($CONTROL_PLANE_IPS $WORKER_IPS)
  preflight::check_ssh_connectivity "$SSH_USER" "${SSH_KEY/#\~/$HOME}" "${all_ips[@]}"

  log::ok "Preflight passed. 🚀"
}
