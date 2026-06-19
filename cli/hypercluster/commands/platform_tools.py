from __future__ import annotations

import os
import subprocess
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.ssh import make_client


def install_remote(cfg: ClusterConfig) -> None:
    log.section("Remote CLI tools (kubectl, helm)")
    ip = cfg.first_cp_ip()
    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping remote CLI install.")
        return
    script = r"""
set -euo pipefail
# kubectl
if ! command -v kubectl &>/dev/null; then
  KVER=$(curl -sfL https://dl.k8s.io/release/stable.txt)
  curl -sfLo /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm /tmp/kubectl
fi
# helm
if ! command -v helm &>/dev/null; then
  curl -sfL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
echo "ok"
"""
    with make_client(ip, cfg) as c:
        r = c.run("bash -s", stdin_data=script, stream=True)
        if r.ok:
            log.ok("Remote CLI tools installed")
        else:
            log.warn(f"Remote CLI tools install failed on {ip}: {r.stderr}")


def merge_laptop_kubeconfig(cfg: ClusterConfig) -> None:
    from hypercluster.commands.kubeconfig import merge_into_default
    merge_into_default(cfg)
