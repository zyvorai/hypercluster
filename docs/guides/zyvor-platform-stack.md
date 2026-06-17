# Zyvor platform stack — ecosystem map & install order

hypercluster is **Day 0**: it creates a Kubernetes cluster over SSH. The sibling products in the Zyvor portfolio handle **Day 1+** (VMs, GPU/AI, observability, migration, metal). This guide maps engineering domains to products and gives a recommended install order — **no separate “mega product” required**.

Commercial umbrella: [hypersdk](https://zyvor.dev) · hypercluster repo lives alongside other `../tt` projects on a developer workstation.

---

## Install order (reference path)

```text
  [Optional] Metal / hypervisor          [Optional] Migration / inspect
         │                                        │
         ▼                                        ▼
   machina · zyvor-fabric · IronWolf      guestkit · hyper2kvm
         │                                        │
         └────────────────┬───────────────────────┘
                          ▼
                   hypercluster  ◄── YOU ARE HERE (Day 0)
                   preflight → deploy → test
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
     packetwolf        forge          v9s (Zeus OS)
   (Cilium network)  (GPU / AI)    (KubeVirt VM ops)
          │               │               │
          └───────────────┼───────────────┘
                          ▼
              ragnarok · VMRogue · Aether (as needed)
```

### Step-by-step

| Phase | Product | When | Notes |
|-------|---------|------|-------|
| 0 — Nodes | **machina**, **zyvor-fabric**, or **IronWolf** | Bare metal or libvirt hosts not ready | machina = KVM/libvirt; IronWolf = Metal3/BMC; zyvor-fabric = systemd-native cloud |
| 0 — Migrate in | **guestkit**, **hyper2kvm** | VMs moving from VMware/Hyper-V | Offline inspect (guestkit) + conversion (hyper2kvm) |
| **1 — Cluster** | **hypercluster** | Always first for K8s | `K8S_DISTRO=kubespray` or `k3s`; outputs `KUBECONFIG_OUTPUT` |
| 2 — Network intel | **packetwolf** | k3s path with Cilium enabled | Requires running cluster + Cilium |
| 3 — GPU / AI serving | **forge** | GPU clusters, vLLM/Triton, operators | Installs **into** existing cluster via Helm |
| 3 — VM / app ops | **v9s** (Zeus OS), **ragnarok**, **VMRogue** | KubeVirt workloads | hypercluster can install KubeVirt/CDI; ops UI lives in sibling apps |
| 4 — Portability | **Aether** | Multi-runtime (Podman/K8s/KubeVirt/Metal3) | Above single-cluster lifecycle |

After hypercluster deploy:

```bash
export KUBECONFIG="${KUBECONFIG_OUTPUT:-$HOME/.kube/mycluster.yaml}"
kubectl get nodes
./hypercluster -c cluster.conf health --json
```

Point sibling products at the same kubeconfig (or merge into `~/.kube/config` via `./hypercluster merge-kubeconfig`).

### Forge handoff (Day 2)

After deploy, emit JSON for **forge** federation import:

```bash
./hypercluster -c cluster.conf forge-handoff --json > handoff.json
```

From a **forge** checkout:

```bash
./scripts/lib/hypercluster-handoff.sh --handoff handoff.json
# API: POST /api/k8s/clusters/import/hypercluster
# Docs: forge/docs/product/HYPERCLUSTER_HANDOFF.md
```

Recommended forge Helm profiles: `hyperclusterProfile`, `velero` (k3s → `rancher.io/local-path` CSI), `helm/observability/values-hypercluster.yaml`, and `vectorStore.bootstrap`.

---

## Domain → product map

Use this when scoping work: **do not re-implement sibling products inside hypercluster**.

| # | Engineering domain | Owner product(s) | hypercluster role |
|---|-------------------|------------------|-------------------|
| 1 | Linux infrastructure | machina, zyvor-fabric, IronWolf | Assumes SSH-ready nodes; `lab.sh` for single-node k3s tuning only |
| 2 | DevOps / CI/CD | forge/gitops (Argo CD, Flux, Tekton) | On-demand CLI deploy only — no pipelines |
| 3 | **Kubernetes engineering** | **hypercluster** (+ Aether portability) | **Core product** |
| 4 | Virtualization | machina, hyper2kvm, guestkit, v9s, ragnarok, VMRogue | KubeVirt/CDI Helm on k3s path |
| 5 | GPU infrastructure | forge, zyvor-fabric | Optional GPU Operator Helm flag |
| 6 | AI/LLM infrastructure | forge, v9s | Desktop Copilot = ops chat, not serving |
| 7 | Container platform | Aether, hypersdk | Runtime via Kubespray/k3s |
| 8 | DevSecOps | packetwolf, ragnarok, VMRogue | cert-manager TLS only; policy stacks in siblings |
| 9 | **Infrastructure automation** | **hypercluster**, Terraform in v9s/zyvor-fabric/IronWolf | **Core:** Ansible + `cluster.conf` |
| 10 | Database / vector stack | v9s (PostgreSQL events); **gap** for Qdrant SKU | Not in hypercluster |
| 11 | Observability | packetwolf, forge, machina, VMRogue, ragnarok | `health --json`, metrics-server, Hubble |
| 12 | HA & DR | forge DR, ragnarok, VMRogue (Velero) | Multi-CP HA via Kubespray; no Velero product |

Full non-goals detail: [Agent training § Scope](../agents/training.md#2-scope--non-goals).

---

## What hypercluster should not become

| Avoid in hypercluster | Use instead |
|----------------------|-------------|
| vLLM / Triton / KServe serving | forge |
| VM vCenter-style cockpit | v9s, ragnarok, VMRogue |
| Bare-metal hypervisor UI | machina, zyvor-fabric |
| VMware → KVM migration | hyper2kvm + guestkit |
| Network auto-policy / eBPF intel | packetwolf |
| Full Prometheus/Grafana/Loki | forge observability charts, VMRogue |
| Velero backup / BCP | ragnarok, VMRogue, forge DR |
| GitOps / Tekton pipelines | forge/gitops |

**Reasonable hypercluster extensions** (thin, composable): optional Helm hooks for catalog flags (Velero, Prometheus), richer `postdeploy` handoff, discover → `cluster.conf` from machina/libvirt sources.

---

## Portfolio gaps (optional future SKUs)

Not covered by a dedicated product today:

- **Vector / RAG data plane** (Qdrant, managed Postgres platform) — consider a small **`zyvor-data`** add-on or forge chart pack, not hypercluster.
- **Unified DevSecOps SAST / secure CI** — integrate scanners into forge or packetwolf catalogs rather than a new monolith.

---

## Related docs

| Doc | Purpose |
|-----|---------|
| [Scope & non-goals](../agents/training.md#2-scope--non-goals) | 12-domain in/out list for agents |
| [README — Scope](../../README.md#scope--non-goals) | Executive summary |
| [Lab operations](lab-ops.md) | Single-node k3s disk/memory tune |
| [Desktop UX guide](desktop-ux-guide.md) | Cluster Studio & cockpit |

---

_Doc version: 2026-06-17T17:22:39Z · hypercluster v0.1.0_
