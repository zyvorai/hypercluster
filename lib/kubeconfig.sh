#!/usr/bin/env bash
# kubeconfig retrieval and merge helpers — source this file.

if ! declare -f ssh::node_opts &>/dev/null; then
  # shellcheck source=lib/ssh.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ssh.sh"
fi

kubeconfig::_patch_server() {
  local output="$1" first_cp_ip="$2"
  if [[ -n "${K3S_API_LOCAL_PORT:-}" ]]; then
    log::info "Patching server address → 127.0.0.1:${K3S_API_LOCAL_PORT} (SSH API tunnel)"
    if [[ "$(uname)" == "Darwin" ]]; then
      sed -i '' \
        -e "s|https://127.0.0.1:[0-9]*|https://127.0.0.1:${K3S_API_LOCAL_PORT}|g" \
        -e "s|https://localhost:[0-9]*|https://127.0.0.1:${K3S_API_LOCAL_PORT}|g" \
        -e "s|https://${first_cp_ip}:6443|https://127.0.0.1:${K3S_API_LOCAL_PORT}|g" \
        "$output"
    else
      sed -i.bak \
        -e "s|https://127.0.0.1:[0-9]*|https://127.0.0.1:${K3S_API_LOCAL_PORT}|g" \
        -e "s|https://localhost:[0-9]*|https://127.0.0.1:${K3S_API_LOCAL_PORT}|g" \
        -e "s|https://${first_cp_ip}:6443|https://127.0.0.1:${K3S_API_LOCAL_PORT}|g" \
        "$output"
      rm -f "${output}.bak"
    fi
    return 0
  fi
  log::info "Patching server address → $first_cp_ip"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' \
      -e "s|https://127.0.0.1:|https://${first_cp_ip}:|g" \
      -e "s|https://localhost:|https://${first_cp_ip}:|g" \
      "$output"
  else
    sed -i.bak \
      -e "s|https://127.0.0.1:|https://${first_cp_ip}:|g" \
      -e "s|https://localhost:|https://${first_cp_ip}:|g" \
      "$output"
    rm -f "${output}.bak"
  fi
}

kubeconfig::fetch_k3s() {
  local first_cp_ip
  first_cp_ip=$(echo "$CONTROL_PLANE_IPS" | awk '{print $1}')
  local key="${SSH_KEY/#\~/$HOME}"
  local output="${KUBECONFIG_OUTPUT/#\~/$HOME}"

  log::section "Fetching k3s kubeconfig"
  mkdir -p "$(dirname "$output")"

  if [[ "${DRY_RUN:-0}" == "1" ]]; then
    log::warn "DRY RUN — skipping kubeconfig fetch."
    return 0
  fi

  log::info "Reading /etc/rancher/k3s/k3s.yaml from $first_cp_ip …"
  local ssh_opts=() attempt raw=""
  ssh::node_opts ssh_opts "$key" "${SSH_PORT:-22}"
  for attempt in 1 2 3 4 5 6; do
    if raw="$(ssh "${ssh_opts[@]}" "$SSH_USER@$first_cp_ip" "sudo cat /etc/rancher/k3s/k3s.yaml" 2>/dev/null)"; then
      printf '%s\n' "$raw" > "$output"
      break
    fi
    log::warn "kubeconfig fetch attempt $attempt/6 failed — retrying …"
    sleep 10
  done
  [[ -s "$output" ]] || die "failed to fetch kubeconfig from $first_cp_ip"
  chmod 600 "$output"
  kubeconfig::_patch_server "$output" "$first_cp_ip"

  log::ok "kubeconfig saved → $output"
  log::info "To use:"
  printf "    export KUBECONFIG=%s\n    kubectl get nodes\n\n" "$output"
}

kubeconfig::fetch() {
  local kubespray_dir="$1"
  if [[ "${K8S_DISTRO:-kubespray}" == "k3s" ]]; then
    kubeconfig::fetch_k3s
    return
  fi

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

  kubeconfig::_patch_server "$output" "$first_cp_ip"

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
