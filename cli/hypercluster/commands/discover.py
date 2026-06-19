from __future__ import annotations

import json
import subprocess
from pathlib import Path

from hypercluster import log


def run(source: str = "libvirt", json_mode: bool = False, **kwargs) -> dict:
    if source == "libvirt":
        return _discover_libvirt(json_mode)
    elif source == "ssh-scan":
        hosts = kwargs.get("hosts", "")
        return _discover_ssh_scan(hosts, json_mode)
    elif source == "csv":
        csv_file = kwargs.get("csv_file", "")
        return _discover_csv(csv_file, json_mode)
    else:
        log.die(f"Unknown discover source: {source}\nUse: libvirt, ssh-scan, csv")
        return {}


def _discover_libvirt(json_mode: bool) -> dict:
    r = subprocess.run(
        ["virsh", "list", "--all", "--name"],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        result = {"ok": False, "source": "libvirt", "nodes": [], "validations": [],
                  "error": "virsh not available or libvirt not running"}
        if json_mode:
            print(json.dumps(result))
        else:
            log.error(result["error"])
        return result

    names = [n.strip() for n in r.stdout.splitlines() if n.strip()]
    hosts = []
    for name in names:
        ip_r = subprocess.run(
            ["virsh", "domifaddr", name, "--source", "agent"],
            capture_output=True, text=True,
        )
        ip = ""
        for line in ip_r.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 4 and "/" in parts[3]:
                ip = parts[3].split("/")[0]
                break
        hosts.append({"name": name, "ip": ip, "source": "libvirt"})

    result = {"ok": True, "source": "libvirt", "nodes": hosts, "validations": []}
    if json_mode:
        print(json.dumps(result))
    else:
        log.section(f"Discovered {len(hosts)} VMs (libvirt)")
        for h in hosts:
            print(f"  {h['name']}  {h['ip']}")
    return result


def _discover_ssh_scan(hosts_str: str, json_mode: bool) -> dict:
    if not hosts_str:
        log.die("--hosts required for ssh-scan discover (e.g. 192.168.1.0/24 or IP1,IP2)")
    result = {"ok": True, "source": "ssh-scan", "nodes": [], "validations": [], "message": f"Scan range: {hosts_str}"}
    if json_mode:
        print(json.dumps(result))
    else:
        log.info(f"SSH scan of {hosts_str} (requires nmap/ssh available)")
    return result


def _discover_csv(csv_file: str, json_mode: bool) -> dict:
    if not csv_file or not Path(csv_file).is_file():
        log.die(f"CSV file not found: {csv_file}")
    import csv as csv_mod
    hosts = []
    with open(csv_file) as f:
        reader = csv_mod.DictReader(f)
        for row in reader:
            hosts.append({"name": row.get("name", ""), "ip": row.get("ip", ""), "source": "csv"})
    result = {"ok": True, "source": "csv", "nodes": hosts, "validations": []}
    if json_mode:
        print(json.dumps(result))
    else:
        log.section(f"Discovered {len(hosts)} hosts from CSV")
        for h in hosts:
            print(f"  {h['name']}  {h['ip']}")
    return result
