from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

from hypercluster import log


def _lock_dir(cluster_name: str) -> Path:
    return Path(tempfile.gettempdir()) / f"hypercluster-{cluster_name}.lock"


def acquire(cluster_name: str) -> Path:
    lock_dir = _lock_dir(cluster_name)
    pid_file = lock_dir / "pid"

    if lock_dir.is_dir():
        if pid_file.is_file():
            try:
                old_pid = int(pid_file.read_text().strip())
            except (ValueError, OSError):
                old_pid = None
            if old_pid and _pid_running(old_pid):
                log.die(
                    f"Another hypercluster instance is already running for cluster "
                    f"'{cluster_name}' (PID {old_pid}).\n"
                    f"Lock dir: {lock_dir} — use 'hypercluster unlock' if the previous run crashed."
                )
            log.warn(f"Removing stale lock for cluster '{cluster_name}' (PID {old_pid} not running).")
            import shutil
            shutil.rmtree(lock_dir, ignore_errors=True)
        else:
            log.die(
                f"Lock dir exists without PID file: {lock_dir}\n"
                "Remove it manually or run 'hypercluster unlock'."
            )

    try:
        lock_dir.mkdir(parents=False, exist_ok=False)
    except FileExistsError:
        log.die(f"Could not acquire lock for cluster '{cluster_name}' ({lock_dir}).")

    pid_file.write_text(str(os.getpid()))
    return lock_dir


def release(lock_dir: Path | None) -> None:
    if lock_dir and lock_dir.is_dir():
        import shutil
        shutil.rmtree(lock_dir, ignore_errors=True)


def unlock_cluster(cluster_name: str) -> None:
    lock_dir = _lock_dir(cluster_name)
    if not lock_dir.is_dir():
        log.info(f"No lock found for cluster '{cluster_name}'.")
        return
    import shutil
    shutil.rmtree(lock_dir)
    log.ok(f"Lock removed for cluster '{cluster_name}'.")


def _pid_running(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False
