from __future__ import annotations

import os
import subprocess
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig


def _kubectl(cfg: ClusterConfig, *args: str) -> int:
    kc = cfg.resolved_kubeconfig()
    env = dict(os.environ, KUBECONFIG=kc)
    return proc.run_stream(["kubectl"] + list(args), env=env)


def setup(cfg: ClusterConfig) -> None:
    if cfg.distro() != "k3s":
        log.die("lab command is for K8S_DISTRO=k3s only.")
    log.section("Lab setup")
    if cfg.LAB_SECONDARY_DISK:
        storage(cfg)
    if cfg.LAB_MEMORY_TUNE_ENABLED:
        tune(cfg)


def storage(cfg: ClusterConfig) -> None:
    log.section("Lab storage")
    disk = cfg.LAB_SECONDARY_DISK
    if not disk:
        log.warn("LAB_SECONDARY_DISK not set — skipping storage setup")
        return

    from hypercluster.paths import config_dir
    manifests_dir = config_dir() / "manifests" / "lab"

    if proc.DRY_RUN:
        log.warn(f"DRY RUN — would mount {disk} and configure storage class")
        return

    ip = cfg.first_cp_ip()
    from hypercluster.ssh import run_remote
    mount_script = f"""
set -euo pipefail
sudo mkdir -p /var/lib/rancher/k3s/storage
if ! grep -q '{disk}' /proc/mounts 2>/dev/null; then
  sudo mkfs.ext4 -F '{disk}' || true
  echo '{disk} /var/lib/rancher/k3s/storage ext4 defaults 0 2' | sudo tee -a /etc/fstab
  sudo mount -a
fi
"""
    r = run_remote(ip, cfg, mount_script)
    if r.ok:
        log.ok(f"Secondary disk {disk} mounted")
    else:
        log.warn(f"Disk mount may have failed: {r.stderr}")

    sc_manifest = manifests_dir / "kubevirt-sdb-storageclass.yaml"
    if sc_manifest.is_file():
        _kubectl(cfg, "apply", "-f", str(sc_manifest))
        log.ok("Storage class applied")


def tune(cfg: ClusterConfig) -> None:
    log.section("Lab memory tune (HA replicas → 1 for single-node)")
    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping memory tune")
        return
    kc = cfg.resolved_kubeconfig()
    env = dict(os.environ, KUBECONFIG=kc)
    ha_deployments = [
        ("cert-manager", "cert-manager-cainjector"),
        ("cert-manager", "cert-manager-webhook"),
        ("kube-system", "cilium-operator"),
        ("metallb-system", "metallb-controller"),
    ]
    for ns, name in ha_deployments:
        r = subprocess.run(
            ["kubectl", "scale", "deploy", name, "-n", ns, "--replicas=1"],
            env=env, capture_output=True,
        )
        if r.returncode == 0:
            log.ok(f"Scaled {ns}/{name} → 1")
        else:
            log.debug(f"Could not scale {ns}/{name} (may not exist)")


def run(cfg: ClusterConfig, subcommand: str, *args: str) -> None:
    if subcommand == "setup":
        setup(cfg)
    elif subcommand == "storage":
        storage(cfg)
    elif subcommand == "tune":
        tune(cfg)
    else:
        log.die(f"Unknown lab subcommand: {subcommand}\nUsage: hypercluster lab [setup|storage|tune]")
