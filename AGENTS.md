# hypercluster — Agent Instructions

Guidance for AI coding agents (Cursor, Claude, etc.) working in this repository.

## What this project is

**hypercluster** is a bash CLI that deploys and manages Kubernetes clusters over SSH via two paths:

| Path | `K8S_DISTRO` | Engine |
|------|--------------|--------|
| Kubespray | `kubespray` (default) | Ansible playbooks in `.kubespray/` |
| k3s platform | `k3s` | SSH k3s install + Helm stack from laptop |

**Hypercluster Desktop** (`desktop/`) is a Tauri + React UI that **only** spawns the `hypercluster` binary — never `helm`, `kubectl`, or manual installs for lifecycle ops.

## Golden rules

1. **Single config file:** `cluster.conf` (gitignored). Template: `config/cluster.conf.example`.
2. **k3s platform stack order:** Cilium → cert-manager → MetalLB → KubeVirt/CDI → metrics-server (`lib/platform-stack.sh`).
3. **k3s must use** `--disable-kube-proxy` in `K3S_EXEC_ARGS` when Cilium replaces kube-proxy.
4. **Re-deploy skips** k3s reinstall if server is healthy; use `FORCE_K3S_REINSTALL=1` to replace.
5. **`preflight --json` / `test --json`:** stdout is JSON only; human logs go to stderr (`lib/preflight.sh`, `lib/platform-test.sh`).
6. **Desktop:** all cluster actions via `hypercluster` subprocess (`desktop/src-tauri/src/hypercluster.rs`). Edit flows use **`ClusterSpec`** → `mergeClusterSpec` / `specToClusterConf`; saving an existing cluster calls `update_cluster_by_path` (preserves registry id).
7. **Do not commit** `cluster.conf`, kubeconfigs, or `.kubespray-venv/` / `.docs-venv/`.
8. **Minimize scope** — match existing bash/React patterns; no unrelated refactors.

## Project layout

```
hypercluster              # CLI entry (bash 4+)
lib/*.sh                  # preflight, k3s, platform-stack, platform-test, wizard, …
config/cluster.conf.example
desktop/                  # Tauri 2 + React 19
docs/                     # make docs → guides, pdf/, generated/
tests/                    # shell unit tests (inventory, platform-config, test-json)
scripts/generate-docs.sh  # doc + PDF pipeline
```

## Commands agents should use

```bash
make lint                    # shellcheck
make test-smoke test-inventory test-platform-config test-platform-json
make desktop-check           # TS build + cargo check + spec/discover/vms/workloads tests
make docs                    # regenerate all docs + PDFs

# JSON helpers (also used by Desktop)
./hypercluster discover --json --source csv --csv tests/fixtures/discover-nodes.csv
./hypercluster -c cluster.conf vms --json
./hypercluster -c cluster.conf workloads --json

# k3s E2E (requires cluster.conf + remote host)
./hypercluster -c cluster.conf preflight
./hypercluster -c cluster.conf preflight --json
./hypercluster init --profile k3s-remote
./hypercluster -c cluster.conf deploy
./hypercluster -c cluster.conf test --json
./hypercluster -c cluster.conf status --json
```

## When changing behavior

| Area | Update |
|------|--------|
| CLI flags/commands | `hypercluster` header comment + `make docs` |
| cluster.conf vars | `config/cluster.conf.example` + `make docs` |
| Platform install order | `lib/platform-stack.sh` + tests |
| JSON output shape | `lib/platform-test.sh`, `tests/test-platform-test-json.sh` |
| Desktop ↔ CLI | `desktop/README.md`, `docs/guides/desktop-ux-guide.md`, `AGENTS.md` |
| User-facing docs | `README.md`, run `make docs` |

## Common pitfalls

- **cert-manager before Cilium** → pods cannot reach API `10.43.0.1`; Cilium must be first.
- **Parsing `test --json` from full stdout** → use stderr redirect or parse last JSON line only if legacy.
- **macOS bash 3.2** → CLI re-execs Homebrew bash 4+ (`hypercluster` shebang block).
- **MetalLB without `METALLB_IP_POOL`** → preflight fails when `METALLB_ENABLED=true`.
- **Desktop `app.emit`** → requires `use tauri::Emitter`.

## Documentation

- Hub: [docs/index.md](docs/index.md)
- Agent training: [docs/agents/training.md](docs/agents/training.md)
- Generated quickref: [docs/generated/AGENT-QUICKREF.md](docs/generated/AGENT-QUICKREF.md)
- UX: [docs/guides/desktop-ux-guide.md](docs/guides/desktop-ux-guide.md)

Regenerate everything: `make docs`
