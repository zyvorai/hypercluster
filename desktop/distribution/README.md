# Hypercluster Desktop — macOS installation

Proprietary software · **ZyvorAI Labs Private Limited** · [zyvor.dev](https://zyvor.dev)

**Trial access:** contact **sales@zyvor.dev** (not a public website download).

## Build on macOS (from source)

One-time CLI/tooling setup (from repo root):

```bash
chmod +x scripts/setup-macos.sh
./scripts/setup-macos.sh   # bash 5, ansible, kubectl, helm, …
```

| Goal | Command | Output |
|------|---------|--------|
| Dev UI | `make desktop-dev` or `npm run desktop` | Tauri dev window |
| `.app` / `.dmg` | `make desktop-build` | `desktop/src-tauri/target/*/release/bundle/macos/` |
| `.pkg` installer | `make desktop-pkg` | `desktop/distribution/Hypercluster-*-arm64.pkg` |
| Install locally | `make desktop-install` | `/Applications/Hypercluster.app` |
| Sanity check | `make desktop-check` | TS + `cargo check` |

Requirements: **Apple Silicon (arm64)** for release artifacts, macOS 11+, Node 20+, Rust, Xcode CLT, Homebrew bash 5.

Before first deploy from the installed app:

```bash
./scripts/setup-macos.sh
./scripts/macos/desktop-preflight.sh
```

Troubleshooting (PATH, bash 5, SSH agent, wrong-arch builds): [docs/guides/desktop-macos-apple-silicon.md](../../docs/guides/desktop-macos-apple-silicon.md).

## Install options

### Option A — `.pkg` installer (recommended)

Shows the **Zyvor License Agreement** in the macOS Installer UI and starts a **30-day trial** on this Mac.

```bash
make desktop-pkg
open desktop/distribution/Hypercluster-0.1.0-arm64.pkg
```

Installs `Hypercluster.app` to `/Applications` with bundled `hypercluster` CLI runtime.

### Option B — `.dmg` drag-and-drop

```bash
make desktop-build
open desktop/src-tauri/target/*/release/bundle/dmg/Hypercluster_*.dmg
```

Drag **Hypercluster** to **Applications**. On first launch, accept the in-app license to start the trial.

### Option C — Script install (from built `.app`)

```bash
make desktop-build          # or: npm run desktop:build  (on macOS)
make desktop-install        # prompts: type ACCEPT for Zyvor license
```

## Uninstall

Double-click the uninstaller (macOS dialog):

```bash
open desktop/distribution/Uninstall-Hypercluster.command
# or from repo:
open scripts/macos/Uninstall-Hypercluster.command
```

Or from the terminal:

```bash
make desktop-uninstall
# remove app + cluster data + license acceptance (trial is kept):
./scripts/macos/uninstall-hypercluster-app.sh --purge
```

Removes `/Applications/Hypercluster.app`. With `--purge`, also deletes:

- `~/Library/Application Support/Hypercluster` (cluster registry and settings)
- `~/.hypercluster/license-acceptance.json`

**Trial records are never removed** by uninstall (macOS Keychain + `~/.hypercluster/trial.json`), so reinstalling cannot start a new trial.

## 30-day trial

| Event | Behavior |
|-------|----------|
| First license acceptance | 30-day trial starts on this Mac |
| Trial active | Full app access |
| Trial expired | App blocked; contact **sales@zyvor.dev** for a license |
| Uninstall + reinstall | Trial does **not** reset |
| Paid license | Place `~/.hypercluster/commercial-license.json` (from Zyvor sales) |

Trial persistence:

| Store | Path / service |
|-------|----------------|
| Keychain | `dev.zyvor.hypercluster.desktop.trial` |
| File mirror | `~/.hypercluster/trial.json` |

## License acceptance

| Method | Record location |
|--------|-----------------|
| `.pkg` installer | `~/.hypercluster/license-acceptance.json` (after EULA pane) |
| `install-hypercluster-app.sh` | Same (interactive `ACCEPT` prompt) |
| First app launch | Same (in-app **I Accept & Start Trial** button) |

Non-interactive install (automation):

```bash
export HYPERCLUSTER_LICENSE_ACCEPT=1
./scripts/macos/install-hypercluster-app.sh
```

## Bundled CLI

The Mac app includes:

`/Applications/Hypercluster.app/Contents/Resources/hypercluster-runtime/hypercluster`

The desktop app auto-detects this path; no separate CLI install required.

## Requirements

- **Apple Silicon Mac (M1/M2/M3/M4 or later)** — arm64 only; Intel (x86_64) support ended
- macOS 11.0+
- [Homebrew bash 5](https://formulae.brew.sh/formula/bash) for bundled CLI scripts

Build the release `.pkg` on an Apple Silicon Mac (`make desktop-pkg`). Local dev on Intel Macs still works via `npm run desktop`, but release artifacts are arm64-only.

See also:

- [Desktop UX guide](../../docs/guides/desktop-ux-guide.md)
- [Apple Silicon troubleshooting](../../docs/guides/desktop-macos-apple-silicon.md)
