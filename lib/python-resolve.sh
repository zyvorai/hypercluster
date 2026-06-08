#!/usr/bin/env bash
# Resolve a modern Python 3 for Kubespray/Ansible on macOS GUI launches.

python::_version_ok() {
  local py="$1"
  [[ -n "$py" && -x "$py" ]] || return 1
  "$py" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)' 2>/dev/null
}

python::_emit_candidates() {
  local c

  if [[ -n "${HYPERCLUSTER_PYTHON:-}" ]]; then
    echo "$HYPERCLUSTER_PYTHON"
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    for prefix in /opt/homebrew /usr/local; do
      [[ -d "$prefix" ]] || continue
      for rel in \
        bin/python3 \
        opt/python@3.13/bin/python3 \
        opt/python@3.12/bin/python3 \
        opt/python@3.11/bin/python3; do
        c="$prefix/$rel"
        [[ -x "$c" ]] && echo "$c"
      done
    done
  fi

  if command -v python3 &>/dev/null; then
    command -v python3
  fi
}

_PYTHON_BIN=""

python::resolve() {
  local c
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    if python::_version_ok "$c"; then
      echo "$c"
      return 0
    fi
  done < <(python::_emit_candidates | awk '!seen[$0]++')
  return 1
}

python::bin() {
  if [[ -n "$_PYTHON_BIN" ]]; then
    echo "$_PYTHON_BIN"
    return 0
  fi
  if _PYTHON_BIN="$(python::resolve 2>/dev/null)"; then
    echo "$_PYTHON_BIN"
    return 0
  fi
  echo "python3"
}

python::configure_path() {
  local py dir user_bin major minor
  py="$(python::resolve 2>/dev/null || true)"
  [[ -n "$py" ]] || return 0
  _PYTHON_BIN="$py"
  export HYPERCLUSTER_PYTHON="$py"
  dir="$(dirname "$py")"
  if [[ ":$PATH:" != *":$dir:"* ]]; then
    export PATH="$dir:$PATH"
  fi
  if [[ "$(uname -s)" == "Darwin" ]]; then
    major="$("$py" -c 'import sys; print(sys.version_info.major)')"
    minor="$("$py" -c 'import sys; print(sys.version_info.minor)')"
    user_bin="${HOME}/Library/Python/${major}.${minor}/bin"
    if [[ -d "$user_bin" && ":$PATH:" != *":$user_bin:"* ]]; then
      export PATH="$user_bin:$PATH"
    fi
  fi
}

python::require() {
  local py ver hint
  if ! py="$(python::resolve 2>/dev/null)"; then
    hint="Install Python 3.11+ (macOS: brew install python@3.12 && ./scripts/setup-macos.sh)"
    die "Python 3.11+ required for Kubespray/Ansible — not found. $hint"
  fi
  ver="$("$py" -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
  log::debug "Using Python $ver ($py)"
}
