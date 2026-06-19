from __future__ import annotations

import shutil
import subprocess
import sys
from typing import Sequence

from hypercluster import log

DRY_RUN: bool = False


def find_cmd(name: str) -> str | None:
    return shutil.which(name)


def run(
    cmd: Sequence[str],
    env: dict | None = None,
    capture: bool = False,
    check: bool = True,
    dry_run: bool | None = None,
) -> subprocess.CompletedProcess:
    _dry = DRY_RUN if dry_run is None else dry_run
    if _dry:
        log.warn(f"DRY RUN — {' '.join(str(c) for c in cmd)}")
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    stdout = subprocess.PIPE if capture else None
    stderr = subprocess.PIPE if capture else None

    result = subprocess.run(
        cmd,
        env=env,
        stdout=stdout,
        stderr=stderr,
        text=capture,
    )
    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, cmd)
    return result


def run_stream(
    cmd: Sequence[str],
    env: dict | None = None,
    dry_run: bool | None = None,
) -> int:
    _dry = DRY_RUN if dry_run is None else dry_run
    if _dry:
        log.warn(f"DRY RUN — {' '.join(str(c) for c in cmd)}")
        return 0
    proc = subprocess.Popen(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    assert proc.stdout
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
    proc.wait()
    return proc.returncode


def capture(cmd: Sequence[str], env: dict | None = None, default: str = "") -> str:
    try:
        r = run(cmd, env=env, capture=True, check=True)
        return (r.stdout or "").strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return default
