import json
import sys
from typing import Any


def emit(ok: bool, data: Any = None, error: str | None = None, as_json: bool = False) -> None:
    if as_json:
        payload: dict = {"ok": ok}
        if data is not None:
            payload["data"] = _to_json_safe(data)
        if error is not None:
            payload["error"] = error
        print(json.dumps(payload))
    else:
        if data is not None and not ok:
            print(str(data), file=sys.stderr)
        elif data is not None:
            _print_text(data)
        if error and not as_json:
            print(f"Error: {error}", file=sys.stderr)


def _print_text(data: Any) -> None:
    if isinstance(data, str):
        print(data)
    elif isinstance(data, (list, dict)):
        print(json.dumps(data, indent=2))
    else:
        print(str(data))


def _to_json_safe(obj: Any) -> Any:
    if hasattr(obj, "model_dump"):
        return obj.model_dump()
    if hasattr(obj, "__dict__"):
        return obj.__dict__
    return obj
