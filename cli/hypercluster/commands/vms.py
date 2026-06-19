from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from hypercluster import log
from hypercluster.models import ClusterConfig
from hypercluster.paths import config_dir


def list_json(cfg: ClusterConfig) -> dict:
    kc_path = cfg.resolved_kubeconfig()
    if not Path(kc_path).is_file():
        return {"vms": [], "error": f"kubeconfig not found: {kc_path}"}

    env = dict(os.environ, KUBECONFIG=kc_path)
    r = subprocess.run(
        ["kubectl", "get", "vmi", "-A", "-o", "json"],
        env=env, capture_output=True, text=True,
    )
    vms = []
    if r.returncode == 0:
        data = json.loads(r.stdout)
        for item in data.get("items", []):
            meta = item.get("metadata", {})
            status = item.get("status", {})
            interfaces = status.get("interfaces", [])
            ip = interfaces[0].get("ipAddress", "") if interfaces else ""
            vms.append({
                "namespace": meta.get("namespace", "default"),
                "name": meta.get("name", ""),
                "phase": status.get("phase", "unknown"),
                "ip": ip,
            })

    templates = _load_templates()
    return {"vms": vms, "templates": templates}


def _load_templates() -> list:
    tpl_file = config_dir() / "kubevirt-templates.json"
    if not tpl_file.is_file():
        return []
    try:
        return json.loads(tpl_file.read_text())
    except (json.JSONDecodeError, OSError):
        return []


def create_json(template_id: str, name: str, namespace: str, cfg: ClusterConfig) -> dict:
    templates = _load_templates()
    tpl = next((t for t in templates if t.get("id") == template_id), None)
    if not tpl:
        return {"ok": False, "error": f"Unknown template: {template_id}"}
    if not name:
        return {"ok": False, "error": "VM name is required"}
    return {
        "ok": True,
        "message": f"VM '{name}' would be created in namespace '{namespace}' using template '{template_id}'",
        "template": tpl,
    }


def cmd_vms(cfg: ClusterConfig, json_mode: bool = False) -> None:
    data = list_json(cfg)
    if json_mode:
        print(json.dumps(data))
        return
    log.section(f"KubeVirt VMs: {cfg.CLUSTER_NAME}")
    vms = data.get("vms", [])
    if not vms:
        print("(no running VMIs — enable KubeVirt and create VMs)")
        return
    for vm in vms:
        ns = vm.get("namespace", "default")
        name = vm.get("name", "?")
        phase = vm.get("phase", "?")
        ip = vm.get("ip", "")
        print(f"{ns}/{name}  {phase}  {ip}")


def cmd_vm_create(cfg: ClusterConfig, template: str, name: str, namespace: str = "default",
                  json_mode: bool = False) -> None:
    result = create_json(template, name, namespace, cfg)
    if json_mode:
        print(json.dumps(result))
        return
    print(result.get("message", str(result)))
