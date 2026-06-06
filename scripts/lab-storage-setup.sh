#!/usr/bin/env bash
# Wrapper — prefer: hypercluster -c cluster.conf lab storage [--status]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${CONFIG:-${ROOT}/cluster.conf}"
exec "${ROOT}/hypercluster" -c "${CONFIG}" lab storage "$@"
