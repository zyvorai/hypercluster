from __future__ import annotations

import sys
import threading
import time

from hypercluster import log, proc


def stage(current: int, total: int, label: str) -> None:
    if sys.stderr.isatty() and not proc.DRY_RUN:
        print(f"\n\033[1m[{current}/{total}]\033[0m {label}", file=sys.stderr)
    else:
        log.section(f"[{current}/{total}] {label}")


class Spinner:
    _FRAMES = "|/-\\"

    def __init__(self, msg: str) -> None:
        self.msg = msg
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if not sys.stderr.isatty():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._spin, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=1)
        if sys.stderr.isatty():
            print("\r\033[K", end="", file=sys.stderr)

    def _spin(self) -> None:
        i = 0
        while not self._stop.is_set():
            frame = self._FRAMES[i % 4]
            print(f"\r\033[36m{frame}\033[0m {self.msg}", end="", file=sys.stderr, flush=True)
            i += 1
            time.sleep(0.12)
