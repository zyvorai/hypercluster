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

### Agent training (AI / Cursor)

| Guide | Best for |
|-------|----------|
| [AGENTS.md](../../AGENTS.md) | Root agent summary |
| [Agent training](agents/training.md) | Full architecture and workflows |
| [AGENT-QUICKREF](../generated/AGENT-QUICKREF.md) | Generated quickref (`make docs`) |

### Operations

| Guide | Best for |
|-------|----------|
| [Lab operations](lab-ops.md) | Secondary disk for KubeVirt, single-node memory tune |
| [Main README](../../README.md) | Install, tutorial, troubleshooting |
| [Release checklist](../../RELEASE.md) | Version bump and QA |

## By task

| Task | Guide | Time |
|------|-------|------|
| First remote k3s cluster | [README — k3s quickstart](../../README.md#remote-k3s-platform-quickstart) | 30–60 min |
| Use Desktop instead of CLI | [Desktop UX guide](desktop-ux-guide.md) | 10 min |
| Discover nodes for Studio | [CLI guide — discover](cli/hypercluster-guide.md#discover-no-clusterconf) | 5 min |
| Automate smoke tests | [CLI guide — JSON](cli/hypercluster-guide.md#json-output) | 5 min |
| Import existing config | [Desktop UX — Import](desktop-ux-guide.md#3-dashboard) | 2 min |

## Regenerate docs

```bash
make docs
make docs-serve   # browse at http://localhost:8080
```
