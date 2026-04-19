#!/usr/bin/env bash
# Logging helpers — source this file, do not execute directly.

_ts() { date '+%H:%M:%S'; }

log::info()    { printf "[%s] ➜  %s\n"   "$(_ts)" "$*"; }
log::ok()      { printf "[%s] ✅  %s\n"   "$(_ts)" "$*"; }
log::warn()    { printf "[%s] ⚠️   %s\n"  "$(_ts)" "$*" >&2; }
log::error()   { printf "[%s] ❌  %s\n"   "$(_ts)" "$*" >&2; }
log::section() { printf "\n🔷  %s\n%s\n\n" "$*" "$(printf '─%.0s' {1..60})"; }
log::debug()   {
  [[ "${VERBOSE:-0}" == "1" ]] && printf "[%s] 🐛  %s\n" "$(_ts)" "$*" >&2 || true
}

die() {
  log::error "$*"
  exit 1
}
