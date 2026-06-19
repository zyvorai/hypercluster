from __future__ import annotations

import os
import time
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.ssh import make_client, run_remote, run_remote_script


_HOST_PREP_SCRIPT = r"""
set -euo pipefail
sudo modprobe br_netfilter 2>/dev/null || true
sudo modprobe overlay 2>/dev/null || true
sudo modprobe kvm 2>/dev/null || true
if [[ "$(uname -m)" == x86_64 ]]; then
  if grep -qi intel /proc/cpuinfo 2>/dev/null; then sudo modprobe kvm_intel 2>/dev/null || true
  elif grep -qi amd /proc/cpuinfo 2>/dev/null; then sudo modprobe kvm_amd 2>/dev/null || true
  fi
fi
if command -v swapon >/dev/null 2>&1 && sudo swapon --show 2>/dev/null | grep -q .; then
  sudo swapoff -a || true
  if [[ -f /etc/fstab ]]; then
    sudo sed -i '/[[:space:]]swap[[:space:]]/s/^/# /' /etc/fstab || true
  fi
fi
cat <<'SYSCTL' | sudo tee /etc/sysctl.d/99-kubernetes.conf >/dev/null
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=8192
SYSCTL
sudo sysctl --system >/dev/null 2>&1 || sudo sysctl -p /etc/sysctl.d/99-kubernetes.conf >/dev/null
if systemctl is-active firewalld &>/dev/null; then
  sudo systemctl stop firewalld || true
  sudo systemctl disable firewalld || true
fi
if command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y qemu-kvm libvirt-client 2>/dev/null || true
elif command -v apt-get >/dev/null 2>&1; then
  DEBIAN_FRONTEND=noninteractive sudo apt-get update -qq 2>/dev/null || true
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y qemu-kvm qemu-utils 2>/dev/null || true
fi
"""

_REMOTE_KUBECONFIG_SCRIPT = r"""
set -euo pipefail
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config
grep -q 'KUBECONFIG=.*\.kube/config' ~/.bashrc 2>/dev/null || \
  echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc
"""


def _exec_args(cfg: ClusterConfig) -> str:
    args = cfg.K3S_EXEC_ARGS or "--flannel-backend=none --disable-network-policy --disable traefik --disable servicelb --disable-kube-proxy"
    if cfg.K3S_DATA_DIR:
        args = f"--data-dir {cfg.K3S_DATA_DIR} {args}"
    return args


def _agent_exec_args(cfg: ClusterConfig) -> str:
    if cfg.K3S_AGENT_EXEC_ARGS:
        return cfg.K3S_AGENT_EXEC_ARGS
    if cfg.K3S_DATA_DIR:
        return f"--data-dir {cfg.K3S_DATA_DIR}"
    return ""


def _install_env(exec_args: str, cfg: ClusterConfig) -> str:
    parts = []
    if cfg.K3S_VERSION:
        parts.append(f"INSTALL_K3S_VERSION='{cfg.K3S_VERSION}'")
    if cfg.K3S_CHANNEL:
        parts.append(f"INSTALL_K3S_CHANNEL='{cfg.K3S_CHANNEL}'")
    parts.append(f"INSTALL_K3S_EXEC='server {exec_args}'")
    return " ".join(parts)


def _agent_install_env(exec_args: str, token: str, master_ip: str, cfg: ClusterConfig) -> str:
    parts = []
    if cfg.K3S_VERSION:
        parts.append(f"INSTALL_K3S_VERSION='{cfg.K3S_VERSION}'")
    if cfg.K3S_CHANNEL:
        parts.append(f"INSTALL_K3S_CHANNEL='{cfg.K3S_CHANNEL}'")
    parts.append(f"INSTALL_K3S_EXEC='agent {exec_args}'")
    parts.append(f"K3S_URL='https://{master_ip}:6443'")
    parts.append(f"K3S_TOKEN='{token}'")
    return " ".join(parts)


def _data_dir(cfg: ClusterConfig) -> str:
    return cfg.K3S_DATA_DIR or "/var/lib/rancher/k3s"


def _server_running(ip: str, cfg: ClusterConfig) -> bool:
    try:
        r = run_remote(ip, cfg, "systemctl is-active k3s 2>/dev/null | grep -qx active", stream=False)
        return r.ok
    except Exception:
        return False


def host_prep(cfg: ClusterConfig) -> None:
    log.section("k3s host prep")
    prep_script = _HOST_PREP_SCRIPT
    if cfg.K3S_DATA_DIR:
        prep_script += f"\nsudo mkdir -p '{cfg.K3S_DATA_DIR}'\n"

    for ip in cfg.all_ips():
        if not ip:
            continue
        log.info(f"Preparing {cfg.SSH_USER}@{ip} …")
        r = run_remote_script(ip, cfg, prep_script)
        if not r.ok:
            log.die(f"Host prep failed on {ip}:\n{r.stderr}")
        log.ok(f"{ip} prepared")


def install_server(cfg: ClusterConfig) -> None:
    ip = cfg.first_cp_ip()
    exec_args = _exec_args(cfg)
    log.section(f"k3s server on {ip}")

    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping k3s install.")
        return

    if not cfg.FORCE_K3S_REINSTALL and _server_running(ip, cfg):
        log.ok(f"k3s already running on {ip} — skipping reinstall (set FORCE_K3S_REINSTALL=1 to replace)")
        return

    install_env = _install_env(exec_args, cfg)
    r = run_remote(ip, cfg, f"curl -sfL https://get.k3s.io | sudo {install_env} sh -")
    if not r.ok:
        log.die(f"k3s server install failed on {ip}")

    log.info(f"Waiting for k3s API on {ip} …")
    for _ in range(60):
        check = run_remote(ip, cfg, "sudo /usr/local/bin/k3s kubectl get nodes", stream=False)
        if check.ok:
            log.ok(f"k3s API ready on {ip}")
            return
        time.sleep(2)
    log.die(f"k3s API not ready on {ip} after 120s")


def join_workers(cfg: ClusterConfig) -> None:
    workers = cfg.worker_ips()
    if not workers:
        log.info("No worker nodes — single-node cluster.")
        return

    master_ip = cfg.first_cp_ip()
    data_dir_path = _data_dir(cfg)
    token_result = run_remote(master_ip, cfg, f"sudo cat {data_dir_path}/server/node-token", stream=False)
    if not token_result.ok or not token_result.stdout.strip():
        log.die(f"Could not read k3s node token from {master_ip}:{data_dir_path}/server/node-token")
    token = token_result.stdout.strip()
    exec_args = _agent_exec_args(cfg)

    log.section(f"Joining {len(workers)} worker(s) to k3s")
    for ip in workers:
        if not ip:
            continue
        log.info(f"Joining {ip} …")
        if proc.DRY_RUN:
            log.warn(f"DRY RUN — skip join {ip}")
            continue
        install_env = _agent_install_env(exec_args, token, master_ip, cfg)
        r = run_remote(ip, cfg, f"curl -sfL https://get.k3s.io | sudo {install_env} sh -")
        if not r.ok:
            log.die(f"Worker join failed on {ip}")
        log.ok(f"{ip} joined")


def install_remote_kubeconfig(cfg: ClusterConfig) -> None:
    ip = cfg.first_cp_ip()
    log.section(f"Remote kubeconfig → {cfg.SSH_USER}@{ip}:~/.kube/config")
    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping remote kubeconfig.")
        return
    r = run_remote_script(ip, cfg, _REMOTE_KUBECONFIG_SCRIPT)
    if not r.ok:
        log.warn(f"Remote kubeconfig install failed on {ip}: {r.stderr}")
    else:
        log.ok(f"Remote kubeconfig installed for {cfg.SSH_USER}@{ip}")


def wait_api(cfg: ClusterConfig) -> None:
    import subprocess
    kc = cfg.resolved_kubeconfig()
    if not Path(kc).is_file():
        return
    if proc.DRY_RUN:
        return
    log.info("Waiting for Kubernetes API (kubeconfig) …")
    max_tries = 150 if cfg.K3S_API_LOCAL_PORT else 60
    env = dict(os.environ, KUBECONFIG=kc)
    for _ in range(max_tries):
        r = subprocess.run(["kubectl", "get", "nodes"], env=env,
                           capture_output=True)
        if r.returncode == 0:
            log.ok("API reachable via kubeconfig")
            return
        time.sleep(2)
    log.die(f"API not reachable via {kc} after {max_tries * 2}s")


def deploy(cfg: ClusterConfig) -> None:
    host_prep(cfg)
    install_server(cfg)
    join_workers(cfg)


def destroy(cfg: ClusterConfig, force: bool = False) -> None:
    if force:
        _destroy_platform(cfg)

    log.section("Removing k3s from all nodes")
    for ip in cfg.all_ips():
        if not ip:
            continue
        log.info(f"Uninstalling k3s on {ip} …")
        if proc.DRY_RUN:
            log.warn(f"DRY RUN — skip uninstall on {ip}")
            continue
        r = run_remote(ip, cfg,
                       "sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || "
                       "sudo k3s-uninstall.sh 2>/dev/null || true")
        log.ok(f"k3s removed from {ip}")


def _destroy_platform(cfg: ClusterConfig) -> None:
    import subprocess
    import os
    kc = cfg.resolved_kubeconfig()
    if not Path(kc).is_file():
        return
    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping platform Helm uninstalls.")
        return
    log.section("Removing Helm platform releases")
    env = dict(os.environ, KUBECONFIG=kc)
    releases = [
        ("kubevirt", "kubevirt"),
        ("cdi", "cdi"),
        ("kubevirt-csi", "kubevirt"),
        ("cnao", "cluster-network-addons"),
        ("ssp", "kubevirt"),
        ("cilium", "kube-system"),
        ("metallb", "metallb-system"),
        ("cert-manager", "cert-manager"),
        ("snapshot-controller", "snapshot-system"),
        ("longhorn", "longhorn-system"),
    ]
    for name, ns in releases:
        subprocess.run(["helm", "uninstall", name, "-n", ns],
                       env=env, capture_output=True)
