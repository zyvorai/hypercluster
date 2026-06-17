#!/usr/bin/env python3
"""Email Zyvor platform architecture PDF bundle via Zoho SMTP (contact-mailer.env)."""
from __future__ import annotations

import argparse
import mimetypes
import smtplib
import ssl
import sys
import zipfile
from datetime import datetime, timezone
from email import encoders
from email.mime.base import MIMEBase
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PDF_DIR = ROOT / "docs" / "pdf"
DEFAULT_ENV = ROOT.parent / "hypersdk-web" / "contact-mailer.env"

PLATFORM_PDFS = [
    "PLATFORM-ARCHITECTURE.pdf",
    "06-platform-overview.pdf",
    "07-platform-layer-model.pdf",
    "08-platform-foundation.pdf",
    "09-platform-cloud-apps.pdf",
    "10-platform-migration.pdf",
    "11-platform-intelligence.pdf",
    "12-platform-integration.pdf",
    "13-platform-deployment.pdf",
    "14-platform-architecture-detail.pdf",
]


def load_env(path: Path) -> dict[str, str]:
    env: dict[str, str] = {}
    if not path.is_file():
        raise FileNotFoundError(f"SMTP env file not found: {path}")
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        env[key.strip()] = val.strip()
    return env


def attach_file(msg: MIMEMultipart, path: Path) -> None:
    ctype, _ = mimetypes.guess_type(str(path))
    if ctype is None:
        ctype = "application/octet-stream"
    maintype, subtype = ctype.split("/", 1)
    part = MIMEBase(maintype, subtype)
    part.set_payload(path.read_bytes())
    encoders.encode_base64(part)
    part.add_header("Content-Disposition", f'attachment; filename="{path.name}"')
    msg.attach(part)


def build_zip(paths: list[Path], out: Path) -> Path:
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for p in paths:
            zf.write(p, arcname=p.name)
    return out


def send_mail(
    env: dict[str, str],
    to_addrs: list[str],
    cc_addrs: list[str],
    subject: str,
    body: str,
    attachments: list[Path],
) -> None:
    host = env.get("SMTP_HOST", "")
    port = int(env.get("SMTP_PORT", "587"))
    user = env.get("SMTP_USERNAME", "")
    password = env.get("SMTP_PASSWORD", "")
    from_addr = env.get("SMTP_FROM", user)
    use_tls = env.get("SMTP_USE_TLS", "true").lower() not in ("0", "false", "no")

    if not all([host, user, password, from_addr]):
        raise RuntimeError("Incomplete SMTP configuration in contact-mailer.env")

    msg = MIMEMultipart()
    msg["From"] = from_addr
    msg["To"] = ", ".join(to_addrs)
    if cc_addrs:
        msg["Cc"] = ", ".join(cc_addrs)
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain", "utf-8"))

    for path in attachments:
        attach_file(msg, path)

    recipients = to_addrs + cc_addrs
    context = ssl.create_default_context()

    if use_tls and port == 465:
        with smtplib.SMTP_SSL(host, port, context=context, timeout=120) as smtp:
            smtp.login(user, password)
            smtp.sendmail(from_addr, recipients, msg.as_string())
    else:
        with smtplib.SMTP(host, port, timeout=120) as smtp:
            smtp.ehlo()
            if use_tls:
                smtp.starttls(context=context)
                smtp.ehlo()
            smtp.login(user, password)
            smtp.sendmail(from_addr, recipients, msg.as_string())


def main() -> int:
    parser = argparse.ArgumentParser(description="Mail Zyvor platform architecture PDFs")
    parser.add_argument("--to", default="sibu@zyvor.dev")
    parser.add_argument("--cc", default="ssahani@zyvor.dev")
    parser.add_argument("--env", type=Path, default=DEFAULT_ENV)
    parser.add_argument("--zip-only", action="store_true", help="Only create zip bundle, do not send")
    args = parser.parse_args()

    pdfs = [PDF_DIR / name for name in PLATFORM_PDFS]
    missing = [p.name for p in pdfs if not p.is_file()]
    if missing:
        print("ERROR: missing PDFs (run make docs first):", ", ".join(missing), file=sys.stderr)
        return 1

    ts = datetime.now(timezone.utc).strftime("%Y%m%d")
    zip_path = PDF_DIR / f"zyvor-platform-architecture-{ts}.zip"
    build_zip(pdfs, zip_path)
    print(f"  zip: {zip_path} ({zip_path.stat().st_size // 1024} KB)")

    if args.zip_only:
        return 0

    env = load_env(args.env)
    subject = f"[Zyvor Platform] Architecture PDF bundle — {ts}"
    body = f"""Hello,

Please find attached the Zyvor Platform architecture documentation bundle:

- PLATFORM-ARCHITECTURE.pdf — full printable reference
- 06–13 platform client decks (overview, layers, foundation, cloud, migration, intelligence, integration, deployment)
- 14-platform-architecture-detail.pdf — per-product deep dive (14 products)
- zyvor-platform-architecture-{ts}.zip — all PDFs in one archive

Source: github.com/ssahani/hypercluster · docs/PLATFORM_ARCHITECTURE.md
Generated: {datetime.now(timezone.utc).isoformat()}

Regenerate locally: cd hypercluster && make docs

— Zyvor Platform docs automation
"""

    to_addrs = [a.strip() for a in args.to.split(",") if a.strip()]
    cc_addrs = [a.strip() for a in args.cc.split(",") if a.strip()]

    send_mail(
        env,
        to_addrs=to_addrs,
        cc_addrs=cc_addrs,
        subject=subject,
        body=body,
        attachments=pdfs + [zip_path],
    )
    print(f"  sent: {', '.join(to_addrs)} (cc: {', '.join(cc_addrs)})")
    print(f"  attachments: {len(pdfs) + 1} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
