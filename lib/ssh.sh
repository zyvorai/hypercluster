#!/usr/bin/env bash
# Shared SSH option helpers for hypercluster + remote libvirt deploy.

ssh::_key() {
  echo "${SSH_KEY/#\~/$HOME}"
}

# Append ProxyJump + SSH_EXTRA_ARGS to an opts array (nameref).
ssh::append_extra_opts() {
  local -n _dest="$1"
  local extra="${SSH_EXTRA_ARGS:-}" arg
  if [[ -n "${SSH_PROXY_JUMP:-}" ]]; then
    _dest+=(-o "ProxyJump=${SSH_PROXY_JUMP}")
    extra="$(printf '%s' "$extra" | sed -E \
      's/(^|[[:space:]])-o[[:space:]]+ProxyJump=[^[:space:]]+//g; s/^[[:space:]]+//; s/[[:space:]]+$//')"
  fi
  [[ -n "$extra" ]] || return 0
  for arg in ${extra}; do
    _dest+=("$arg")
  done
}

# opts for SSH to cluster nodes (k3s deploy, platform tests).
ssh::node_opts() {
  local -n _ref="$1"
  local key="${2:-$(ssh::_key)}"
  local port="${3:-${SSH_PORT:-22}}"
  _ref=(
    -i "$key"
    -o BatchMode=yes
    -o ConnectTimeout=20
    -o ServerAliveInterval=15
    -o StrictHostKeyChecking=accept-new
    -o ControlMaster=no
    -o ControlPath=none
  )
  [[ -n "$port" && "$port" != "22" ]] && _ref+=(-p "$port")
  ssh::append_extra_opts _ref
}

# opts for SSH to libvirt guests via hypervisor jump.
ssh::guest_opts() {
  local -n _ref="$1"
  local key="${2:-${DEPLOY_REMOTE_SSH_KEY:-$(ssh::_key)}}"
  local jump="${3:-${HYPERVISOR_JUMP:-${SSH_PROXY_JUMP:-}}}"
  _ref=(
    -i "$key"
    -o BatchMode=yes
    -o ConnectTimeout=15
    -o ServerAliveInterval=15
    -o StrictHostKeyChecking=accept-new
    -o IdentitiesOnly=yes
    -o ControlMaster=no
    -o ControlPath=none
  )
  if [[ -n "$jump" ]]; then
    _ref+=(-o "ProxyJump=${jump}")
  else
    ssh::append_extra_opts _ref
  fi
}
