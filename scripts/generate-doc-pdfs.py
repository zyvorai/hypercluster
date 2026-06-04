#!/usr/bin/env python3
"""Generate branded PDFs for hypercluster docs (hyper2kvm-style docs/pdf/)."""
from __future__ import annotations

import importlib.util
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
PDF_DIR = DOCS / "pdf"
PRODUCT = "Hypercluster"
VERSION = (ROOT / "VERSION").read_text().strip() if (ROOT / "VERSION").is_file() else "unknown"

# Load shared BrandedPDF helpers from customer bundle script (hyphenated filename).
_LIB = Path(__file__).resolve().parent / "lib" / "generate-customer-pdfs.py"
_spec = importlib.util.spec_from_file_location("zyvor_pdf", _LIB)
if _spec is None or _spec.loader is None:
    print(f"ERROR: cannot load {_LIB}", file=sys.stderr)
    sys.exit(1)
_gcp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_gcp)

txt_to_pdf = _gcp.txt_to_pdf
BrandedPDF = _gcp.BrandedPDF
_safe = _gcp._safe
_render_body_line = _gcp._render_body_line
_is_rule = _gcp._is_rule
_heading_level = _gcp._heading_level
ORANGE = _gcp.ORANGE
ORANGE_LIGHT = _gcp.ORANGE_LIGHT
SLATE_400 = _gcp.SLATE_400
SLATE_800 = _gcp.SLATE_800
SLATE_950 = _gcp.SLATE_950
WHITE = _gcp.WHITE
XPos = _gcp.XPos
YPos = _gcp.YPos

WELCOME_STEPS = (
    ("Configure", "cp config/cluster.conf.example cluster.conf"),
    ("Deploy", "./hypercluster -c cluster.conf preflight && deploy"),
    ("Verify", "./hypercluster -c cluster.conf test --json"),
)


def resolve_logo() -> Path:
    candidates = [
        DOCS / "zyvor-logo.png",
        ROOT / "docs" / "zyvor-logo.png",
        ROOT.parent / "hyper2kvm-" / "docs" / "zyvor-logo.png",
        ROOT.parent / "packetwolf" / "docs" / "zyvor-logo.png",
    ]
    for p in candidates:
        if p.is_file():
            return p
    return Path("/dev/null")


def md_to_plain(md: str) -> str:
    lines_out: list[str] = []
    in_code = False
    for raw in md.splitlines():
        line = raw.rstrip()
        if line.strip().startswith("<!--"):
            continue
        if line.strip().startswith("```"):
            in_code = not in_code
            if in_code:
                lines_out.append("")
            continue
        if in_code:
            lines_out.append("  " + line)
            continue
        if line.strip() == "---":
            lines_out.append("")
            continue
        # ATX headings -> plain title lines
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            level = len(m.group(1))
            title = m.group(2).strip()
            lines_out.append("")
            if level <= 2:
                lines_out.append(title.upper() if level == 1 else title)
                lines_out.append("=" * min(len(title), 60) if level == 1 else "-" * min(len(title), 60))
            else:
                lines_out.append(title + ":")
            continue
        # Strip md links/images
        line = re.sub(r"!\[([^\]]*)\]\([^)]+\)", r"\1", line)
        line = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)
        line = line.replace("`", "")
        line = re.sub(r"^\|\s*---.*", "", line)  # table separator
        line = line.strip("| ").replace("|", " · ")
        if line:
            lines_out.append(line)
    return "\n".join(lines_out) + "\n"


def md_file_to_pdf(md_path: Path, pdf_path: Path, logo: Path) -> None:
    title = pdf_path.stem.replace("-", " ").replace("_", " ")
    plain = md_to_plain(md_path.read_text(encoding="utf-8"))
    tmp = pdf_path.with_suffix(".gen.txt")
    tmp.write_text(f"{title}\n{'=' * len(title)}\n\n{plain}", encoding="utf-8")
    try:
        txt_to_pdf(tmp, pdf_path, logo if logo.is_file() else Path("/dev/null"), PRODUCT)
    finally:
        tmp.unlink(missing_ok=True)


def welcome_pdf(pdf_path: Path, logo: Path) -> None:
    pdf = BrandedPDF(format="Letter", unit="mm")
    pdf.product = PRODUCT
    pdf.doc_title = "Welcome"
    pdf.logo_path = logo if logo.is_file() else None
    pdf.set_auto_page_break(auto=False)
    pdf.add_page()

    pdf.set_fill_color(*SLATE_950)
    pdf.rect(0, 0, pdf.w, pdf.h, style="F")
    pdf.set_fill_color(*ORANGE)
    pdf.rect(0, 0, pdf.w, 2.5, style="F")

    if logo.is_file():
        pdf.image(str(logo), x=(pdf.w - 70) / 2, y=42, w=70)

    pdf.set_y(118)
    pdf.set_font("Helvetica", "B", 28)
    pdf.set_text_color(*WHITE)
    pdf.cell(0, 12, _safe(PRODUCT), align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font("Helvetica", "", 14)
    pdf.set_text_color(*ORANGE_LIGHT)
    pdf.cell(0, 8, "Kubernetes lifecycle · k3s platform · Desktop UX", align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.ln(6)
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(*SLATE_400)
    pdf.cell(0, 6, _safe(f"Version {VERSION} · docs/pdf/ · zyvor.dev"), align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.ln(14)
    box_w = 150
    box_x = (pdf.w - box_w) / 2
    pdf.set_fill_color(*SLATE_800)
    pdf.set_draw_color(*ORANGE)
    pdf.set_line_width(0.4)
    pdf.rect(box_x, pdf.get_y(), box_w, 58, style="DF")

    y0 = pdf.get_y() + 8
    for n, (label, cmd) in enumerate(WELCOME_STEPS, 1):
        pdf.set_xy(box_x + 10, y0 + (n - 1) * 17)
        pdf.set_font("Helvetica", "B", 10)
        pdf.set_text_color(*ORANGE)
        pdf.cell(12, 6, f"{n}.", new_x=XPos.RIGHT, new_y=YPos.TOP)
        pdf.set_font("Helvetica", "B", 10)
        pdf.set_text_color(*WHITE)
        pdf.cell(28, 6, _safe(label), new_x=XPos.RIGHT, new_y=YPos.TOP)
        pdf.set_font("Courier", "", 7.5)
        pdf.set_text_color(*SLATE_400)
        pdf.cell(0, 6, _safe(cmd[:52]))

    pdf.set_y(pdf.h - 36)
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(*SLATE_400)
    pdf.cell(0, 5, "docs/welcome.html  ·  docs/pdf/WELCOME.pdf", align="C", new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.cell(0, 5, "make docs  ·  zyvor.dev · © 2026", align="C")

    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    pdf.output(str(pdf_path))


def find_chrome() -> str | None:
    for cmd in (
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        "google-chrome",
        "google-chrome-stable",
        "chromium",
        "chromium-browser",
    ):
        if Path(cmd).is_file():
            return cmd
        if shutil.which(cmd):
            return cmd
    return None


def html_to_pdf(html_path: Path, pdf_path: Path) -> bool:
    chrome = find_chrome()
    if not chrome:
        return False
    url = html_path.resolve().as_uri()
    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        chrome,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path.resolve()}",
        url,
    ]
    try:
        subprocess.run(cmd, check=True, capture_output=True, timeout=120)
        return pdf_path.is_file() and pdf_path.stat().st_size > 0
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
        return False


def write_pdf_index(names: list[str]) -> None:
    lines = [
        "hypercluster — printable PDF index",
        f"Version {VERSION}",
        "",
        "  docs/welcome.html     interactive hub",
        "  docs/pdf/WELCOME.pdf  one-page overview",
        "",
        "  Guides:",
    ]
    for name in sorted(names):
        label = name.replace(".pdf", "").replace("-", " ")
        lines.append(f"    {name:<36} {label}")
    lines.extend(["", "  Regenerate: make docs", ""])
    (DOCS / "PDF_INDEX.txt").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    try:
        import fpdf  # noqa: F401
    except ImportError:
        print("ERROR: fpdf2 required — pip install -r requirements-docs.txt", file=sys.stderr)
        return 1

    logo = resolve_logo()
    if logo.is_file():
        (DOCS / "zyvor-logo.png").write_bytes(logo.read_bytes())

    made: list[str] = []

    welcome_out = PDF_DIR / "WELCOME.pdf"
    welcome_pdf(welcome_out, logo)
    made.append("WELCOME.pdf")
    print(f"  pdf: docs/pdf/WELCOME.pdf")

    sources: list[tuple[Path, str]] = [
        (DOCS / "agents" / "training.md", "AGENT-TRAINING.pdf"),
        (DOCS / "guides" / "desktop-ux-guide.md", "DESKTOP-UX-GUIDE.pdf"),
        (DOCS / "guides" / "cli" / "hypercluster-guide.md", "CLI-GUIDE.pdf"),
        (DOCS / "_build" / "cli-reference.txt", "CLI-REFERENCE.pdf"),
        (DOCS / "generated" / "CONFIG-REFERENCE.md", "CONFIG-REFERENCE.pdf"),
    ]

    for src, pdf_name in sources:
        if not src.is_file():
            print(f"  skip: {src.name} (missing — run make docs first)", file=sys.stderr)
            continue
        out = PDF_DIR / pdf_name
        if src.suffix == ".md":
            md_file_to_pdf(src, out, logo)
        else:
            txt_to_pdf(src, out, logo if logo.is_file() else Path("/dev/null"), PRODUCT)
        made.append(pdf_name)
        print(f"  pdf: docs/pdf/{pdf_name}")

    chrome = find_chrome()
    if chrome:
        for html in sorted((DOCS / "client-presentations").glob("*.html")):
            pdf_name = html.stem + ".pdf"
            out = PDF_DIR / pdf_name
            if html_to_pdf(html, out):
                made.append(pdf_name)
                print(f"  pdf: docs/pdf/{pdf_name}")
            else:
                print(f"  warn: failed HTML→PDF {html.name}", file=sys.stderr)
    else:
        print("  note: Chrome/Chromium not found — skipping presentation PDFs", file=sys.stderr)

    write_pdf_index(made)
    print(f"  index: docs/PDF_INDEX.txt ({len(made)} PDFs)")
    return 0 if len(made) >= 2 else 1


if __name__ == "__main__":
    raise SystemExit(main())
