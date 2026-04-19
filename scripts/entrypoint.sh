#!/bin/bash
# Inject AUTHORIZED_KEYS env var into root's authorized_keys.
# Runs as a systemd oneshot before sshd starts.
set -e

if [[ -n "${AUTHORIZED_KEYS:-}" ]]; then
    mkdir -p /root/.ssh
    echo "$AUTHORIZED_KEYS" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
fi
