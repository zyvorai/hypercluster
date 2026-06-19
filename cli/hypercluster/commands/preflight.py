from __future__ import annotations

import json
import os
import stat
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.ssh import check_connectivity, make_client


class PreflightRunner:
    def __init__(self, cfg: ClusterConfig, json_mode: bool = False) -> None:
        self.cfg = cfg
        self.json_mode = json_mode
        self._checks: list[dict] = []
        self._failed = 0

    def _record(self, passed: bool, name: str, detail: str = "") -> None:
        item: dict = {"name": name, "passed": passed}
        if detail:
            item["detail"] = detail
        self._checks.append(item)
        if not passed:
            self._failed += 1

    def _pass(self, name: str, detail: str = "") -> None:
        self._record(True, name, detail)
        log.ok(f"{name}{' — ' + detail if detail else ''}")

    def _fail(self, name: str, detail: str = "") -> None:
        self._record(False, name, detail)
        log.error(f"{name}{' — ' + detail if detail else ''}")

    def check_command(self, cmd: str) -> bool:
        path = proc.find_cmd(cmd)
        if path:
            self._pass(f"Command: {cmd}", path)
            return True
        self._fail(f"Command: {cmd}", "not found")
        return False

    def check_ssh_key(self) -> bool:
        key = Path(self.cfg.resolved_ssh_key())
        if not key.is_file():
            self._fail("SSH key", f"not found: {key}")
            log.die(f"SSH key not found: {key}")
        mode = oct(stat.S_IMODE(key.stat().st_mode))
        if mode != "0o600":
            log.warn(f"SSH key permissions are {mode} — fixing to 600: {key}")
            key.chmod(0o600)
        self._pass("SSH key", str(key))
        return True

    def check_ssh_connectivity(self) -> bool:
        all_ips = self.cfg.all_ips()
        failed = 0
        for ip in all_ips:
            log.info(f"Testing SSH → {self.cfg.SSH_USER}@{ip} …")
            if check_connectivity(ip, self.cfg):
                self._pass(f"SSH connectivity: {self.cfg.SSH_USER}@{ip}")
            else:
                self._fail(f"SSH connectivity: {self.cfg.SSH_USER}@{ip}")
                failed += 1
        if failed:
            log.die(f"SSH connectivity check failed for {failed} node(s).")
        return True

    def check_k3s_remote(self) -> None:
        first_cp = self.cfg.first_cp_ip()
        log.info("Checking passwordless sudo on control plane …")
        try:
            with make_client(first_cp, self.cfg) as c:
                r = c.run("sudo -n true")
                if r.ok:
                    self._pass("Passwordless sudo on control plane")
                else:
                    self._fail("Passwordless sudo on control plane", "required for k3s deploy")
                    log.die(
                        f"Passwordless sudo required on remote nodes for k3s deploy.\n"
                        f"On the server run: echo '{self.cfg.SSH_USER} ALL=(ALL) NOPASSWD:ALL' | "
                        f"sudo tee /etc/sudoers.d/{self.cfg.SSH_USER}-hypercluster"
                    )
        except Exception as e:
            self._fail("Passwordless sudo on control plane", str(e))

        if self.cfg.METALLB_ENABLED and not self.cfg.METALLB_IP_POOL:
            self._fail("MetalLB IP pool", "METALLB_ENABLED=true but METALLB_IP_POOL is empty")
            log.die(
                'METALLB_ENABLED=true but METALLB_IP_POOL is empty.\n'
                'Set METALLB_IP_POOL="192.168.1.240-192.168.1.250" in cluster.conf'
            )
        if self.cfg.METALLB_IP_POOL:
            self._pass("MetalLB IP pool", self.cfg.METALLB_IP_POOL)

        if self.cfg.KUBEVIRT_ENABLED:
            log.info("Checking /dev/kvm on control plane …")
            try:
                with make_client(first_cp, self.cfg) as c:
                    r = c.run("test -e /dev/kvm")
                    if r.ok:
                        self._pass("/dev/kvm on control plane")
                    else:
                        self._fail("/dev/kvm on control plane", "KubeVirt may need useEmulation")
                        log.warn("/dev/kvm not present — KubeVirt VMs may fail unless useEmulation is enabled")
            except Exception:
                self._fail("/dev/kvm on control plane", "check failed")

    def emit_json(self) -> None:
        result = {"ok": self._failed == 0, "checks": self._checks}
        print(json.dumps(result))

    def run(self) -> bool:
        if not self.json_mode:
            log.section("Preflight checks")

        distro = self.cfg.distro()
        required_cmds = ["ssh", "scp", "git", "kubectl", "curl"]
        if distro == "kubespray":
            required_cmds += ["ansible", "ansible-playbook", "python3"]
        elif distro == "k3s":
            required_cmds.append("helm")

        failed_cmds = 0
        for cmd in required_cmds:
            if not self.check_command(cmd):
                failed_cmds += 1

        if failed_cmds:
            log.die(f"Fix the {failed_cmds} missing dependency/dependencies above, then re-run.")

        if not self.json_mode:
            log.ok("All required tools present.")

        self.check_ssh_key()
        self.check_ssh_connectivity()

        if distro == "k3s":
            self.check_k3s_remote()

        if self.json_mode:
            self.emit_json()
            return self._failed == 0

        log.ok("Preflight passed. \U0001f680")
        return True
