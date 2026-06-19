from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from hypercluster import log
from hypercluster.models import ClusterConfig


def workloads_json(cfg: ClusterConfig) -> dict:
    kc_path = cfg.resolved_kubeconfig()
    if not Path(kc_path).is_file():
        return {"pods": [], "services": [], "error": f"kubeconfig not found: {kc_path}"}

    env = dict(os.environ, KUBECONFIG=kc_path)

    r_pods = subprocess.run(
        ["kubectl", "get", "pods", "-A", "-o", "json"],
        env=env, capture_output=True, text=True,
    )
    pods = []
    if r_pods.returncode == 0:
        for item in json.loads(r_pods.stdout).get("items", []):
            pods.append({
                "namespace": item["metadata"].get("namespace", "default"),
                "name": item["metadata"]["name"],
                "phase": item.get("status", {}).get("phase", "unknown"),
            })

    r_svcs = subprocess.run(
        ["kubectl", "get", "svc", "-A", "-o", "json"],
        env=env, capture_output=True, text=True,
    )
    services = []
    if r_svcs.returncode == 0:
        for item in json.loads(r_svcs.stdout).get("items", []):
            services.append({
                "namespace": item["metadata"].get("namespace", "default"),
                "name": item["metadata"]["name"],
                "type": item.get("spec", {}).get("type", "ClusterIP"),
                "clusterIP": item.get("spec", {}).get("clusterIP", ""),
            })

    return {"pods": pods, "services": services}


def cmd_workloads(cfg: ClusterConfig, json_mode: bool = False) -> None:
    data = workloads_json(cfg)
    if json_mode:
        print(json.dumps(data))
        return
    log.section(f"Workloads: {cfg.CLUSTER_NAME}")
    pods = data.get("pods", [])
    svcs = data.get("services", [])
    print(f"Pods: {len(pods)}  Services: {len(svcs)}")
    for p in pods[:20]:
        print(f"{p['namespace']}/{p['name']}  {p['phase']}")
    if len(pods) > 20:
        print(f"... and {len(pods) - 20} more pods")
