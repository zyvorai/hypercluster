from __future__ import annotations

import re
from pathlib import Path

from hypercluster.models import ClusterConfig


_VAR_RE = re.compile(r'^([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$')


def _strip_quotes(value: str) -> str:
    value = value.strip()
    if (value.startswith('"') and value.endswith('"')) or \
       (value.startswith("'") and value.endswith("'")):
        value = value[1:-1]
    return value


def _parse_bash_conf(path: Path) -> dict[str, str]:
    raw: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        m = _VAR_RE.match(line)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        # strip inline comment
        val = re.sub(r'\s+#.*$', '', val).strip()
        raw[key] = _strip_quotes(val)
    return raw


def load_config(config_path: str) -> ClusterConfig:
    p = Path(config_path).expanduser().resolve()
    if not p.is_file():
        raise FileNotFoundError(
            f"Config file not found: {config_path}\n"
            "Run: hypercluster wizard\n"
            "Or:  cp config/cluster.conf.example cluster.conf"
        )
    raw = _parse_bash_conf(p)
    # Normalize bool-like strings from shell config
    bool_keys = {k for k in ClusterConfig.model_fields if
                 ClusterConfig.model_fields[k].annotation in (bool, "bool")}
    for k, v in list(raw.items()):
        if v.lower() in ("true", "1", "yes"):
            raw[k] = "true" if k in bool_keys else v
        elif v.lower() in ("false", "0", "no"):
            raw[k] = "false" if k in bool_keys else v
    return ClusterConfig.model_validate(raw)
