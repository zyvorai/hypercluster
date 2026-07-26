# HyperCluster — Complete page index

Every primary navigable dashboard route.

_Generated: 2026-07-26 · 32 routes_

Regenerate: `node scripts/customer-docs/generate-page-index.mjs`

## Nav

| Page | Route | Purpose | Guide |
|------|-------|---------|-------|
| Dashboard | `dashboard` | Fleet home for Hypercluster Desktop — registered clusters and deploy shortcuts. | [Open](pages/nav/dashboard.md) |
| Cluster detail | `cluster` | Cluster cockpit — open a selected cluster into overview and day-2 tabs. | [Open](pages/nav/cluster.md) |
| Create Cluster | `studio-hub` | Create Cluster hub — pick Kubernetes, virtualization, AI, or edge intent. | [Open](pages/nav/studio-hub.md) |
| Advanced ops | `operations` | Advanced Day-2 operations against the selected cluster. | [Open](pages/nav/operations.md) |
| Settings | `settings` | Desktop app settings, providers, and trial/license status. | [Open](pages/nav/settings.md) |
| Ask Zeus | `copilot` | Ask Zeus / Copilot overlay for cluster-grounded assistance. | [Open](pages/nav/copilot.md) |

## Create

| Page | Route | Purpose | Guide |
|------|-------|---------|-------|
| Cluster Studio | `studio` | Full Cluster Studio wizard (nodes → storage → network → validate → deploy). | [Open](pages/create/studio.md) |
| Quick Deploy | `quick-deploy` | Opinionated quick path for a standard cluster profile. | [Open](pages/create/quick-deploy.md) |

## Edit

| Page | Route | Purpose | Guide |
|------|-------|---------|-------|
| Conf editor | `editor` | Raw cluster.conf editor with validation. | [Open](pages/edit/editor.md) |

## Ops

| Page | Route | Purpose | Guide |
|------|-------|---------|-------|
| Deploy console | `deploy` | Live deploy console — pipeline logs and stage status. | [Open](pages/ops/deploy.md) |

## Cockpit

| Page | Route | Purpose | Guide |
|------|-------|---------|-------|
| Overview | `cluster/overview` | Cluster overview — health, version, and capacity summary. | [Open](pages/cockpit/cluster-overview.md) |
| Nodes | `cluster/nodes` | Node inventory, SSH status, and scale actions. | [Open](pages/cockpit/cluster-nodes.md) |
| Workloads | `cluster/workloads` | Workloads running on the provisioned cluster. | [Open](pages/cockpit/cluster-workloads.md) |
| Networking | `cluster/network` | CNI / MetalLB / ingress networking status. | [Open](pages/cockpit/cluster-network.md) |
| Storage | `cluster/storage` | Storage classes and CSI status. | [Open](pages/cockpit/cluster-storage.md) |
| Virtual Machines | `cluster/vms` | KubeVirt VMs when virtualization add-ons are installed. | [Open](pages/cockpit/cluster-vms.md) |
| Templates | `cluster/templates` | Cluster / workload templates. | [Open](pages/cockpit/cluster-templates.md) |
| GPU | `cluster/gpu` | GPU node and operator status. | [Open](pages/cockpit/cluster-gpu.md) |
| Platform | `cluster/platform` | Zyvor platform components installed on the cluster. | [Open](pages/cockpit/cluster-platform.md) |
| Instruments | `cluster/instruments` | Instrument / telemetry panels for the cluster. | [Open](pages/cockpit/cluster-instruments.md) |
| Observability | `cluster/observability` | Observability stack status (metrics, logs). | [Open](pages/cockpit/cluster-observability.md) |
| Security | `cluster/security` | Security posture and hardening checklist. | [Open](pages/cockpit/cluster-security.md) |
| Backups | `cluster/backups` | Backup and etcd/snapshot related ops. | [Open](pages/cockpit/cluster-backups.md) |
| Upgrades | `cluster/upgrades` | Upgrade paths for k3s/Kubespray clusters. | [Open](pages/cockpit/cluster-upgrades.md) |
| Cluster Settings | `cluster/settings` | Per-cluster settings and conf linkage. | [Open](pages/cockpit/cluster-settings.md) |

## CLI

| Page | Route | Purpose | Guide |
|------|-------|---------|-------|
| CLI Provisioning | `cli/provision` | CLI deploy / wizard / profiles for bare-metal Kubernetes. | [Open](pages/cli/cli-provision.md) |
| Node Lifecycle | `cli/lifecycle` | Scale, upgrade, destroy, unlock via hypercluster CLI. | [Open](pages/cli/cli-lifecycle.md) |
| SSH & Kubeconfig | `cli/ssh` | SSH, jump hosts, kubeconfig fetch/merge, API tunnels. | [Open](pages/cli/cli-ssh.md) |
| Discovery & Preflight | `cli/discover` | Discovery sources and preflight checks before deploy. | [Open](pages/cli/cli-discover.md) |
| Health & Status | `cli/health` | health / status / test / forge-handoff JSON ops. | [Open](pages/cli/cli-health.md) |
| Lab Mode | `cli/lab` | Lab mode storage/tune/setup helpers. | [Open](pages/cli/cli-lab.md) |
| Zyvor Platform Handoff | `cli/zyvor-handoff` | Hand off a ready cluster to the Zyvor product stack. | [Open](pages/cli/cli-zyvor-handoff.md) |

## Related

- [Customer docs home](README.md)
- [Page-by-page guides](pages/README.md)
