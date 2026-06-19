from __future__ import annotations

import re
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.ssh import make_client, run_remote


def deploy(cfg: ClusterConfig) -> None:
    log.section(f"MicroK8s deploy: {cfg.CLUSTER_NAME}")
    server_ip = cfg.first_cp_ip()
    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping MicroK8s install.")
        return

    log.info(f"Installing MicroK8s on {server_ip} …")
    r = run_remote(server_ip, cfg,
                   "sudo snap install microk8s --classic && "
                   "sudo microk8s status --wait-ready && "
                   "sudo microk8s enable dns storage")
    if not r.ok:
        log.die(f"MicroK8s install failed on {server_ip}: {r.stderr}")
    log.ok(f"MicroK8s installed on {server_ip}")

    for ip in cfg.worker_ips():
        if not ip:
            continue
        log.info(f"Generating join token for {ip} …")
        token_r = run_remote(server_ip, cfg, "sudo microk8s add-node --token-ttl 3600", stream=False)
        if not token_r.ok:
            log.warn(f"Could not get join token for {ip}")
            continue
        join_cmd_match = re.search(r'microk8s join\s+\S+', token_r.stdout)
        if not join_cmd_match:
            log.warn(f"Could not parse join command for {ip}")
            continue
        join_cmd = join_cmd_match.group(0)
        r = run_remote(ip, cfg,
                       f"sudo snap install microk8s --classic && sudo {join_cmd}")
        if r.ok:
            log.ok(f"Node {ip} joined MicroK8s cluster")
        else:
            log.warn(f"Node {ip} join failed: {r.stderr}")


def fetch_kubeconfig(cfg: ClusterConfig) -> None:
    first_cp = cfg.first_cp_ip()
    output = Path(cfg.resolved_kubeconfig())
    output.parent.mkdir(parents=True, exist_ok=True)

    with make_client(first_cp, cfg) as c:
        r = c.run("sudo microk8s config")
        if not r.ok:
            log.die(f"Could not fetch MicroK8s kubeconfig from {first_cp}")
        output.write_text(r.stdout)
        output.chmod(0o600)
    text = output.read_text()
    text = re.sub(r'https://127\.0\.0\.1:', f'https://{first_cp}:', text)
    output.write_text(text)
    log.ok(f"MicroK8s kubeconfig saved → {output}")
