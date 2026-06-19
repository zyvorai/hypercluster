from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from hypercluster import log
from hypercluster.models import ClusterConfig


def run(cfg: ClusterConfig, json_mode: bool = False, with_test: bool = False) -> None:
    kc_path = cfg.resolved_kubeconfig()
    if not Path(kc_path).is_file():
        log.die(f"kubeconfig not found: {kc_path} — run 'fetch-kubeconfig' first.")

    env = dict(os.environ, KUBECONFIG=kc_path)

    # Nodes
    r_nodes = subprocess.run(
        ["kubectl", "get", "nodes", "-o", "json"],
        env=env, capture_output=True, text=True,
    )
    nodes = []
    if r_nodes.returncode == 0:
        data = json.loads(r_nodes.stdout)
        for item in data.get("items", []):
            name = item["metadata"]["name"]
            conds = item.get("status", {}).get("conditions", [])
            is_ready = any(c["type"] == "Ready" and c["status"] == "True" for c in conds)
            nodes.append({"name": name, "ready": is_ready})

    # Pods
    r_pods = subprocess.run(
        ["kubectl", "get", "pods", "-A", "-o", "json"],
        env=env, capture_output=True, text=True,
    )
    pod_count = 0
    if r_pods.returncode == 0:
        pod_count = len(json.loads(r_pods.stdout).get("items", []))

    # Services
    r_svcs = subprocess.run(
        ["kubectl", "get", "svc", "-A", "-o", "json"],
        env=env, capture_output=True, text=True,
    )
    svc_count = 0
    if r_svcs.returncode == 0:
        svc_count = len(json.loads(r_svcs.stdout).get("items", []))

    # VMs
    r_vms = subprocess.run(
        ["kubectl", "get", "vmi", "-A", "-o", "json"],
        env=env, capture_output=True, text=True,
    )
    vm_count = 0
    if r_vms.returncode == 0:
        vm_count = len(json.loads(r_vms.stdout).get("items", []))

    ready_nodes = sum(1 for n in nodes if n["ready"])
    ok_overall = ready_nodes == len(nodes) and len(nodes) > 0

    test_results = None
    if with_test and cfg.distro() == "k3s":
        from hypercluster.commands.platform_test import run as test_run
        test_ok = test_run(cfg, json_mode=False)
        test_results = {"ok": test_ok}

    if json_mode:
        report = {
            "ok": ok_overall,
            "cluster": cfg.CLUSTER_NAME,
            "nodes": {"ready": ready_nodes, "total": len(nodes), "list": nodes},
            "pods": pod_count,
            "services": svc_count,
            "vms": vm_count,
        }
        if test_results is not None:
            report["tests"] = test_results
        print(json.dumps(report))
        return

    log.section(f"Cluster health: {cfg.CLUSTER_NAME}")
    print(f"  Nodes:    {ready_nodes}/{len(nodes)} ready")
    print(f"  Pods:     {pod_count}")
    print(f"  Services: {svc_count}")
    print(f"  VMs:      {vm_count}")
    if test_results:
        status = "✅" if test_results["ok"] else "❌"
        print(f"  Tests:    {status}")
    if ok_overall:
        log.ok("Cluster healthy")
    else:
        log.warn("Some nodes not ready")
