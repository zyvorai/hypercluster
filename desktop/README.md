# Hypercluster Desktop

Premium macOS/Windows desktop UI for the [hypercluster](../hypercluster) CLI — Liquid Glass design, cluster wizard, live deploy logs, and day-2 operations.

**All cluster lifecycle actions run exclusively through the `hypercluster` binary.** The desktop never invokes `helm`, `kubectl`, or manual installs for deploy/scale/upgrade/destroy/test.

## Requirements

- Node.js 20+
- Rust (for Tauri 2)
- macOS: Xcode CLT; [Homebrew bash 5](https://formulae.brew.sh/formula/bash) recommended (hypercluster requires bash 4+)
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

## UI → CLI mapping

| Desktop action | hypercluster command |
|----------------|---------------------|
| Test / Validate | `preflight` |
| Deploy | `deploy` |
| Platform smoke (k3s) | `test` / `test --full` |
| Node status | `status` |
| Scale | `scale` (after updating worker IPs in conf) |
| Upgrade | `upgrade` |
| Remove node | `remove-node <name>` (optional `-f`) |
| Destroy | `destroy -f` |

## Tech stack

- Tauri 2 (Rust) — process spawn, log streaming, native dialogs/notifications
- React 19 + TypeScript + Vite + Tailwind
- Monaco Editor — `cluster.conf` editing
- Framer Motion — glass card interactions

## Design

Machina-inspired Liquid Glass: `#0B0B0F` background, `#0A84FF` accents, 22–28px rounded glass panels, backdrop blur.
