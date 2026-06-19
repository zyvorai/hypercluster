import sys
import time

VERBOSE: bool = False


def _ts() -> str:
    return time.strftime("%H:%M:%S")


def info(msg: str) -> None:
    print(f"[{_ts()}] ➜  {msg}", file=sys.stderr)


def ok(msg: str) -> None:
    print(f"[{_ts()}] ✅  {msg}", file=sys.stderr)


def warn(msg: str) -> None:
    print(f"[{_ts()}] ⚠️   {msg}", file=sys.stderr)


def error(msg: str) -> None:
    print(f"[{_ts()}] ❌  {msg}", file=sys.stderr)


def section(msg: str) -> None:
    print(f"\n\U0001f537  {msg}\n{'─' * 60}\n", file=sys.stderr)


def debug(msg: str) -> None:
    if VERBOSE:
        print(f"[{_ts()}] \U0001f41b  {msg}", file=sys.stderr)


def die(msg: str) -> None:
    error(msg)
    sys.exit(1)
