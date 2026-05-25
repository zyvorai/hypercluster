#!/usr/bin/env bash
# TTY progress indicators for long-running steps — source this file.

progress::_use_tty() {
  [[ -t 1 && "${VERBOSE:-0}" != "1" && "${DRY_RUN:-0}" != "1" ]]
}

progress::stage() {
  local current="$1" total="$2" label="$3"
  _PROGRESS_STAGE="$current"
  _PROGRESS_TOTAL="$total"
  if progress::_use_tty; then
    printf "\n\033[1m[%s/%s]\033[0m %s\n" "$current" "$total" "$label"
  else
    log::section "[$current/$total] $label"
  fi
}

progress::spinner_start() {
  local msg="$1"
  progress::_use_tty || return 0
  local frames='|/-\'
  (
    local i=0
    while true; do
      printf '\r\033[36m%s\033[0m %s' "${frames:i++%4:1}" "$msg"
      sleep 0.12
    done
  ) &
  _PROGRESS_SPINNER_PID=$!
}

progress::spinner_stop() {
  progress::_use_tty || return 0
  if [[ -n "${_PROGRESS_SPINNER_PID:-}" ]]; then
    kill "$_PROGRESS_SPINNER_PID" 2>/dev/null || true
    wait "$_PROGRESS_SPINNER_PID" 2>/dev/null || true
    unset _PROGRESS_SPINNER_PID
  fi
  printf '\r\033[K'
}

progress::elapsed_start() {
  _PROGRESS_START=$(date +%s)
}

progress::elapsed_stop() {
  progress::_use_tty || return 0
  [[ -n "${_PROGRESS_START:-}" ]] || return 0
  local now elapsed mins secs
  now=$(date +%s)
  elapsed=$(( now - _PROGRESS_START ))
  mins=$(( elapsed / 60 ))
  secs=$(( elapsed % 60 ))
  printf "\033[2m  completed in %dm %ds\033[0m\n" "$mins" "$secs"
  unset _PROGRESS_START
}

# Run a command with a spinner when stdout is a TTY.
progress::run() {
  local msg="$1"
  shift
  progress::elapsed_start
  progress::spinner_start "$msg"
  set +e
  "$@"
  local rc=$?
  set -e
  progress::spinner_stop
  progress::elapsed_stop
  return "$rc"
}
