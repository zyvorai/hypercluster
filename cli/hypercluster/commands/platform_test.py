from __future__ import annotations

import json
import subprocess
import os

from hypercluster import log, proc
from hypercluster.models import ClusterConfig


def _kubectl(cfg: ClusterConfig, *args: str) -> subprocess.CompletedProcess:
    kc = cfg.resolved_kubeconfig()
    env = dict(os.environ, KUBECONFIG=kc)
    return subprocess.run(["kubectl"] + list(args), env=env, capture_output=True, text=True)


def _check_nodes(cfg: ClusterConfig, checks: list, failed: list) -> None:
    r = _kubectl(cfg, "get", "nodes", "-o", "json")
    if r.returncode != 0:
        checks.append({"name": "Node readiness", "passed": False, "detail": "kubectl get nodes failed"})
        failed.append("nodes")
        return
    data = json.loads(r.stdout)
    items = data.get("items", [])
    not_ready = [
        n["metadata"]["name"] for n in items
        if not any(c["type"] == "Ready" and c["status"] == "True"
                   for c in n.get("status", {}).get("conditions", []))
    ]
    if not_ready:
        checks.append({"name": "Node readiness", "passed": False,
                       "detail": f"Not ready: {', '.join(not_ready)}"})
        failed.append("nodes")
    else:
        checks.append({"name": "Node readiness", "passed": True,
                       "detail": f"{len(items)} node(s) ready"})


def _check_pods(cfg: ClusterConfig, ns: str, label: str, checks: list, failed: list) -> None:
    r = _kubectl(cfg, "get", "pods", "-n", ns, "-l", label, "-o", "json")
    if r.returncode != 0:
        checks.append({"name": f"Pods: {label}", "passed": False, "detail": f"kubectl failed in {ns}"})
        failed.append(label)
        return
    data = json.loads(r.stdout)
    items = data.get("items", [])
    if not items:
        checks.append({"name": f"Pods: {label}", "passed": False, "detail": "no pods found"})
        failed.append(label)
        return
    not_running = [
        p["metadata"]["name"] for p in items
        if p.get("status", {}).get("phase") != "Running"
    ]
    if not_running:
        checks.append({"name": f"Pods: {label}", "passed": False,
                       "detail": f"Not running: {', '.join(not_running)}"})
        failed.append(label)
    else:
        checks.append({"name": f"Pods: {label}", "passed": True,
                       "detail": f"{len(items)} pod(s) running"})


def run(cfg: ClusterConfig, json_mode: bool = False, full: bool = False) -> bool:
    if cfg.distro() != "k3s":
        log.die("test command is for K8S_DISTRO=k3s only. Use kubectl checks for Kubespray clusters.")

    if not json_mode:
        log.section("Platform smoke tests")

    checks: list = []
    failed: list = []

    _check_nodes(cfg, checks, failed)
    _check_pods(cfg, "kube-system", "app.kubernetes.io/name=cilium", checks, failed)

    if cfg.CERT_MANAGER_ENABLED:
        _check_pods(cfg, "cert-manager", "app.kubernetes.io/name=cert-manager", checks, failed)

    if cfg.METALLB_ENABLED:
        _check_pods(cfg, "metallb-system", "app=metallb", checks, failed)

    if cfg.KUBEVIRT_ENABLED:
        _check_pods(cfg, "kubevirt", "kubevirt.io=virt-api", checks, failed)
        if cfg.CDI_ENABLED:
            _check_pods(cfg, "cdi", "app=containerized-data-importer", checks, failed)

    ok = len(failed) == 0
    if json_mode:
        print(json.dumps({"ok": ok, "checks": checks}))
        return ok

    for c in checks:
        if c["passed"]:
            log.ok(f"{c['name']}{' — ' + c.get('detail','') if c.get('detail') else ''}")
        else:
            log.error(f"{c['name']}{' — ' + c.get('detail','') if c.get('detail') else ''}")

    if ok:
        log.ok("All platform tests passed \U0001f680")
    else:
        log.error(f"{len(failed)} test(s) failed: {', '.join(failed)}")
    return ok
