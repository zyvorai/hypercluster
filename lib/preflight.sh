#!/usr/bin/env bash
# Preflight checks — source this file, do not execute directly.

# shellcheck source=lib/python-pip.sh
source "${HYPERCLUSTER_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/python-pip.sh"

preflight::_json_mode() { [[ "${HC_JSON:-0}" == "1" ]]; }

preflight::_record() {
  local status="$1" name="$2" detail="${3:-}"
  if preflight::_json_mode; then
    PREFLIGHT_CHECKS+=("${status}:${name}:${detail}")
    [[ "$status" == "pass" ]] || PREFLIGHT_FAILED=$(( PREFLIGHT_FAILED + 1 ))
    return 0
  fi
  return 0
}

preflight::_pass() {
  preflight::_record pass "$1" "${2:-}"
  log::ok "${1}${2:+ — $2}"
}

preflight::_fail() {
  preflight::_record fail "$1" "${2:-}"
  log::error "${1}${2:+ — $2}"
}

preflight::check_command() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    preflight::_pass "Command: $cmd" "$(command -v "$cmd")"
    return 0
  fi
  preflight::_fail "Command: $cmd" "not found"
  return 1
}

preflight::check_python_module() {
  local mod="$1" py
  py="$(python::bin)"
  if "$py" -c "import $mod" &>/dev/null; then
    preflight::_pass "Python module: $mod"
    return 0
  fi
  preflight::_fail "Python module: $mod" "$(pip::module_install_hint "$mod")"
  return 1
}

preflight::check_python() {
  local py ver
  if ! py="$(python::resolve 2>/dev/null)"; then
    preflight::_fail "Python 3.11+" "not found — macOS: brew install python@3.12 && ./scripts/setup-macos.sh"
    return 1
  fi
  ver="$("$py" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
  preflight::_pass "Python 3.11+" "$py ($ver)"
}

preflight::check_ssh_key() {
  local key="${1/#\~/$HOME}"
  if [[ ! -f "$key" ]]; then
    preflight::_fail "SSH key" "not found: $key"
    die "SSH key not found: $key"
  fi
  local perms
  perms=$(stat -c %a "$key" 2>/dev/null || stat -f %Lp "$key")
  if [[ "$perms" != "600" ]]; then
    log::warn "SSH key permissions are $perms — fixing to 600: $key"
    chmod 600 "$key"
  fi
  preflight::_pass "SSH key" "$key"
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
      preflight::_fail "SSH connectivity: $user@$ip"
      (( failed++ )) || true
    else
      preflight::_pass "SSH connectivity: $user@$ip"
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
  if preflight::_ssh_first_cp "sudo -n true" 2>/dev/null; then
    preflight::_pass "Passwordless sudo on control plane"
  else
    preflight::_fail "Passwordless sudo on control plane" "required for k3s deploy"
    die "Passwordless sudo required on remote nodes for k3s deploy.
       On the server run: echo '${SSH_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${SSH_USER}-hypercluster"
  fi

  if [[ "${METALLB_ENABLED:-true}" == "true" && -z "${METALLB_IP_POOL:-}" ]]; then
    preflight::_fail "MetalLB IP pool" "METALLB_ENABLED=true but METALLB_IP_POOL is empty"
    die "METALLB_ENABLED=true but METALLB_IP_POOL is empty.
       Set METALLB_IP_POOL=\"192.168.1.240-192.168.1.250\" in cluster.conf"
  fi
  if [[ -n "${METALLB_IP_POOL:-}" ]]; then
    preflight::_pass "MetalLB IP pool" "${METALLB_IP_POOL}"
  fi

  if [[ "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    log::info "Checking /dev/kvm on control plane …"
    if preflight::_ssh_first_cp "test -e /dev/kvm" 2>/dev/null; then
      preflight::_pass "/dev/kvm on control plane"
    else
      preflight::_fail "/dev/kvm on control plane" "KubeVirt may need useEmulation"
      log::warn "/dev/kvm not present — KubeVirt VMs may fail unless useEmulation is enabled"
    fi
  fi

  if [[ "${CNAO_ENABLED:-true}" == "true" && "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    if [[ -n "${CNAO_HELM_REPO:-}" ]]; then
      preflight::_pass "CNAO helm repo configured" "${CNAO_HELM_REPO}"
    else
      preflight::_pass "CNAO install" "manifest fallback available if Helm chart missing"
    fi
  fi

  if [[ "${SSP_ENABLED:-true}" == "true" && "${KUBEVIRT_ENABLED:-false}" == "true" ]]; then
    if [[ -n "${SSP_HELM_REPO:-}" ]]; then
      preflight::_pass "SSP helm repo configured" "${SSP_HELM_REPO}"
    else
      preflight::_pass "SSP install" "Helm chart may be unavailable — non-blocking"
    fi
  fi
}

preflight::emit_json() {
  CHECKS="$(printf '%s\n' "${PREFLIGHT_CHECKS[@]}")" \
    FAILED="$PREFLIGHT_FAILED" \
    python3 <<'PY'
import json, os
checks = []
for line in os.environ.get("CHECKS", "").splitlines():
    if not line:
        continue
    status, name, detail = (line.split(":", 2) + ["", ""])[:3]
    item = {"name": name, "passed": status == "pass"}
    if detail:
        item["detail"] = detail
    checks.append(item)
ok = int(os.environ.get("FAILED", "0")) == 0
print(json.dumps({"ok": ok, "checks": checks}))
PY
}

preflight::run() {
  PREFLIGHT_CHECKS=()
  PREFLIGHT_FAILED=0

  if preflight::_json_mode; then
    exec 3>&1
    exec 1>&2
  else
    log::section "Preflight checks"
  fi

  local required_cmds=(ssh scp git kubectl curl)
  local failed=0
  local distro="${K8S_DISTRO:-kubespray}"

  if [[ "$distro" == "kubespray" ]]; then
    required_cmds+=(ansible ansible-playbook python3)
  elif [[ "$distro" == "k3s" ]]; then
    required_cmds+=(helm)
    if [[ "${CILIUM_HUBBLE_ENABLED:-true}" == "true" ]] && ! command -v cilium &>/dev/null; then
      preflight::_record pass "cilium CLI" "optional — Hubble UI unavailable"
      log::warn "cilium CLI not found — Hubble UI commands will be unavailable (brew install cilium-cli)"
    fi
  else
    die "Unknown K8S_DISTRO: $distro (use kubespray or k3s)"
  fi

  for cmd in "${required_cmds[@]}"; do
    preflight::check_command "$cmd" || (( failed++ )) || true
  done

  if [[ "$distro" == "kubespray" ]]; then
    preflight::check_python || (( failed++ )) || true
    for mod in jinja2 netaddr; do
      preflight::check_python_module "$mod" || (( failed++ )) || true
    done
  fi

  [[ "$failed" -eq 0 ]] || die "Fix the $failed missing dependency/dependencies above, then re-run."
  if ! preflight::_json_mode; then
    log::ok "All required tools present."
  fi

  preflight::check_ssh_key "$SSH_KEY"

  local all_ips=($CONTROL_PLANE_IPS $WORKER_IPS)
  preflight::check_ssh_connectivity "$SSH_USER" "${SSH_KEY/#\~/$HOME}" "${all_ips[@]}"

  if [[ "$distro" == "k3s" ]]; then
    preflight::check_k3s_remote
  fi

  if preflight::_json_mode; then
    exec 1>&3
    exec 3>&-
    preflight::emit_json
    [[ "$PREFLIGHT_FAILED" -eq 0 && "$failed" -eq 0 ]] || exit 1
    return 0
  fi

  log::ok "Preflight passed. 🚀"
}
