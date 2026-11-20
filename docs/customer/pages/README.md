# Page-by-page guides

Each guide follows: Purpose → When to use it → How to get there → What you can do → Related pages.

Every route is also listed in the [complete page index](../PAGE_INDEX.md).

## Cli

| Page | What it covers |
|------|----------------|
| [Discovery & Preflight](cli/cli-discover.md) | Discovery sources and preflight checks before deploy. |
| [Health & Status](cli/cli-health.md) | health / status / test / forge-handoff JSON ops. |
| [Lab Mode](cli/cli-lab.md) | Lab mode storage/tune/setup helpers. |
| [Node Lifecycle](cli/cli-lifecycle.md) | Scale, upgrade, destroy, unlock via hypercluster CLI. |
| [CLI Provisioning](cli/cli-provision.md) | CLI deploy / wizard / profiles for bare-metal Kubernetes. |
| [SSH & Kubeconfig](cli/cli-ssh.md) | SSH, jump hosts, kubeconfig fetch/merge, API tunnels. |
| [Zyvor Platform Handoff](cli/cli-zyvor-handoff.md) | Hand off a ready cluster to the Zyvor product stack. |

## Cockpit

| Page | What it covers |
|------|----------------|
| [Backups](cockpit/cluster-backups.md) | Backup and etcd/snapshot related ops. |
| [GPU](cockpit/cluster-gpu.md) | GPU node and operator status. |
| [Instruments](cockpit/cluster-instruments.md) | Instrument / telemetry panels for the cluster. |
| [Networking](cockpit/cluster-network.md) | CNI / MetalLB / ingress networking status. |
| [Nodes](cockpit/cluster-nodes.md) | Node inventory, SSH status, and scale actions. |
| [Observability](cockpit/cluster-observability.md) | Observability stack status (metrics, logs). |
| [Overview](cockpit/cluster-overview.md) | Cluster overview — health, version, and capacity summary. |
| [Platform](cockpit/cluster-platform.md) | Zyvor platform components installed on the cluster. |
| [Security](cockpit/cluster-security.md) | Security posture and hardening checklist. |
| [Cluster Settings](cockpit/cluster-settings.md) | Per-cluster settings and conf linkage. |
| [Storage](cockpit/cluster-storage.md) | Storage classes and CSI status. |
| [Templates](cockpit/cluster-templates.md) | Cluster / workload templates. |
| [Upgrades](cockpit/cluster-upgrades.md) | Upgrade paths for k3s/Kubespray clusters. |
| [Virtual Machines](cockpit/cluster-vms.md) | KubeVirt VMs when virtualization add-ons are installed. |
| [Workloads](cockpit/cluster-workloads.md) | Workloads running on the provisioned cluster. |

## Create

| Page | What it covers |
|------|----------------|
| [Quick Deploy](create/quick-deploy.md) | Opinionated quick path for a standard cluster profile. |
| [Cluster Studio](create/studio.md) | Full Cluster Studio wizard (nodes → storage → network → validate → deploy). |

## Edit

| Page | What it covers |
|------|----------------|
| [Conf editor](edit/editor.md) | Raw cluster.conf editor with validation. |

## Nav

| Page | What it covers |
|------|----------------|
| [Cluster detail](nav/cluster.md) | Cluster cockpit — open a selected cluster into overview and day-2 tabs. |
| [Ask Zeus](nav/copilot.md) | Ask Zeus / Copilot overlay for cluster-grounded assistance. |
| [Dashboard](nav/dashboard.md) | Fleet home for Hypercluster Desktop — registered clusters and deploy shortcuts. |
| [Advanced ops](nav/operations.md) | Advanced Day-2 operations against the selected cluster. |
| [Settings](nav/settings.md) | Desktop app settings, providers, and trial/license status. |
| [Create Cluster](nav/studio-hub.md) | Create Cluster hub — pick Kubernetes, virtualization, AI, or edge intent. |

## Ops

| Page | What it covers |
|------|----------------|
| [Deploy console](ops/deploy.md) | Live deploy console — pipeline logs and stage status. |

---

32 guides. Regenerate: `node scripts/customer-docs/generate-guide-index.mjs`.
