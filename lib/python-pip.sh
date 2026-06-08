#!/usr/bin/env bash
# Python pip helpers — pip3 with python3 -m pip fallback (Homebrew/macOS compat).

# shellcheck source=lib/python-resolve.sh
source "${HYPERCLUSTER_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/python-resolve.sh"

pip::_repo_dir() {
  echo "${HYPERCLUSTER_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
}

if [[ -z "${_PYTHON_PIP_LOG_SOURCED:-}" ]]; then
  # shellcheck source=lib/log.sh
  source "$(pip::_repo_dir)/lib/log.sh"
  _PYTHON_PIP_LOG_SOURCED=1
fi

pip::_externally_managed() {
  local py
  py="$(python::bin)"
  "$py" -c "
import sys, sysconfig
from pathlib import Path
if sys.version_info < (3, 11):
    raise SystemExit(1)
stdlib = Path(sysconfig.get_path('stdlib'))
raise SystemExit(0 if (stdlib.parent / 'EXTERNALLY-MANAGED').is_file() else 1)
" 2>/dev/null
}

pip::extra_args() {
  pip::_externally_managed && echo "--break-system-packages"
}

pip::module_install_hint() {
  local mod="$1" extra hint
  extra="$(pip::extra_args)"
  hint="pip3 install${extra:+ $extra} $mod; or python3 -m pip install${extra:+ $extra} $mod"
  if [[ "$(uname)" == "Darwin" ]]; then
    hint="$hint (if both fail identically, run ./scripts/setup-macos.sh)"
  fi
  echo "$hint"
}

pip::install() {
  local extra=() py
  py="$(python::bin)"
  if pip::_externally_managed; then
    extra=(--break-system-packages)
  fi

  local err_pip3 err_pym tried_pip3=0
  err_pip3=$(mktemp)
  err_pym=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$err_pip3' '$err_pym'" RETURN

  if command -v pip3 &>/dev/null; then
    tried_pip3=1
    if pip3 install "${extra[@]}" "$@" 2>"$err_pip3"; then
      return 0
    fi
  fi

  if "$py" -m pip install "${extra[@]}" "$@" 2>"$err_pym"; then
    return 0
  fi

  if [[ "$tried_pip3" -eq 1 ]] && diff -q "$err_pip3" "$err_pym" &>/dev/null; then
    log::error "pip install failed — pip3 and python3 -m pip failed identically (Homebrew/macOS Python compatibility)"
    log::error "Try: ./scripts/setup-macos.sh  or  brew reinstall python@3.12"
  else
    log::error "pip install failed"
  fi
  if [[ -s "$err_pym" ]]; then
    cat "$err_pym" >&2
  elif [[ -s "$err_pip3" ]]; then
    cat "$err_pip3" >&2
  fi
  return 1
}
