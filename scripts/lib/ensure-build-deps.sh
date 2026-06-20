#!/usr/bin/env bash
# ensure-build-deps.sh — Idempotent build prerequisite installer for remote SSH sessions.
#
# Source this file in a remote bash heredoc, then call:
#   ensure_build_deps_all        — system tools + Node.js 22 + Rust/cargo
#   ensure_build_deps_system     — apt/dnf build-essential, pkg-config, libssl-dev, curl, wget, git
#   ensure_build_deps_node       — Node.js >= NODE_VERSION_MIN (default 18) via NodeSource 22.x
#   ensure_build_deps_rust       — rustup stable + cargo
#
# Set SKIP_BUILD_DEPS=1 to skip all installations silently.

NODE_VERSION_MIN="${NODE_VERSION_MIN:-18}"

ensure_build_deps_system() {
  [ "${SKIP_BUILD_DEPS:-0}" = "1" ] && return 0
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y -qq build-essential pkg-config libssl-dev curl wget git ca-certificates 2>/dev/null || true
    echo "[deps] OK: system tools (apt)"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y gcc make pkgconfig openssl-devel curl wget git ca-certificates 2>/dev/null || true
    echo "[deps] OK: system tools (dnf)"
  else
    echo "[deps] !!: no apt-get or dnf found — skipping system tools"
  fi
}

ensure_build_deps_node() {
  [ "${SKIP_BUILD_DEPS:-0}" = "1" ] && return 0
  local _cur=0
  command -v node >/dev/null 2>&1 && _cur="$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')"
  if [ "${_cur}" -ge "${NODE_VERSION_MIN}" ]; then
    echo "[deps] OK: node v${_cur} (>= ${NODE_VERSION_MIN})"
    return 0
  fi
  echo "[deps] Installing Node.js 22 (current: ${_cur:-none}, need >= ${NODE_VERSION_MIN})..."
  if command -v apt-get >/dev/null 2>&1; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null || true
    sudo apt-get install -y -qq nodejs 2>/dev/null || true
    echo "[deps] OK: node $(node -v 2>/dev/null || echo NOT_FOUND) (apt/NodeSource)"
  elif command -v dnf >/dev/null 2>&1; then
    curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - 2>/dev/null || true
    sudo dnf install -y nodejs 2>/dev/null || true
    echo "[deps] OK: node $(node -v 2>/dev/null || echo NOT_FOUND) (dnf/NodeSource)"
  else
    echo "[deps] !!: no apt-get or dnf — cannot install Node.js automatically"
  fi
}

ensure_build_deps_rust() {
  [ "${SKIP_BUILD_DEPS:-0}" = "1" ] && return 0
  source "${HOME}/.cargo/env" 2>/dev/null || true
  if command -v cargo >/dev/null 2>&1; then
    echo "[deps] OK: $(cargo --version)"
    return 0
  fi
  echo "[deps] Installing Rust toolchain..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  source "${HOME}/.cargo/env"
  echo "[deps] OK: $(cargo --version)"
}

ensure_build_deps_all() {
  ensure_build_deps_system
  ensure_build_deps_node
  ensure_build_deps_rust
}
