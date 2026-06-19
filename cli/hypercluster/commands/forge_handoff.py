from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from hypercluster import log
from hypercluster.models import ClusterConfig


def run(cfg: ClusterConfig, json_mode: bool = False) -> dict:
    kc_path = cfg.resolved_kubeconfig()
    env = dict(os.environ, KUBECONFIG=kc_path) if Path(kc_path).is_file() else os.environ.copy()

    nodes = []
    r = subprocess.run(["kubectl", "get", "nodes", "-o", "json"], env=env,
                       capture_output=True, text=True)
    if r.returncode == 0:
        for item in json.loads(r.stdout).get("items", []):
            nodes.append({
                "name": item["metadata"]["name"],
                "labels": item["metadata"].get("labels", {}),
            })

    handoff = {
        "cluster_name": cfg.CLUSTER_NAME,
        "distro": cfg.distro(),
        "kubeconfig": kc_path,
        "control_plane_ips": cfg.control_plane_ips(),
        "worker_ips": cfg.worker_ips(),
        "kubevirt_enabled": cfg.KUBEVIRT_ENABLED,
        "nodes": nodes,
    }

    if json_mode:
        print(json.dumps(handoff))
    else:
        log.section(f"Forge handoff: {cfg.CLUSTER_NAME}")
        print(json.dumps(handoff, indent=2))
    return handoff
