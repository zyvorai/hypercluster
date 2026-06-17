# hypercluster Documentation

Bare-metal Kubernetes lifecycle over SSH

## Start Here

| Goal | Document |
|------|----------|
| Platform stack | [zyvor-platform-stack.md](guides/zyvor-platform-stack.md) |
| Agent training | [training.md](agents/training.md) |
| Main README | [README.md](../README.md) |
| **User journeys & acceptance criteria** | [User Stories](USER_STORIES.md) |

## User Stories

Persona-based journeys with acceptance criteria: **[USER_STORIES.md](USER_STORIES.md)**

| Persona | Focus |
|---------|-------|
| Alex (Cluster Admin) | Deploy Kubespray or k3s platform stacks |
| Morgan (Bare-Metal Engineer) | Day-2 upgrade, scale, health |
| Jordan (Lab Operator) | Single-node k3s with KubeVirt for demos |

## Ecosystem

Part of the [Zyvor / HyperSDK platform stack](https://zyvor.dev):

| Product | Role |
|---------|------|
| **hypercluster** | Kubernetes bootstrap |
| **machina** | Bare-metal hypervisor OS |
| **zeus-os (v9s)** | Cloud / KubeVirt control plane |
| **forge** | AI infrastructure on K8s |
| **hypersdk / hyper2kvm** | VM migration |
| **guestkit** | Offline VM assurance |
| **packetwolf** | Network intelligence |
| **Aether** | Runtime portability |
| **hermes** | Application layer for K8s |

See also: [../README.md](../README.md)
