#!/usr/bin/env bash
# Kubespray clone / playbook execution helpers — source this file.

kubespray::_clone() {
  local dir="$1" version="$2"
  log::info "Cloning Kubespray $version …"
  git clone --depth 1 --branch "$version" \
    https://github.com/kubernetes-sigs/kubespray.git "$dir"
  log::ok "Kubespray cloned → $dir"

  log::info "Installing Python requirements …"
  pip3 install -r "$dir/requirements.txt" || die "pip3 install failed — check requirements.txt"
  log::ok "Python requirements installed."
}

kubespray::ensure_source() {
  local dir="$1" version="$2"

  if [[ -d "$dir/.git" ]]; then
    local current_tag
    current_tag=$(git -C "$dir" describe --tags --exact-match 2>/dev/null || echo "unknown")
    if [[ "$current_tag" == "$version" ]]; then
      log::info "Kubespray $version already present at $dir"
      return
    fi
    log::warn "Version mismatch: cloned=$current_tag requested=$version."
    if [[ "${FORCE:-0}" != "1" ]]; then
      die "Kubespray dir $dir is at the wrong version.
       Re-run with -f to re-clone (WARNING: local changes to $dir will be deleted)."
    fi
    log::warn "Re-cloning (--force) — deleting $dir"
    rm -rf "$dir"
  fi

  kubespray::_clone "$dir" "$version"
}

kubespray::_ansible_args() {
  local inv_dir="$1"
  local -n _args_ref="$2"
  _args_ref=(
    -i "$inv_dir/hosts.yaml"
    --private-key "${SSH_KEY/#\~/$HOME}"
    --user "$SSH_USER"
    --become
  )
  [[ "${VERBOSE:-0}" == "1" ]] && _args_ref+=(-v)
  [[ -n "${SSH_EXTRA_ARGS:-}" ]] && _args_ref+=(--ssh-extra-args "$SSH_EXTRA_ARGS")
}

kubespray::run_playbook() {
  local kubespray_dir="$1" playbook="$2"
  shift 2
  local extra_args=("$@")

  local inv_dir="$kubespray_dir/inventory/$CLUSTER_NAME"
  local base_args=()
  kubespray::_ansible_args "$inv_dir" base_args

  log::info "Running playbook: $playbook"
  log::debug "ansible-playbook ${base_args[*]} ${extra_args[*]} $kubespray_dir/$playbook"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — skipping actual playbook execution."
    return 0
  fi

  ansible-playbook "${base_args[@]}" "${extra_args[@]}" "$kubespray_dir/$playbook"
}
