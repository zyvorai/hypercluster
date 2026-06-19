from __future__ import annotations

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.ssh import run_remote, run_remote_script


def deploy(cfg: ClusterConfig) -> None:
    log.section(f"RKE2 deploy: {cfg.CLUSTER_NAME}")
    server_ip = cfg.first_cp_ip()
    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping RKE2 install.")
        return

    log.info(f"Installing RKE2 server on {server_ip} …")
    r = run_remote(server_ip, cfg,
                   "curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_TYPE=server sh - && "
                   "sudo systemctl enable rke2-server && sudo systemctl start rke2-server")
    if not r.ok:
        log.die(f"RKE2 server install failed on {server_ip}")
    log.ok(f"RKE2 server installed on {server_ip}")

    token_result = run_remote(server_ip, cfg,
                               "sudo cat /var/lib/rancher/rke2/server/node-token", stream=False)
    if not token_result.ok:
        log.die(f"Could not read RKE2 token from {server_ip}")
    token = token_result.stdout.strip()

    for ip in cfg.worker_ips():
        if not ip:
            continue
        log.info(f"Joining agent {ip} …")
        r = run_remote(ip, cfg,
                       f"curl -sfL https://get.rke2.io | sudo INSTALL_RKE2_TYPE=agent sh - && "
                       f"sudo mkdir -p /etc/rancher/rke2 && "
                       f"echo 'server: https://{server_ip}:9345\ntoken: {token}' | "
                       f"sudo tee /etc/rancher/rke2/config.yaml && "
                       f"sudo systemctl enable rke2-agent && sudo systemctl start rke2-agent")
        if not r.ok:
            log.die(f"RKE2 agent join failed on {ip}")
        log.ok(f"Agent {ip} joined")


def fetch_kubeconfig(cfg: ClusterConfig) -> None:
    from hypercluster.commands.kubeconfig import fetch_k3s
    import re
    from pathlib import Path
    first_cp = cfg.first_cp_ip()
    from hypercluster.ssh import make_client
    output = Path(cfg.resolved_kubeconfig())
    output.parent.mkdir(parents=True, exist_ok=True)
    with make_client(first_cp, cfg) as c:
        r = c.run("sudo cat /etc/rancher/rke2/rke2.yaml")
        if not r.ok:
            log.die(f"Could not fetch RKE2 kubeconfig from {first_cp}")
        output.write_text(r.stdout)
        output.chmod(0o600)
    text = output.read_text()
    text = re.sub(r'https://127\.0\.0\.1:', f'https://{first_cp}:', text)
    output.write_text(text)
    log.ok(f"RKE2 kubeconfig saved → {output}")
