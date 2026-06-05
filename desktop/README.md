# Hypercluster Desktop

Premium macOS/Windows desktop UI for the [hypercluster](../hypercluster) CLI — Liquid Glass design, **Cluster Creation Studio**, live deploy logs, and a 14-section cluster cockpit.

**All cluster lifecycle actions run exclusively through the `hypercluster` binary.** The desktop never invokes `helm`, `kubectl`, or manual installs for deploy/scale/upgrade/destroy/test.

## Requirements

- Node.js 20+
- Rust (for Tauri 2)
- macOS: Xcode CLT; **Apple Silicon (M-series) for release installs**; [Homebrew bash 5](https://formulae.brew.sh/formula/bash) recommended
- A working `hypercluster` binary (repo root `../hypercluster` is auto-detected in dev)

## Run (npm CLI — like `agent`)

From the **repo root**:

```bash
npm install
npm run desktop
# or
npx hypercluster-desktop
```

Install globally (command available everywhere):

```bash
npm install -g ./desktop
hypercluster-desktop        # alias: hc-desktop
```

### macOS app (`.pkg` / `.dmg` + 30-day trial)

```bash
make desktop-pkg              # → desktop/distribution/Hypercluster-0.1.0-arm64.pkg
open desktop/distribution/Hypercluster-0.1.0-arm64.pkg

make desktop-build            # → .app + .dmg (drag to Applications)
make desktop-install          # script install (type ACCEPT for license)
open scripts/macos/Uninstall-Hypercluster.command   # GUI uninstall
make desktop-uninstall        # remove from /Applications
```

Includes a **30-day trial per Mac** (survives reinstall). Contact **sales@zyvor.dev** for trial access or a license after expiry.

See [`distribution/README.md`](distribution/README.md).

### Commands

| Command | Description |
|---------|-------------|
| `hypercluster-desktop` | Start Tauri dev (default) |
| `hypercluster-desktop dev` | Same as above |
| `hypercluster-desktop build` | Build frontend + native bundle |
| `hypercluster-desktop run` | Launch built `.app` / binary |
| `hypercluster-desktop help` | Show usage |

Legacy (still works):

```bash
cd desktop && npm install && npm run tauri dev
```

On first launch, open **Settings** and confirm the resolved hypercluster binary path.

## Cluster storage

- Registry: `~/Library/Application Support/Hypercluster/clusters.json` (macOS)
- Per-cluster config: `~/Library/Application Support/Hypercluster/clusters/<name>/cluster.conf`

## Create & edit clusters

| Action | Behavior |
|--------|----------|
| **Import cluster.conf…** | File picker → copies config into registry |
| **Auto-import on startup** | If the hypercluster binary lives in a repo with `cluster.conf`, imports once when the cluster name is new |
| **Create Cluster Hub** | Intent cards → **Quick Deploy** (3 steps) or **Cluster Studio** (full `ClusterSpec` flow) |
| **Edit existing** | **Open Cluster Studio** from cluster detail — saves via `mergeClusterSpec` (preserves registry UUID) |

Templates live in `config/templates/*.yaml`. The typed model is `desktop/src/lib/clusterSpec.ts`.

## UI → CLI mapping

| Desktop action | hypercluster command |
|----------------|---------------------|
| Test / Validate | `preflight` |
| Deploy | `deploy` |
| Platform smoke (k3s) | `test` / `test --full` |
| Node status (dashboard) | `status --json` |
| Workloads cockpit | `workloads --json` |
| KubeVirt VMs / templates | `vms --json` |
| Template create (preview) | `vm create --template … --name … --json` |
| Node discovery (Studio) | `discover --json --source …` |
| Platform test results | `test --json` |
| Scale | `scale` (after updating worker IPs in conf) |
| Upgrade | `upgrade` |
| Remove node | `remove-node <name>` (optional `-f`) |
| Destroy | `destroy -f` |

## Tech stack

- Tauri 2 (Rust) — process spawn, log streaming, native dialogs/notifications
- React 19 + TypeScript + Vite + Tailwind
- Monaco Editor — `cluster.conf` editing
- Framer Motion — topology canvas (lazy-loaded chunk)

## Design

Machina-inspired Liquid Glass: `#0B0B0F` background, `#0A84FF` accents, 22–28px rounded glass panels, backdrop blur.

See also: [`docs/index.md`](../docs/index.md) · [`docs/guides/desktop-ux-guide.md`](../docs/guides/desktop-ux-guide.md) · [`distribution/README.md`](distribution/README.md) (macOS `.pkg` install)
