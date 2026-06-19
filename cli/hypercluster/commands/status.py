from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from hypercluster import log
from hypercluster.models import ClusterConfig


def cmd_status(cfg: ClusterConfig, json_mode: bool = False) -> None:
    kc_path = cfg.resolved_kubeconfig()
    if not Path(kc_path).is_file():
        log.die(f"kubeconfig not found: {kc_path} — run 'fetch-kubeconfig' first.")

    env = dict(os.environ, KUBECONFIG=kc_path)

    if json_mode:
        r = subprocess.run(
            ["kubectl", "get", "nodes", "-o", "json"],
            env=env, capture_output=True, text=True,
        )
        if r.returncode != 0:
            log.die(f"kubectl get nodes failed: {r.stderr}")
        data = json.loads(r.stdout)
        nodes = []
        ready = 0
        for item in data.get("items", []):
            name = item["metadata"]["name"]
            conds = item.get("status", {}).get("conditions", [])
            is_ready = any(c.get("type") == "Ready" and c.get("status") == "True" for c in conds)
            if is_ready:
                ready += 1
            role = item["metadata"].get("labels", {}).get("node-role.kubernetes.io/control-plane", "")
            nodes.append({"name": name, "ready": is_ready, "roles": role or "worker"})
        print(json.dumps({"ready": ready, "total": len(nodes), "nodes": nodes}))
        return

    log.section(f"Cluster status: {cfg.CLUSTER_NAME}")
    subprocess.run(["kubectl", "get", "nodes", "-o", "wide"], env=env)
