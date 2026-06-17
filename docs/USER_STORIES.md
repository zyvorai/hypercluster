# hypercluster User Stories

**Product:** Bare-metal Kubernetes lifecycle over SSH

Cross-reference: [Documentation index](README.md) · [Main README](../README.md)

## Personas

| Persona | Name | Focus |
|---------|------|-------|
| Cluster Admin | Alex | Deploy Kubespray or k3s platform stacks |
| Bare-Metal Engineer | Morgan | Day-2 upgrade, scale, health |
| Lab Operator | Jordan | Single-node k3s with KubeVirt for demos |

---

### Story 1 — Deploy first cluster

**As Alex** (Cluster Admin), I want bootstrap kubernetes via kubespray over ssh from cluster.conf, **so that** I deliver reliable outcomes.

| Criterion | Notes |
|-----------|-------|
| Core capability | hypercluster deploy, preflight |

---

### Story 2 — k3s platform stack

**As Jordan** (Lab Operator), I want install k3s + cilium + metallb + kubevirt on remote host, **so that** I deliver reliable outcomes.

| Criterion | Notes |
|-----------|-------|
| Core capability | K8S_DISTRO=k3s, hypercluster test |

---

### Story 3 — Upgrade cluster

**As Morgan** (Bare-Metal Engineer), I want run controlled upgrade with health checks, **so that** I deliver reliable outcomes.

| Criterion | Notes |
|-----------|-------|
| Core capability | upgrade_cluster.yml wrapper |

---

### Story 4 — Install Zyvor stack

**As Alex** (Cluster Admin), I want day-2 install forge, zeus-os, machina after cluster ready, **so that** I deliver reliable outcomes.

| Criterion | Notes |
|-----------|-------|
| Core capability | docs/guides/zyvor-platform-stack.md |

---

### Story 5 — Fetch kubeconfig

**As Morgan** (Bare-Metal Engineer), I want get kubeconfig on laptop after remote deploy, **so that** I deliver reliable outcomes.

| Criterion | Notes |
|-----------|-------|
| Core capability | hypercluster kubeconfig |

---

## Validation

Map each story to smoke tests, CI jobs, or manual lab steps before marking production-ready.
