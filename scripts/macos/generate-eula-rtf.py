#!/usr/bin/env python3
"""Generate EULA.rtf for macOS .pkg installer license pane."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "desktop/distribution/HYPERCLUSTER-EULA.txt"
OUT = ROOT / "desktop/distribution/EULA.rtf"


def rtf_escape(text: str) -> str:
    out = []
    for ch in text:
        if ch == "\\":
            out.append("\\\\")
        elif ch == "{":
            out.append("\\{")
        elif ch == "}":
            out.append("\\}")
        elif ch == "\n":
            out.append("\\par\n")
        elif ord(ch) > 127:
            out.append(f"\\u{ord(ch)}?")
        else:
            out.append(ch)
    return "".join(out)


def main() -> None:
    body = SRC.read_text(encoding="utf-8")
    rtf = (
        "{\\rtf1\\ansi\\deff0\n"
        "{\\fonttbl{\\f0 Helvetica;}}\n"
        "\\f0\\fs22\n"
        + rtf_escape(body)
        + "\n}"
    )
    OUT.write_text(rtf, encoding="utf-8")
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
