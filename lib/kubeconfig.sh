#!/usr/bin/env bash
# kubeconfig retrieval and merge helpers — source this file.

kubeconfig::fetch() {
  local kubespray_dir="$1"
  local first_cp_ip
  first_cp_ip=$(echo "$CONTROL_PLANE_IPS" | awk '{print $1}')
  local key="${SSH_KEY/#\~/$HOME}"
  local output="${KUBECONFIG_OUTPUT/#\~/$HOME}"
  local artifacts_kc="$kubespray_dir/inventory/$CLUSTER_NAME/artifacts/admin.conf"

  log::section "Fetching kubeconfig"
  mkdir -p "$(dirname "$output")"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — skipping kubeconfig fetch."
    return 0
  fi

  if [[ -f "$artifacts_kc" ]]; then
    log::info "Using local artifacts copy: $artifacts_kc"
    cp "$artifacts_kc" "$output"
  else
    log::info "Artifacts copy not found — copying via scp from $first_cp_ip …"
    # shellcheck disable=SC2086
    scp -i "$key" \
        -o StrictHostKeyChecking=accept-new \
        -o ConnectTimeout=15 \
        ${SSH_EXTRA_ARGS:-} \
        "$SSH_USER@$first_cp_ip:/etc/kubernetes/admin.conf" \
        "$output"
  fi

  # Rewrite the server address if it resolves to 127.0.0.1 / localhost
  log::info "Patching server address → $first_cp_ip"
  sed -i.bak \
    -e "s|https://127.0.0.1:|https://${first_cp_ip}:|g" \
    -e "s|https://localhost:|https://${first_cp_ip}:|g" \
    "$output"
  rm -f "${output}.bak"

  log::ok "kubeconfig saved → $output"
  log::info "To use:"
  printf "    export KUBECONFIG=%s\n    kubectl get nodes\n\n" "$output"
}

kubeconfig::merge_into_default() {
  local src="${KUBECONFIG_OUTPUT/#\~/$HOME}"
  local default="$HOME/.kube/config"

  [[ -f "$src" ]] || die "kubeconfig not found at $src — run 'fetch-kubeconfig' first."

  mkdir -p "$HOME/.kube"
  if [[ -f "$default" ]]; then
    log::info "Merging into existing $default …"
    local backup="${default}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$default" "$backup"
    log::info "Backup saved → $backup"
    KUBECONFIG="$default:$src" kubectl config view --flatten > "${default}.tmp"
    mv "${default}.tmp" "$default"
  else
    cp "$src" "$default"
  fi
  log::ok "kubeconfig merged into $default 🎉"
}
