#!/usr/bin/env bash
# Writable data / anchor paths — bundled Mac app vs dev checkout.

runtime::_repo_dir() {
  echo "${HYPERCLUSTER_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
}

runtime::bundled_macos_app() {
  [[ "$(uname -s)" == "Darwin" ]] || return 1
  local dir
  dir="$(runtime::_repo_dir)"
  [[ "$dir" == *"/Hypercluster.app/Contents/Resources/hypercluster-runtime" ]]
}

runtime::data_dir() {
  if [[ -n "${HYPERCLUSTER_DATA_DIR:-}" ]]; then
    echo "$HYPERCLUSTER_DATA_DIR"
    return 0
  fi
  if runtime::bundled_macos_app; then
    echo "${HOME}/Library/Application Support/Hypercluster"
    return 0
  fi
  echo "$(runtime::_repo_dir)"
}

# Relative KUBESPRAY_DIR / venv paths anchor here (repo root in dev, app data when bundled).
runtime::anchor_dir() {
  runtime::data_dir
}
