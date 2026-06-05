# Hypercluster Desktop — macOS installation

Proprietary software · **ZyvorAI Labs Private Limited** · [zyvor.dev](https://zyvor.dev)

## Install options

### Option A — `.pkg` installer (recommended)

Shows the **Zyvor License Agreement** in the macOS Installer UI.

```bash
make desktop-pkg
open desktop/distribution/Hypercluster-0.1.0-arm64.pkg
```

Installs `Hypercluster.app` to `/Applications` with bundled `hypercluster` CLI runtime.

### Option B — Script install (from built `.app`)

```bash
make desktop-build          # or: npm run desktop:build  (on macOS)
make desktop-install        # prompts: type ACCEPT for Zyvor license
```

### Option C — Drag-and-drop

Build the app, copy `Hypercluster.app` to `/Applications`. On **first launch**, the in-app **Zyvor License Agreement** must be accepted.

## Uninstall

```bash
make desktop-uninstall
# remove app data + license record:
./scripts/macos/uninstall-hypercluster-app.sh --purge
```

Removes `/Applications/Hypercluster.app`. With `--purge`, also deletes:

- `~/Library/Application Support/Hypercluster`
- `~/.hypercluster/` (license acceptance record)

## License acceptance

| Method | Record location |
|--------|-----------------|
| `.pkg` installer | `~/.hypercluster/license-acceptance.json` (after EULA pane) |
| `install-hypercluster-app.sh` | Same (interactive `ACCEPT` prompt) |
| First app launch | Same (in-app **I Accept** button) |

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

See also: [Desktop UX guide](../docs/guides/desktop-ux-guide.md)
