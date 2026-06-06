#!/usr/bin/env bash
# Apple Silicon (arm64) host checks for Hypercluster Desktop macOS releases.
# Intel Mac support ended — distributed .pkg / release .app are arm64 only.
# shellcheck shell=bash

# Hardware check — works when pkg scripts run under Rosetta (uname -m → x86_64 on M-series).
hc_macos_is_arm64_hardware() {
  if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" == "1" ]]; then
    return 0
  fi
  [[ "$(sysctl -n hw.machine 2>/dev/null || true)" == "arm64" ]]
}

hc_macos_host_arch() {
  if hc_macos_is_arm64_hardware; then
    echo "arm64"
    return 0
  fi
  uname -m
}

hc_macos_is_arm64_host() {
  hc_macos_is_arm64_hardware
}

hc_macos_require_arm64_host() {
  if hc_macos_is_arm64_host; then
    return 0
  fi
  cat >&2 <<'EOF'
ERROR: Hypercluster Desktop release builds require an Apple Silicon Mac (arm64).

Intel-based Mac support has ended. You can still run `npm run desktop` for local
development on Intel, but `make desktop-pkg` and release artifacts are arm64-only.

Use an M-series Mac to build the .pkg, or download the arm64 release from Zyvor.
EOF
  return 1
}

hc_macos_app_binary_arch() {
  local app="${1:?Hypercluster.app path}"
  local bin="${app%/}/Contents/MacOS/hypercluster-desktop"
  if [[ ! -f "$bin" ]]; then
    echo "missing"
    return 1
  fi
  if command -v lipo >/dev/null 2>&1; then
    lipo -info "$bin" 2>/dev/null | sed 's/.*: //' || file -b "$bin"
  else
    file -b "$bin"
  fi
}

hc_macos_require_arm64_app() {
  local app="${1:?}"
  local info
  info="$(hc_macos_app_binary_arch "$app")"
  if [[ "$info" == *arm64* ]] && [[ "$info" != *x86_64* ]]; then
    return 0
  fi
  if [[ "$info" == *x86_64* ]]; then
    cat >&2 <<EOF
ERROR: ${app} is an Intel (x86_64) build.

Release Hypercluster Desktop is Apple Silicon (arm64) only. Rebuild on an M-series Mac:

  cd desktop && npm run tauri build -- --bundles app --target aarch64-apple-darwin

Detected binary: ${info}
EOF
    return 1
  fi
  echo "WARN: Could not confirm arm64 architecture: ${info}" >&2
  return 0
}

hc_macos_tauri_release_target() {
  echo "aarch64-apple-darwin"
}
