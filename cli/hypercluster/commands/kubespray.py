from __future__ import annotations

import os
import subprocess
import sys
import venv
from pathlib import Path

from hypercluster import log, proc
from hypercluster.models import ClusterConfig
from hypercluster.paths import data_dir


def _venv_dir(kubespray_dir: Path) -> Path:
    d = data_dir()
    d_venv = d / "kubespray-venv"
    if d != kubespray_dir.parent:
        return kubespray_dir.parent / ".kubespray-venv"
    return d_venv


def _ensure_venv(kubespray_dir: Path) -> Path:
    venv_dir = _venv_dir(kubespray_dir)
    if not (venv_dir / "bin" / "python").is_file() and not (venv_dir / "Scripts" / "python.exe").is_file():
        log.info(f"Creating Python venv at {venv_dir} …")
        venv.create(str(venv_dir), with_pip=True)
    return venv_dir


def _venv_python(venv_dir: Path) -> str:
    if sys.platform == "win32":
        return str(venv_dir / "Scripts" / "python.exe")
    return str(venv_dir / "bin" / "python")


def _install_requirements(kubespray_dir: Path, venv_dir: Path) -> None:
    req = kubespray_dir / "requirements.txt"
    if not req.is_file():
        log.warn(f"No requirements.txt in {kubespray_dir} — skipping pip install")
        return
    log.info("Installing Python requirements into venv …")
    py = _venv_python(venv_dir)
    result = subprocess.run(
        [py, "-m", "pip", "install", "-r", str(req)],
        check=False,
    )
    if result.returncode != 0:
        log.die("pip install failed — check requirements.txt")
    log.ok("Python requirements installed.")


def _clone(kubespray_dir: Path, version: str) -> None:
    log.info(f"Cloning Kubespray {version} …")
    proc.run(["git", "clone", "--depth", "1", "--branch", version,
              "https://github.com/kubernetes-sigs/kubespray.git", str(kubespray_dir)])
    log.ok(f"Kubespray cloned → {kubespray_dir}")
    venv_dir = _ensure_venv(kubespray_dir)
    _install_requirements(kubespray_dir, venv_dir)


def ensure_source(kubespray_dir: Path, version: str, force: bool = False) -> None:
    if (kubespray_dir / ".git").is_dir():
        current_tag = proc.capture(
            ["git", "-C", str(kubespray_dir), "describe", "--tags", "--exact-match"],
            default="unknown",
        )
        if current_tag == version:
            log.info(f"Kubespray {version} already present at {kubespray_dir}")
            venv_dir = _ensure_venv(kubespray_dir)
            _install_requirements(kubespray_dir, venv_dir)
            return
        log.warn(f"Version mismatch: cloned={current_tag} requested={version}.")
        if not force:
            log.die(
                f"Kubespray dir {kubespray_dir} is at the wrong version.\n"
                "Re-run with -f to re-clone (WARNING: local changes will be deleted)."
            )
        log.warn(f"Re-cloning (--force) — deleting {kubespray_dir}")
        import shutil
        shutil.rmtree(kubespray_dir)

    _clone(kubespray_dir, version)


def _ansible_args(inv_dir: Path, cfg: ClusterConfig) -> list[str]:
    args = [
        "-i", str(inv_dir / "hosts.yaml"),
        "--private-key", cfg.resolved_ssh_key(),
        "--user", cfg.SSH_USER,
        "--become",
    ]
    if proc.DRY_RUN:
        pass
    if cfg.SSH_EXTRA_ARGS:
        args += ["--ssh-extra-args", cfg.SSH_EXTRA_ARGS]
    return args


def run_playbook(kubespray_dir: Path, playbook: str, cfg: ClusterConfig, extra_args: list[str] | None = None) -> None:
    inv_dir = kubespray_dir / "inventory" / cfg.CLUSTER_NAME
    base_args = _ansible_args(inv_dir, cfg)
    pb_path = kubespray_dir / playbook

    if proc.DRY_RUN:
        log.warn(f"DRY RUN — skipping actual playbook execution: {playbook}")
        return

    log.info(f"Running playbook: {playbook}")

    venv_dir = _ensure_venv(kubespray_dir)
    if sys.platform == "win32":
        ap = str(venv_dir / "Scripts" / "ansible-playbook.exe")
    else:
        ap = str(venv_dir / "bin" / "ansible-playbook")

    cmd = [ap] + base_args + (extra_args or []) + [str(pb_path)]
    rc = proc.run_stream(cmd)
    if rc != 0:
        log.die(f"Playbook {playbook} failed with exit code {rc}")
