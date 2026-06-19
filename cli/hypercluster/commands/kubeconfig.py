from __future__ import annotations

import os
import re
import subprocess
import time
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.ssh import make_client


def _patch_server(output: Path, first_cp_ip: str, cfg: ClusterConfig) -> None:
    text = output.read_text()
    if cfg.K3S_API_LOCAL_PORT:
        port = cfg.K3S_API_LOCAL_PORT
        log.info(f"Patching server address → 127.0.0.1:{port} (SSH API tunnel)")
        text = re.sub(r'https://127\.0\.0\.1:\d+', f'https://127.0.0.1:{port}', text)
        text = re.sub(r'https://localhost:\d+', f'https://127.0.0.1:{port}', text)
        text = re.sub(rf'https://{re.escape(first_cp_ip)}:6443', f'https://127.0.0.1:{port}', text)
    else:
        log.info(f"Patching server address → {first_cp_ip}")
        text = re.sub(r'https://127\.0\.0\.1:', f'https://{first_cp_ip}:', text)
        text = re.sub(r'https://localhost:', f'https://{first_cp_ip}:', text)
    output.write_text(text)


def fetch_k3s(cfg: ClusterConfig) -> None:
    first_cp = cfg.first_cp_ip()
    output = Path(cfg.resolved_kubeconfig())
    log.section("Fetching k3s kubeconfig")
    output.parent.mkdir(parents=True, exist_ok=True)

    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping kubeconfig fetch.")
        return

    log.info(f"Reading /etc/rancher/k3s/k3s.yaml from {first_cp} …")
    raw = ""
    for attempt in range(1, 7):
        try:
            with make_client(first_cp, cfg) as c:
                r = c.run("sudo cat /etc/rancher/k3s/k3s.yaml")
                if r.ok and r.stdout:
                    raw = r.stdout
                    break
        except Exception:
            pass
        log.warn(f"kubeconfig fetch attempt {attempt}/6 failed — retrying …")
        time.sleep(10)

    if not raw:
        log.die(f"Failed to fetch kubeconfig from {first_cp}")

    output.write_text(raw)
    output.chmod(0o600)
    _patch_server(output, first_cp, cfg)
    log.ok(f"kubeconfig saved → {output}")
    log.info(f"To use:\n    export KUBECONFIG={output}\n    kubectl get nodes\n")


def fetch(kubespray_dir: Path, cfg: ClusterConfig) -> None:
    if cfg.distro() == "k3s":
        fetch_k3s(cfg)
        return

    first_cp = cfg.first_cp_ip()
    output = Path(cfg.resolved_kubeconfig())
    artifacts_kc = kubespray_dir / "inventory" / cfg.CLUSTER_NAME / "artifacts" / "admin.conf"
    log.section("Fetching kubeconfig")
    output.parent.mkdir(parents=True, exist_ok=True)

    if proc.DRY_RUN:
        log.warn("DRY RUN — skipping kubeconfig fetch.")
        return

    if artifacts_kc.is_file():
        log.info(f"Using local artifacts copy: {artifacts_kc}")
        import shutil
        shutil.copy2(str(artifacts_kc), str(output))
    else:
        log.info(f"Artifacts copy not found — copying via SCP from {first_cp} …")
        with make_client(first_cp, cfg) as c:
            r = c.run("cat /etc/kubernetes/admin.conf")
            if not r.ok:
                log.die(f"Could not fetch admin.conf from {first_cp}")
            output.write_text(r.stdout)

    output.chmod(0o600)
    _patch_server(output, first_cp, cfg)
    log.ok(f"kubeconfig saved → {output}")
    log.info(f"To use:\n    export KUBECONFIG={output}\n    kubectl get nodes\n")


def merge_into_default(cfg: ClusterConfig) -> None:
    import shutil
    from datetime import datetime
    src = Path(cfg.resolved_kubeconfig())
    default = Path.home() / ".kube" / "config"

    if not src.is_file():
        log.die(f"kubeconfig not found at {src} — run 'fetch-kubeconfig' first.")

    default.parent.mkdir(parents=True, exist_ok=True)
    if default.is_file():
        log.info(f"Merging into existing {default} …")
        backup = default.parent / f"config.bak.{datetime.now().strftime('%Y%m%d%H%M%S')}"
        shutil.copy2(str(default), str(backup))
        log.info(f"Backup saved → {backup}")
        merge_env = dict(os.environ, KUBECONFIG=f"{default}{os.pathsep}{src}")
        r = subprocess.run(
            ["kubectl", "config", "view", "--flatten"],
            env=merge_env,
            capture_output=True,
            text=True,
        )
        if r.returncode != 0:
            log.die(f"kubectl config view --flatten failed: {r.stderr}")
        tmp = default.parent / "config.tmp"
        tmp.write_text(r.stdout)
        tmp.replace(default)
    else:
        shutil.copy2(str(src), str(default))

    log.ok(f"kubeconfig merged into {default} \U0001f389")
