#!/usr/bin/env python3
"""Generate 14-platform-architecture-detail.html — per-product deep dive client deck."""
from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location(
    "gen_platform", ROOT / "scripts" / "generate-platform-presentations.py"
)
mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(mod)

PRODUCT_DETAILS = [
    (
        "hypercluster",
        "Day 0 Kubernetes bootstrap — Kubespray + k3s over SSH",
        [
            "Single cluster.conf — deploy, scale, upgrade, destroy, kubeconfig",
            "k3s path: Cilium → cert-manager → MetalLB → KubeVirt/CDI",
            "forge-handoff --json for Day 2 Forge federation import",
            "Electron Desktop — Cluster Studio + Liquid Glass UI",
        ],
        [
            "Entry: hypercluster bash CLI, lib/k3s.sh, lib/kubespray helpers",
            "Commands: preflight, deploy, test, health --json, merge-kubeconfig",
            "Desktop: desktop/ Electron app spawns CLI for lifecycle ops",
        ],
    ),
    (
        "machina",
        "Enterprise libvirt/KVM hypervisor management — physical layer",
        [
            "machina-daemon HTTPS :5092 — PAM auth, RBAC, console proxies",
            "Web UI 40+ pages — noVNC, SPICE, serial, SSH consoles",
            "Fleet controller + per-host agent for multi-node libvirt",
            "Prometheus endpoint, alerts, webhooks, backup/restore",
        ],
        [
            "Rust workspace: daemon/, core/, web/, tui/, controller/, agent/",
            "CLI: machinactl deploy · verify · health · backup",
            "Integrations: OpenStack, Guacamole, KubeVirt migration path",
        ],
    ),
    (
        "zyvor-fabric",
        "systemd-native private cloud — alternative to libvirt stack",
        [
            "vmspawnd daemon :8443 — 480+ REST endpoints",
            "vmctl apply declarative YAML VM specs",
            "5 interfaces: CLI, TUI, Web, K8s Operator, Terraform",
            "GPU passthrough, HA, replication modules",
        ],
        [
            "backend/vmspawnd/, vmspawn-driver/, machinectl-driver/",
            "Runtime: systemd-vmspawn + systemd-machined + KVM",
            "integrations/machina/ cross-product desktop client",
        ],
    ),
    (
        "IronWolf",
        "Metal3 bare-metal automation — 24 CRDs (bmo.metal3.io)",
        [
            "ClusterClaim hardware allocation — binpack/spread/topology",
            "FirmwareProfile + HardwareBackup fleet lifecycle",
            "BMC Reconciler — IPMI/Redfish/iLO/iDRAC",
            "Dashboard :8888 — real-time BMC + host events",
        ],
        [
            "Go controller-runtime, config/crd/, web/dashboard/",
            "terraform-provider-ironwolf/, scripts/quickstart.sh",
            "Feeds bare metal into hypercluster and Aether Metal3 runtime",
        ],
    ),
    (
        "v9s · Zeus OS",
        "Visual operating system for KubeVirt and enterprise K8s",
        [
            "Web dashboard :5050 + TUI with 48+ specialized views",
            "VM lifecycle, hot-plug, live migration, cost visibility",
            "OIDC/LDAP/SAML, tenants, audit, scoped API tokens",
            "Topology/RCA hooks, Velero integration",
        ],
        [
            "Rust workspace: core/, tui/, ui/, cli/, chart/",
            "kube-rs → KubeVirt VirtualMachine/VMI CRs",
            "Hosts Hermes application layer on Zeus OS clusters",
        ],
    ),
    (
        "VMRogue · Veyron",
        "KubeVirt command center — GitOps CRDs and Mission Control",
        [
            "VeyronVM + VeyronPolicy CEL deny rules",
            "44 OS templates, 8 resource profiles, blueprint engine",
            "Direct K8s VNC WebSocket — no virtctl timeout",
            "GuestKit pre-flight + PacketWolf network context",
        ],
        [
            "Rust veyron binary :8080, Go operator/, charts/veyron/",
            "src/kube/guestkit_client.rs, src/gitops/, terraform-provider-vmrogue/",
        ],
    ),
    (
        "ragnarok",
        "AI-powered VM management — NL provisioning and cost optimizer",
        [
            "Natural language VM creation to KubeVirt specs",
            "AI healer — autonomous incident detection/remediation",
            "PostgreSQL-backed ops, Playwright E2E",
            "Optional Aether attestation via RAGNAROK_URL",
        ],
        [
            "backend/ Rust Axum, frontend/ React, operator/, charts/ragnarok/",
            "docs/AI_NL.md, docs/ARCHITECTURE.md",
        ],
    ),
    (
        "hermes",
        "Application Operating Layer — Launchpad for Kubernetes apps",
        [
            "Auto-discover Services cluster-wide + EndpointSlice health",
            "Gateway /a/{namespace}/{slug}/* reverse proxy + WebSocket",
            "Recognition: Grafana, Argo CD, Harbor, Zeus, Forge",
            "Favorites, recents, spotlight search — SQLite catalog",
        ],
        [
            "Go controller cmd/hermes-controller/, Rust hermes-server :31847",
            "charts/hermes/ Helm, ui/ React Launchpad",
        ],
    ),
    (
        "hypersdk",
        "Multi-cloud VM export — 10+ hypervisor providers",
        [
            "hypervisord daemon :5080 — 238 REST routes, job queue",
            "Provider adapters: vSphere, Nutanix, AWS, Azure, GCP, Hyper-V",
            "Embedded React dashboard with live WebSocket progress",
            "CE vs Enterprise feature split",
        ],
        [
            "cmd/hypervisord/, providers/, daemon/jobs/manager.go",
            "Upstream of hyper2kvm export → convert/deploy pipeline",
        ],
    ),
    (
        "hyper2kvm",
        "Enterprise VM migration — any hypervisor to KVM",
        [
            "VMCraft Python engine — 5–7× faster than shell pipelines",
            "Offline fixers — 35+ OS versions, Windows VirtIO injection",
            "h2kweb Go API :5070 — 110+ endpoints, VNC console",
            "Libvirt → KubeVirt live migration, K8s operator",
        ],
        [
            "hyper2kvm/vmcraft/, fixers/, web/h2kweb/, operator/",
            "Pairs with GuestKit for pre-flight assurance",
        ],
    ),
    (
        "guestkit",
        "Offline VM disk intelligence — zero boot, zero agents",
        [
            "Pure Rust — QCOW2, VMDK, RAW without libguestfs",
            "doctor boot scoring · migrate-plan YAML · fleet analyze",
            "PyO3 bindings hypersdk-guestkit on PyPI",
            "Windows registry + MBR/GPT + ext4/NTFS/XFS detection",
        ],
        [
            "src/disk/, src/core/, k8s/ KubeVirt hooks",
            "Used by Veyron src/kube/guestkit_client.rs",
        ],
    ),
    (
        "Aether",
        "Universal runtime portability — 16 migration paths",
        [
            "One YAML spec → Podman, K8s, KubeVirt, Metal3",
            "Intent engine scores cost, latency, reliability",
            "Blue-green, rolling migration with rollback",
            "Drift detection + auto-reconciliation loop",
        ],
        [
            "src/adapters/, src/migration/, src/drift/, web/ React UI",
            "Helm, deb/rpm, aether serve :8080",
        ],
    ),
    (
        "forge",
        "Kubernetes-native AI infrastructure — 60+ CRDs",
        [
            "API Gateway :24631 · Zeus AI ops :8091 · Intelligence :8090",
            "GPU operator, AI operator, network intelligence, virtualization",
            "24 eBPF programs, 94-page React web-ui, Rust CLI",
            "Closed-loop FinOps, placement, FabricAutoPolicy gates",
        ],
        [
            "services/, operators/, crds/, ebpf/, helm/forge-core/",
            "Consumes PacketWolf; optional hypercluster handoff import",
        ],
    ),
    (
        "packetwolf",
        "Kernel-native network intelligence — requires Cilium",
        [
            "netpred explain — cross-layer root cause analysis",
            "AutoPolicy: traffic learning → Cilium NetworkPolicy",
            "Autonomous Healer + process-to-socket attribution",
            "71K LOC Rust, 130+ REST routes, 18-tab TUI :8443",
        ],
        [
            "src/modules/, netpred-ebpf/, web-api/, chart/",
            "Intelligence plane for Forge and Veyron handlers",
        ],
    ),
]


def main() -> int:
    mod.OUT.mkdir(parents=True, exist_ok=True)
    product_pages = ""
    for title, subtitle, bullets, tech in PRODUCT_DETAILS:
        product_pages += f"""
<div class="page page-dark">
  <h2>{title}</h2>
  <p class="sub">{subtitle}</p>
  {mod.li(bullets)}
  <h3>Stack &amp; entry points</h3>
  {mod.li(tech)}
  <div class="footer">Zyvor Platform · detailed architecture</div>
</div>"""

    mod.deck(
        "14-platform-architecture-detail.html",
        "Platform architecture — detailed",
        "Complete per-product deep dive — ssahani portfolio",
        f"""
<div class="page page-accent">
  <h2>Detailed architecture reference</h2>
  <p class="sub">Companion to PLATFORM_ARCHITECTURE.md — one page per product with stack, capabilities, and integration notes.</p>
  {mod.stats([
      ("19", "products documented"),
      ("821", "lines in ARCH doc"),
      ("21", "printable PDFs"),
      ("14", "product deep dives"),
  ])}
  {mod.table(["Section", "Deck PDF"], [
      ("Executive summary", "06-platform-overview.pdf"),
      ("Layer model", "07-platform-layer-model.pdf"),
      ("Foundation", "08-platform-foundation.pdf"),
      ("Cloud & apps", "09-platform-cloud-apps.pdf"),
      ("Migration", "10-platform-migration.pdf"),
      ("Intelligence", "11-platform-intelligence.pdf"),
      ("Integration", "12-platform-integration.pdf"),
      ("Deployment", "13-platform-deployment.pdf"),
      ("Per-product detail", "14-platform-architecture-detail.pdf"),
      ("Full reference", "PLATFORM-ARCHITECTURE.pdf"),
  ])}
  <div class="footer">hypercluster/docs/pdf/ · zyvor.dev</div>
</div>
{product_pages}
<div class="page page-light">
  <h2>GitHub repository map</h2>
  {mod.table(["Local folder", "GitHub repo"], [
      ("Aether", "ssahani/Aether"),
      ("forge", "ssahani/forge"),
      ("guestkit", "hypersdk/guestkit"),
      ("hermes", "ssahani/hermes"),
      ("hyper2kvm-", "ssahani/hyper2kvm-"),
      ("hypercluster", "ssahani/hypercluster"),
      ("hypersdk-", "ssahani/hypersdk-"),
      ("IronWolf", "ssahani/IronWolf"),
      ("machina", "ssahani/machina"),
      ("packetwolf", "ssahani/packetwolf"),
      ("ragnarok", "ssahani/ragnarok"),
      ("v9s", "ssahani/zeus-os"),
      ("VMRogue", "ssahani/Veyron"),
      ("zyvor-fabric", "ssahani/zyvor-fabric"),
  ])}
  <div class="cta"><h3>Questions or demo?</h3><p>sibu@zyvor.dev · ssahani@zyvor.dev · zyvor.dev/contact</p></div>
  <div class="footer">Generated June 2026 · Zyvor AI Labs</div>
</div>""",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
