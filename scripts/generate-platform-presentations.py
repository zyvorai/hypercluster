#!/usr/bin/env python3
"""Generate Zyvor platform architecture client presentation HTML decks (hyper2kvm format)."""
from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "client-presentations"
VERSION = (ROOT / "VERSION").read_text().strip() if (ROOT / "VERSION").is_file() else "0.1.0"

CSS = """
  @page { size: A4; margin: 0; }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; color: #1a1a2e; background: #fff; line-height: 1.6; }

  .cover { height: 100vh; background: linear-gradient(135deg, #0f0c29, #302b63, #24243e); color: #fff; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; page-break-after: always; position: relative; overflow: hidden; }
  .cover::before { content: ''; position: absolute; inset: -50%; background: radial-gradient(circle at 30% 50%, rgba(255,143,63,0.15) 0%, transparent 50%), radial-gradient(circle at 70% 80%, rgba(99,102,241,0.1) 0%, transparent 50%); }
  .cover h1 { font-size: 3.1em; font-weight: 800; letter-spacing: -1px; position: relative; }
  .cover h1 span { color: #ff8f3f; }
  .cover h2 { font-size: 1.25em; font-weight: 300; opacity: 0.9; margin: 1em 0; max-width: 640px; position: relative; }
  .cover .badge { display: inline-block; background: rgba(255,143,63,0.2); border: 1px solid rgba(255,143,63,0.4); padding: 8px 20px; border-radius: 20px; font-size: 0.88em; margin-top: 1.5em; position: relative; }

  .page { min-height: 100vh; padding: 56px 72px; page-break-after: always; position: relative; }
  .page-dark { background: #0f111a; color: #e8e6df; }
  .page-light { background: #fafbfc; color: #1a1a2e; }
  .page-accent { background: linear-gradient(135deg, #1a1a2e, #16213e); color: #e8e6df; }

  h2 { font-size: 1.85em; font-weight: 700; margin-bottom: 0.55em; color: #ff8f3f; }
  h3 { font-size: 1.1em; font-weight: 600; margin: 1em 0 0.4em; color: #ffb380; }
  .page-light h3 { color: #c2410c; }
  p.sub { opacity: 0.75; margin-bottom: 1.2em; font-size: 0.98em; }

  ul { margin: 0.5em 0 0.8em 1.35em; }
  li { margin-bottom: 0.42em; font-size: 0.95em; }
  code { background: rgba(255,255,255,0.08); padding: 2px 6px; border-radius: 4px; font-size: 0.88em; }
  .page-light code { background: #eef2ff; color: #1e293b; }

  .card-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 18px; margin: 1.2em 0; }
  .card { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.1); border-radius: 12px; padding: 20px; }
  .page-light .card { background: #fff; border: 1px solid #e5e7eb; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
  .card h4 { font-size: 1em; font-weight: 600; margin-bottom: 6px; color: #ff8f3f; }
  .page-light .card h4 { color: #ea580c; }
  .card p { font-size: 0.9em; opacity: 0.88; }

  .stat-row { display: flex; gap: 14px; margin: 1.2em 0; flex-wrap: wrap; }
  .stat { flex: 1; min-width: 110px; text-align: center; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12); border-radius: 10px; padding: 16px 8px; }
  .page-light .stat { background: #fff; border: 1px solid #e5e7eb; }
  .stat .n { font-size: 2em; font-weight: 800; color: #ff8f3f; line-height: 1; }
  .page-light .stat .n { color: #ea580c; }
  .stat .l { font-size: 0.78em; opacity: 0.72; margin-top: 6px; line-height: 1.3; }

  table { width: 100%; border-collapse: collapse; margin: 1em 0; font-size: 0.88em; }
  th { background: #ff8f3f; color: #fff; padding: 10px 14px; text-align: left; font-weight: 600; }
  td { padding: 9px 14px; border-bottom: 1px solid rgba(255,255,255,0.1); vertical-align: top; }
  .page-light td { border-bottom: 1px solid #e5e7eb; }
  .page-light tr:nth-child(even) td { background: #f9fafb; }

  .flow { display: flex; align-items: center; justify-content: center; gap: 6px; margin: 1em 0; flex-wrap: wrap; }
  .flow-step { background: rgba(255,143,63,0.15); border: 1px solid rgba(255,143,63,0.35); padding: 8px 14px; border-radius: 8px; font-weight: 600; font-size: 0.82em; text-align: center; }
  .flow-arrow { font-size: 1.2em; color: #ff8f3f; }

  .cta { background: linear-gradient(135deg, #ff8f3f, #e67a30); color: #fff; padding: 28px; border-radius: 12px; text-align: center; margin-top: 1.5em; }
  .cta h3 { color: #fff; margin-bottom: 0.3em; }
  .footer { position: absolute; bottom: 28px; left: 72px; right: 72px; text-align: center; font-size: 0.76em; opacity: 0.45; }
"""


def li(items: list[str]) -> str:
    return "<ul>" + "".join(f"<li>{i}</li>" for i in items) + "</ul>"


def cards(pairs: list[tuple[str, str]]) -> str:
    return '<div class="card-grid">' + "".join(
        f'<div class="card"><h4>{t}</h4><p>{b}</p></div>' for t, b in pairs
    ) + "</div>"


def stats(items: list[tuple[str, str]]) -> str:
    return '<div class="stat-row">' + "".join(
        f'<div class="stat"><div class="n">{n}</div><div class="l">{l}</div></div>' for n, l in items
    ) + "</div>"


def table(headers: list[str], rows: list[tuple[str, ...]]) -> str:
    th = "".join(f"<th>{h}</th>" for h in headers)
    body = ""
    for row in rows:
        cells = "".join(f"<td>{('<strong>' + c + '</strong>' if i == 0 else c)}</td>" for i, c in enumerate(row))
        body += f"<tr>{cells}</tr>"
    return f"<table><thead><tr>{th}</tr></thead><tbody>{body}</tbody></table>"


def flow(steps: list[str]) -> str:
    parts = []
    for i, s in enumerate(steps):
        if i:
            parts.append('<span class="flow-arrow">→</span>')
        parts.append(f'<span class="flow-step">{s}</span>')
    return f'<div class="flow">{"".join(parts)}</div>'


def deck(filename: str, title: str, subtitle: str, body: str) -> None:
    html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="UTF-8"><title>{title}</title><style>{CSS}</style></head>
<body>
<div class="cover">
  <h1>Zyvor <span>Platform</span></h1>
  <h2>{subtitle}</h2>
  <div class="badge">hypercluster v{VERSION} · zyvor.dev · ssahani portfolio</div>
</div>
{body}
</body></html>"""
    (OUT / filename).write_text(html, encoding="utf-8")
    print(f"  wrote docs/client-presentations/{filename}")


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    deck(
        "06-platform-overview.html",
        "Platform overview",
        "Executive summary — modular enterprise infrastructure stack",
        f"""
<div class="page page-dark">
  <h2>Executive summary</h2>
  <p class="sub">The Zyvor platform is a vertically integrated stack for enterprise infrastructure — bare metal through Kubernetes, KubeVirt VMs, AI/GPU workloads, and VM migration.</p>
  {stats([
      ("19", "portfolio products"),
      ("6", "architecture layers"),
      ("16", "Aether migration paths"),
      ("60+", "Forge CRDs"),
  ])}
  {cards([
      ("Composable", "Each repo owns a domain — hypercluster bootstraps; Forge/Hermes/Zeus install into the cluster."),
      ("Offline-first migration", "GuestKit + hyper2kvm fix guests before boot on KVM."),
      ("Kubernetes-native", "Operators, CRDs, Helm charts; systemd for bare-metal daemons."),
      ("AI as embedded ops", "Forge Zeus, Ragnarok healer, Veyron copilot — not bolt-on chatbots."),
  ])}
  <div class="footer">Zyvor Platform · docs/PLATFORM_ARCHITECTURE.md</div>
</div>
<div class="page page-light">
  <h2>Design philosophy</h2>
  {table(["Principle", "Implementation"], [
      ("Composable", "hypercluster bootstraps; sibling products install into cluster"),
      ("One owner per domain", "Migration = hyper2kvm; disk inspect = guestkit; network = packetwolf"),
      ("K8s-native", "Operators, CRDs, Helm; systemd for host daemons"),
      ("Offline migration", "GuestKit + hyper2kvm pre-boot guest fixes"),
  ])}
  <div class="footer">zyvor.dev · HyperSDK Platform Suite</div>
</div>""",
    )

    deck(
        "07-platform-layer-model.html",
        "Layer model",
        "Bottom-up dependency stack — foundation to intelligence",
        f"""
<div class="page page-dark">
  <h2>Layer model</h2>
  <p class="sub">Lower layers provide compute, storage, and networking; upper layers add orchestration, UX, and intelligence.</p>
  {flow(["Physical", "Bootstrap", "Cloud", "AI", "Apps", "Migration", "Network"])}
  {table(["Layer", "Products", "Runtime"], [
      ("0 — Physical", "machina · zyvor-fabric · IronWolf", "Linux host, systemd"),
      ("1 — Bootstrap", "hypercluster", "Ansible, k3s, SSH"),
      ("2 — Cloud control", "v9s · VMRogue · ragnarok", "In-cluster + sidecar APIs"),
      ("3 — AI infra", "forge", "K8s operators + microservices"),
      ("4 — Applications", "hermes", "K8s controller + Rust gateway"),
      ("5 — Migration", "hypersdk · hyper2kvm · guestkit · Aether", "Host daemon + CLI"),
      ("6 — Network intel", "packetwolf", "DaemonSet + host CLI"),
  ])}
  <div class="footer">Layer 0 → Layer 6 dependency flow</div>
</div>
<div class="page page-accent">
  <h2>Key abstractions</h2>
  {cards([
      ("Unified Workload Spec", "Aether — one YAML across Podman, K8s, KubeVirt, Metal3"),
      ("VeyronVM CR", "VMRogue — declarative VM with GitOps export"),
      ("ClusterClaim", "IronWolf — bare-metal allocation with topology scheduling"),
      ("Application Gateway", "Hermes — /a/{{ns}}/{{app}} stable URLs"),
  ])}
  <div class="footer">Cross-layer integration via kubeconfig handoffs and REST APIs</div>
</div>""",
    )

    deck(
        "08-platform-foundation.html",
        "Foundation layer",
        "Physical hypervisors, metal provisioning, and cluster bootstrap",
        f"""
<div class="page page-dark">
  <h2>Foundation products</h2>
  {table(["Product", "Role", "Port"], [
      ("hypercluster", "Day 0 K8s bootstrap — Kubespray + k3s", "CLI"),
      ("machina", "libvirt/KVM hypervisor management", ":5092"),
      ("zyvor-fabric", "systemd-vmspawn private cloud", ":8443"),
      ("IronWolf", "Metal3 bare-metal automation (24 CRDs)", ":8888"),
  ])}
  <h3>hypercluster workflow</h3>
  {li([
      "<code>cluster.conf</code> → preflight → deploy → test → kubeconfig",
      "k3s path: Cilium → cert-manager → MetalLB → KubeVirt/CDI",
      "<code>forge-handoff --json</code> for Day 2 Forge import",
  ])}
  <div class="footer">Day 0 always starts with hypercluster for Kubernetes</div>
</div>
<div class="page page-light">
  <h2>Physical layer choice</h2>
  {cards([
      ("machina", "Enterprise libvirt/QEMU/KVM — 40+ web pages, fleet controller, VNC/SPICE consoles."),
      ("zyvor-fabric", "systemd-native alternative — vmspawnd daemon, vmctl apply YAML, 480+ REST endpoints."),
      ("IronWolf", "Metal3 extension — firmware profiles, BMC reconciler, ClusterClaim scheduling."),
  ])}
  <h3>When to use which</h3>
  {li([
      "libvirt-centric ops → machina",
      "systemd-native lightweight cloud → zyvor-fabric",
      "Bare-metal fleet with BMC → IronWolf → hypercluster",
  ])}
  <div class="footer">Physical layer under Zeus OS cloud control</div>
</div>""",
    )

    deck(
        "09-platform-cloud-apps.html",
        "Cloud & application layer",
        "KubeVirt command centers and Kubernetes application gateway",
        f"""
<div class="page page-dark">
  <h2>Cloud control layer</h2>
  {table(["Product", "GitHub", "Emphasis", "Port"], [
      ("v9s (Zeus OS)", "zeus-os", "Visual OS — 48+ TUI views, enterprise auth", ":5050"),
      ("VMRogue (Veyron)", "Veyron", "GitOps CRDs, templates, Mission Control", ":8080"),
      ("ragnarok", "ragnarok", "AI VM ops, NL provisioning, cost optimizer", "Ingress"),
  ])}
  {cards([
      ("Zeus OS", "Primary cloud command center — OIDC/LDAP/SAML, cost visibility, live consoles."),
      ("Veyron", "VeyronVM operator, 44 OS templates, GuestKit pre-flight, PacketWolf context."),
      ("Ragnarok", "AI healer, NL provisioning, PostgreSQL-backed ops, Velero integration."),
  ])}
  <div class="footer">All require KubeVirt-enabled cluster (hypercluster k3s path)</div>
</div>
<div class="page page-light">
  <h2>Application layer — Hermes</h2>
  <p class="sub">Application Operating Layer — auto-discover apps, stable gateway URLs, Launchpad UX.</p>
  {stats([
      (":31847", "default port"),
      ("Go", "discovery controller"),
      ("Rust", "gateway server"),
      ("SQLite", "app catalog"),
  ])}
  {li([
      "Cluster-wide Service scan + EndpointSlice health",
      "Recognition engine: Grafana, Argo CD, Harbor, Zeus, Forge",
      "Universal gateway: <code>/a/{{namespace}}/{{slug}}/*</code> reverse proxy + WebSocket",
      "Install after hypercluster — application layer atop Zeus OS",
  ])}
  <div class="footer">hermes · Application layer of Zeus OS</div>
</div>""",
    )

    deck(
        "10-platform-migration.html",
        "Migration & portability",
        "Export → inspect → convert → deploy pipeline",
        f"""
<div class="page page-dark">
  <h2>Migration pipeline</h2>
  {flow(["hypersdk export", "guestkit inspect", "hyper2kvm convert", "machina / KubeVirt deploy"])}
  {table(["Product", "Role", "Port"], [
      ("hypersdk", "Multi-cloud VM export — 10+ providers", ":5080"),
      ("hyper2kvm", "VMCraft engine — offline fixers, h2kweb", ":5070"),
      ("guestkit", "Offline disk intelligence — boot scoring", "CLI"),
      ("Aether", "16 runtime-pair portability overlay", ":8080"),
  ])}
  <div class="footer">Offline-first: fix guests before boot on KVM</div>
</div>
<div class="page page-accent">
  <h2>Migration capabilities</h2>
  {cards([
      ("hypersdk", "hypervisord daemon — 238 REST routes, job queue, provider adapters."),
      ("hyper2kvm", "VMCraft Python engine — 35+ OS versions, Windows VirtIO injection."),
      ("guestkit", "Pure Rust disk reader — doctor, migrate-plan, fleet analyze."),
      ("Aether", "Unified YAML spec — Podman, K8s, KubeVirt, Metal3 adapters."),
  ])}
  <h3>Libvirt → KubeVirt</h3>
  {li([
      "hyper2kvm h2kweb: one-click running VM migration to KubeVirt CRs",
      "GuestKit pre-flight before Veyron deploy",
      "Aether blue-green migration with rollback",
  ])}
  <div class="footer">Migration lane pairs with physical and cloud layers</div>
</div>""",
    )

    deck(
        "11-platform-intelligence.html",
        "Intelligence layer",
        "AI infrastructure and kernel-native network observability",
        f"""
<div class="page page-dark">
  <h2>Forge — AI infrastructure</h2>
  {stats([
      ("60+", "CRDs"),
      ("7", "operators"),
      ("24", "eBPF programs"),
      (":24631", "API Gateway"),
  ])}
  {table(["Service", "Port", "Role"], [
      ("API Gateway", "24631", "Auth, tenancy, aggregation"),
      ("Intelligence Engine", "8090", "Closed-loop optimizers"),
      ("Zeus", "8091", "AI ops engineer, multi-LLM agents"),
      ("Model Router", "8094", "LLM routing"),
      ("Embedding Service", "8095", "Vector embeddings"),
  ])}
  <div class="footer">forge · Kubernetes-native AI control plane</div>
</div>
<div class="page page-light">
  <h2>PacketWolf — network intelligence</h2>
  {stats([
      ("71K", "LOC Rust"),
      ("130+", "REST routes"),
      ("15", "intel modules"),
      (":8443", "web UI"),
  ])}
  {li([
      "<code>netpred explain &lt;service&gt;</code> — cross-layer root cause",
      "AutoPolicy: traffic learning → Cilium NetworkPolicy suggestions",
      "Autonomous Healer — network remediation",
      "Requires Cilium; intelligence plane for Forge and Veyron",
  ])}
  <div class="footer">packetwolf · Cilium-powered observability</div>
</div>""",
    )

    deck(
        "12-platform-integration.html",
        "Integration & install order",
        "Cross-product flows and recommended deployment sequence",
        f"""
<div class="page page-dark">
  <h2>Install order</h2>
  {flow(["Metal/Hypervisor", "Migration prep", "hypercluster", "packetwolf · forge · v9s", "hermes · Aether"])}
  {table(["Phase", "Product", "When"], [
      ("0a", "machina / zyvor-fabric / IronWolf", "Bare metal or libvirt hosts not ready"),
      ("0b", "guestkit + hyper2kvm", "VMs moving from VMware/Hyper-V"),
      ("1", "hypercluster", "Always first for K8s"),
      ("2", "packetwolf", "Cilium-enabled cluster"),
      ("3", "forge + v9s/VMRogue/ragnarok", "GPU/AI + KubeVirt ops"),
      ("4", "hermes + Aether", "App layer + portability overlay"),
  ])}
  <div class="footer">See docs/guides/zyvor-platform-stack.md</div>
</div>
<div class="page page-light">
  <h2>Integration matrix</h2>
  {table(["From", "To", "Mechanism"], [
      ("hypercluster", "Forge, Hermes, Zeus", "kubeconfig + forge-handoff JSON"),
      ("hypersdk", "hyper2kvm", "Export → convert/deploy pipeline"),
      ("guestkit", "Veyron", "Pre-flight boot scoring + fix plans"),
      ("packetwolf", "forge", "Intelligence plane network module"),
      ("machina", "v9s", "Physical hypervisor → cloud VM layer"),
      ("Aether", "All runtimes", "Unified deploy/migrate"),
  ])}
  <div class="footer">Composable siblings — no monolith required</div>
</div>""",
    )

    deck(
        "13-platform-deployment.html",
        "Deployment reference",
        "Ports, patterns, security boundaries, and production stack",
        f"""
<div class="page page-dark">
  <h2>Service ports</h2>
  {table(["Product", "Port", "Protocol"], [
      ("v9s (Zeus OS)", "5050", "HTTP"),
      ("hyper2kvm h2kweb", "5070", "HTTPS"),
      ("hypersdk dashboard", "5080", "HTTPS"),
      ("machina daemon", "5092", "HTTPS"),
      ("Veyron / Aether API", "8080", "HTTPS/HTTP"),
      ("Forge API Gateway", "24631", "HTTP"),
      ("Hermes", "31847", "HTTP"),
      ("zyvor-fabric / packetwolf", "8443", "HTTPS"),
      ("IronWolf dashboard", "8888", "HTTP"),
  ])}
  <div class="footer">Default ports — configurable per deployment</div>
</div>
<div class="page page-light">
  <h2>Deployment patterns</h2>
  {cards([
      ("systemd + binary", "Aether, machina, guestkit, hypersdk, zyvor-fabric"),
      ("Helm operator", "Forge, Hermes, IronWolf, Veyron, Ragnarok, PacketWolf"),
      ("Ansible bootstrap", "hypercluster — operator laptop over SSH"),
      ("pip + Go daemon", "hyper2kvm — VMCraft + h2kweb"),
  ])}
  <h3>Recommended production stack</h3>
  {li([
      "IronWolf (metal) → hypercluster (Kubespray HA) → Cilium + KubeVirt/CDI",
      "packetwolf → forge (GPU) → v9s → hermes",
      "hypersdk + guestkit + hyper2kvm (migration lane)",
      "Aether portability overlay (optional)",
  ])}
  <div class="cta"><h3>Full architecture document</h3><p>docs/PLATFORM_ARCHITECTURE.md · zyvor.dev/contact</p></div>
  <div class="footer">© Zyvor AI Labs · ssahani portfolio · June 2026</div>
</div>""",
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
