import os
import sys
from pathlib import Path


def _exe_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path(sys.executable).parent
    return Path(__file__).parent


def repo_dir() -> Path:
    env = os.environ.get("HYPERCLUSTER_SCRIPT_DIR")
    if env:
        return Path(env)
    if getattr(sys, "frozen", False):
        return _exe_dir()
    return Path(__file__).parent.parent.parent


def data_dir() -> Path:
    env = os.environ.get("HYPERCLUSTER_DATA_DIR")
    if env:
        return Path(env)
    if _is_bundled_macos_app():
        home = Path.home()
        return home / "Library" / "Application Support" / "Hypercluster"
    if _is_bundled_windows():
        import platformdirs
        return Path(platformdirs.user_data_dir("Hypercluster", "Zyvor"))
    return repo_dir()


def anchor_dir() -> Path:
    return data_dir()


def config_dir() -> Path:
    d = repo_dir() / "config"
    if d.is_dir():
        return d
    alt = _exe_dir() / "config"
    if alt.is_dir():
        return alt
    return d


def _is_bundled_macos_app() -> bool:
    if sys.platform != "darwin":
        return False
    p = str(repo_dir())
    return "Hypercluster.app/Contents/Resources" in p


def _is_bundled_windows() -> bool:
    return sys.platform == "win32" and getattr(sys, "frozen", False)


def version_file() -> Path:
    for candidate in (repo_dir() / "VERSION", _exe_dir() / "VERSION"):
        if candidate.is_file():
            return candidate
    return repo_dir() / "VERSION"


def read_version() -> str:
    vf = version_file()
    try:
        return vf.read_text().strip()
    except FileNotFoundError:
        return "unknown"
