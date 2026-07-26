# HyperCluster — Kubernetes Cluster Lifecycle

Deploy and upgrade production Kubernetes clusters with Kubespray — preflight, deploy, scale, upgrade, and kubeconfig delivery from one config file. No cloud provider. No special agents.

All cluster operations run over SSH. No daemons, no persistent agents, no mandatory cloud accounts.

**→ [Download HyperCluster 0.1.0](https://github.com/hypersdk/hypercluster/releases/latest)** · `brew install --cask hypersdk/tap/hypercluster` · **[Book a demo](https://zyvor.dev/contact)**

## What is HyperCluster?

Kubernetes bring-up with Kubespray is powerful but raw — inventory files, group_vars, Ansible configuration, and kubeconfig retrieval all require manual wiring. HyperCluster wraps the full Kubespray lifecycle behind a single `cluster.conf`:

```
cluster.conf  →  hypercluster  →  Kubespray (Ansible)  →  nodes via SSH
                                  │
                                  ├─ pinned Kubespray v2.30
                                  ├─ generates hosts.yaml + group_vars
                                  ├─ cluster.yml · scale.yml · upgrade_cluster.yml
                                  └─ fetches kubeconfig to your laptop
```

**HyperCluster Desktop** — a native macOS app (Apple Silicon) — adds a visual cluster studio on top of the same engine: cluster create wizard, node topology canvas, live health view, AI-assisted preflight insights, and one-click kubeconfig delivery.

## At a Glance

| Area | Detail |
|------|--------|
| **Engine** | Kubespray v2.30 (Ansible) |
| **Kubernetes** | v1.32 (pinned) |
| **Runtime** | Podman (default) · containerd · Docker |
| **CNI** | Calico · Cilium · Flannel · kube-ovn |
| **CLI commands** | 12 — preflight, deploy, scale, upgrade, destroy, kubeconfig, health |
| **Day-2** | Scale workers, rolling upgrade, graceful node removal, destroy |
| **Desktop** | macOS 13 Ventura+ · Apple Silicon (M1+) · 30-day free trial |

## Requirements

| Requirement | Details |
|-------------|---------|
| **macOS** | 13 Ventura or later · Apple Silicon (M1+) |
| **Cluster nodes** | Linux nodes reachable over SSH (bare metal, VMs, or cloud instances) |
| **SSH key** | Passwordless SSH access from your Mac to each node |
| **Internet** | Required during cluster deploy (Kubernetes images pulled to nodes) |
| **Disk space** | ~50 MB installed |

No Python, Ansible, or Homebrew required on your Mac — HyperCluster bundles everything it needs.

## Install

### Option A — Homebrew Cask (recommended)

```bash
brew install --cask hypersdk/tap/hypercluster
```

This downloads the PKG, installs `Hypercluster.app` to `/Applications`, and keeps it updated with `brew upgrade --cask hypercluster`.

### Option B — PKG installer

1. Download `Hypercluster-0.1.0.pkg` from the [GitHub Releases](https://github.com/hypersdk/hypercluster/releases/latest) page
2. Double-click the `.pkg` file
3. Click **Continue → Agree → Install**
4. Enter your Mac password when prompted
5. HyperCluster is installed to `/Applications/Hypercluster.app`

### First launch — Gatekeeper prompt

On first open, macOS may show *"Hypercluster cannot be opened because Apple cannot check it for malicious software."*

To allow it:
1. Go to **System Settings → Privacy & Security**
2. Scroll down to the Security section
3. Click **"Open Anyway"** next to the Hypercluster message
4. Click **Open** in the confirmation dialog

This only needs to be done once.

### Trial period

HyperCluster starts a **30-day free trial** at installation time. All features are fully available during the trial.

After 30 days, contact [sales@zyvor.dev](mailto:sales@zyvor.dev) for a licence key. Per-seat and team plans for platform and infrastructure teams.

## Quick Start

### Desktop app

1. Open **Hypercluster.app** from Applications or Spotlight (`⌘Space → Hypercluster`)
2. Click **New Cluster** — the wizard guides you through node IPs, SSH user, CNI, and runtime
3. Click **Preflight** — validates SSH access, Ansible, Python modules, and connectivity
4. Click **Deploy** — runs Kubespray cluster.yml over SSH
5. Click **Kubeconfig** — fetches `admin.conf` to `~/.kube/config`

### CLI

The CLI is bundled inside the app. Access it via the Desktop Terminal panel or add it to your PATH:

```bash
hypercluster preflight   # validate SSH, Ansible, Python, connectivity
hypercluster deploy      # run Kubespray cluster.yml
hypercluster kubeconfig  # fetch admin.conf to ~/.kube/config
hypercluster health      # cluster health summary
hypercluster scale       # add/remove worker nodes
hypercluster upgrade     # rolling Kubernetes version upgrade
hypercluster destroy     # tear down the cluster
```

## Configuration

All settings live in a single `cluster.conf`:

```ini
# Node IPs (comma-separated)
CONTROL_PLANE_IPS=10.0.0.10,10.0.0.11,10.0.0.12
WORKER_IPS=10.0.0.20,10.0.0.21,10.0.0.22

# SSH
SSH_USER=ubuntu
SSH_KEY=~/.ssh/id_rsa

# Kubernetes
K8S_VERSION=v1.32.0
CNI=cilium
CONTAINER_RUNTIME=podman

# Networking (ensure no overlap with node subnets)
KUBE_PODS_SUBNET=10.233.64.0/18
KUBE_SERVICE_ADDRESSES=10.233.0.0/18
```

The Desktop app generates and edits `cluster.conf` visually — manual editing is optional.

## CNI Options

| CNI | When to choose |
|-----|---------------|
| **Cilium** | eBPF-native networking; recommended with PacketWolf for policy-heavy KubeVirt workloads |
| **Calico** | Proven BGP-capable option for production bare metal |
| **Flannel** | Simple overlay; good for lab and single-site clusters |
| **kube-ovn** | SDN overlay for multi-tenant or OpenStack-adjacent deployments |

## Suite Integration

HyperCluster is the cluster substrate for the full Zyvor product suite:

```
Export → Convert → Inspect → HyperCluster (K8s) → Deploy VMs → Manage → Observe
```

| Product | Role after HyperCluster |
|---------|------------------------|
| [Zeus OS](https://zyvor.dev/zeus-os) | KubeVirt control plane on the cluster |
| [Veyron](https://zyvor.dev/veyron) | KubeVirt VM command center |
| [PacketWolf](https://zyvor.dev/packetwolf) | Kernel-native network intelligence |
| [Forge](https://zyvor.dev/forge) | AI infrastructure on Kubernetes |
| [IronWolf](https://zyvor.dev/ironwolf) | Metal3 bare-metal automation |

## Security

| Property | Guarantee |
|----------|-----------|
| Node access | SSH only — no persistent agent installed on nodes |
| Credentials | SSH keys stay on your Mac; no key material sent off-device |
| kubeconfig | Fetched directly to `~/.kube/config` over SSH |
| Telemetry | Zero analytics, no update checks, no outbound calls from the app |

## Uninstall

### Quick uninstall (app only)

```bash
sudo rm -rf /Applications/Hypercluster.app
sudo pkgutil --forget com.zyvor.hypercluster
```

### Full uninstall (app + all data)

Double-click `Uninstall-Hypercluster.command` (in the distribution folder), or run:

```bash
sudo rm -rf /Applications/Hypercluster.app
rm -rf "$HOME/Library/Application Support/com.zyvor.hypercluster"
rm -f "$HOME/Library/Preferences/com.zyvor.hypercluster.plist"
sudo pkgutil --forget com.zyvor.hypercluster
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| **0.1.0** | 2026-06 | Initial release — Desktop app, CLI, Kubespray v2.30, K8s v1.32, 4 CNI, AI preflight insights |

## Links

- **Product page:** [zyvor.dev/hypercluster](https://zyvor.dev/hypercluster)
- **Documentation:** [zyvor.dev/docs/hypercluster](https://zyvor.dev/docs/hypercluster)
- **Feedback / issues:** [github.com/hypersdk/hypercluster/issues](https://github.com/hypersdk/hypercluster/issues)
- **Licence enquiry:** [sales@zyvor.dev](mailto:sales@zyvor.dev)
- **Demo:** [zyvor.dev/contact](https://zyvor.dev/contact)

## License

Proprietary — Zyvor / HyperCluster. All rights reserved.

## Customer manual

**[Customer manual (page-by-page)](docs/customer/README.md)**
