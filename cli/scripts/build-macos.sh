#!/usr/bin/env bash
# Build hypercluster native binary for macOS / Linux via PyInstaller
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_DIR="$(dirname "$SCRIPT_DIR")"

cd "$CLI_DIR"

echo "-> Creating Python venv …"
python3 -m venv .venv
source .venv/bin/activate

echo "-> Installing dependencies …"
pip install --upgrade pip
pip install -e ".[dev]"

echo "-> Building with PyInstaller …"
pyinstaller hypercluster.spec --clean --noconfirm

echo "-> Binary: $CLI_DIR/dist/hypercluster"
ls -lh dist/hypercluster
