# User Guides

Task-oriented guides for hypercluster CLI and Desktop UX.

## Quick navigation

### CLI

| Guide | Best for |
|-------|----------|
| [hypercluster CLI guide](cli/hypercluster-guide.md) | Commands, flags, k3s workflow, JSON |
| [Generated CLI reference](../generated/CLI.md) | Auto-generated from `./hypercluster -h` |
| [Configuration reference](../generated/CONFIG-REFERENCE.md) | All `cluster.conf` variables |

### Desktop UX

| Guide | Best for |
|-------|----------|
| [Desktop UX guide](desktop-ux-guide.md) | Cluster Studio, cockpit, operations, palettes |
| [Apple Silicon macOS](desktop-macos-apple-silicon.md) | M1/M2/M3/M4 install, PATH, bash 5, SSH from GUI |

### Agent training (AI / Cursor)

| Guide | Best for |
|-------|----------|
| [AGENTS.md](../../AGENTS.md) | Root agent summary |
| [Agent training](agents/training.md) | Full architecture and workflows |
| [AGENT-QUICKREF](../generated/AGENT-QUICKREF.md) | Generated quickref (`make docs`) |

### Operations

| Guide | Best for |
|-------|----------|
| [Zyvor platform stack](zyvor-platform-stack.md) | Ecosystem map, Day 2 install order, sibling products |
| [Lab operations](lab-ops.md) | Secondary disk for KubeVirt, single-node memory tune |
| [Remote libvirt deploy](remote-libvirt-deploy.md) | User story: 2 VM k3s lab on remote hypervisor, zero-touch E2E |
| [Main README](../../README.md) | Install, tutorial, troubleshooting |
| [Release checklist](../../RELEASE.md) | Version bump and QA |

## By task

| Task | Guide | Time |
|------|-------|------|
| First remote k3s cluster | [README — k3s quickstart](../../README.md#remote-k3s-platform-quickstart) or [Remote libvirt deploy](remote-libvirt-deploy.md) | 30–60 min |
| Use Desktop instead of CLI | [Desktop UX guide](desktop-ux-guide.md) | 10 min |
| Discover nodes for Studio | [CLI guide — discover](cli/hypercluster-guide.md#discover-no-clusterconf) | 5 min |
| Automate smoke tests | [CLI guide — JSON](cli/hypercluster-guide.md#json-output) | 5 min |
| Install sibling Zyvor products after deploy | [Zyvor platform stack](zyvor-platform-stack.md) | 5 min |

## Regenerate docs

```bash
make docs
make docs-serve   # browse at http://localhost:8080
```
