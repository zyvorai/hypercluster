# Hypercluster Desktop — Apple Silicon (M1/M2/M3/M4)

Hypercluster Desktop is **arm64-native only**. Release `.pkg` / `.dmg` artifacts are built for Apple Silicon Macs (M1, M2, M3, M4 and later). Intel Mac support has ended.

This guide covers install requirements, common compatibility issues, and fixes when deploy or preflight fails from the GUI app.

---

## Requirements

| Item | Notes |
|------|-------|
| **Mac** | Apple Silicon (M-series), macOS 11+ |
| **Installer** | `Hypercluster-*-arm64.pkg` — filename must include `arm64` |
| **Homebrew bash 5** | Required for the bundled `hypercluster` CLI scripts |
| **Deploy tools** | `ssh`, `kubectl`, `helm`, `ansible` (via `./scripts/setup-macos.sh`) |
| **Rosetta** | **Do not** enable “Open using Rosetta” on Hypercluster.app |

One-time setup from repo root:

```bash
chmod +x scripts/setup-macos.sh scripts/macos/desktop-preflight.sh
./scripts/setup-macos.sh
./scripts/macos/desktop-preflight.sh
```

---

## Why the GUI app behaves differently from Terminal

When you launch Hypercluster from **Finder**, **Dock**, or **Spotlight**, macOS gives the app a **minimal PATH**. Tools installed with Homebrew (`/opt/homebrew/bin`) are often **not** visible unless the app adds them explicitly.

Hypercluster Desktop now prepends these paths for every CLI subprocess:

- `/opt/homebrew/bin` and `/opt/homebrew/sbin` (Apple Silicon Homebrew)
- `/usr/local/bin` and `/usr/local/sbin` (Intel Homebrew / legacy installs)
- Standard system paths (`/usr/bin`, `/bin`, …)

It also forwards `SSH_AUTH_SOCK` and `HOME` so remote deploy over SSH works with your login session keys.

---

## Common issues and fixes

### “Apple Silicon (arm64) required” on an M-series Mac

| Cause | Fix |
|-------|-----|
| Wrong build (Intel x86_64 `.app`) | Reinstall `Hypercluster-*-arm64.pkg` from Zyvor |
| App forced through Rosetta | Finder → Hypercluster.app → Get Info → **uncheck** “Open using Rosetta” |
| `.pkg` install failed with Intel message on M1/M2/M3 | Fixed in 0.1.0+ — preinstall uses `sysctl hw.optional.arm64` (Installer runs scripts under Rosetta). Re-download/rebuild pkg and retry. |
| Dev build on wrong target | `npm run tauri build -- --target aarch64-apple-darwin` |

Verify:

```bash
uname -m                    # expect: arm64
file /Applications/Hypercluster.app/Contents/MacOS/hypercluster-desktop
# expect: arm64
```

### “bash 4+ required” or deploy exits immediately

macOS ships `/bin/bash` 3.2. The CLI needs **Homebrew bash 5**:

```bash
brew install bash
/opt/homebrew/bin/bash --version   # expect 5.x
./scripts/macos/desktop-preflight.sh
```

The desktop app runs subprocesses with Homebrew bash when present (`/opt/homebrew/bin/bash`, then `/usr/local/bin/bash`).

### `ssh: command not found` or `helm: command not found`

Install deploy-side tools once:

```bash
./scripts/setup-macos.sh
```

Then quit and reopen Hypercluster Desktop (or run preflight again from the app).

### SSH works in Terminal but not from the app

The GUI may not inherit your SSH agent. Before deploy:

```bash
ssh-add ~/.ssh/your_key
ssh-add -l
```

Hypercluster Desktop forwards `SSH_AUTH_SOCK` when set. If you use `ssh-agent` only in shell profile, start the agent in your login session or add keys before opening the app.

### Gatekeeper / “app is damaged” / quarantine

After downloading a `.pkg` or `.dmg`:

```bash
xattr -dr com.apple.quarantine /Applications/Hypercluster.app
```

Prefer installing via the signed `.pkg` (`make desktop-pkg` or Zyvor release).

### Preflight passes in Terminal but fails in Desktop

1. Open **Settings** → confirm **hypercluster binary** points to the bundled runtime or your repo clone.
2. Run `./scripts/macos/desktop-preflight.sh` — fix any ❌ items.
3. Ensure `cluster.conf` SSH key path is absolute (e.g. `/Users/you/.ssh/id_ed25519`).

---

## Build and install (developers)

| Goal | Command |
|------|---------|
| Preflight this Mac | `./scripts/macos/desktop-preflight.sh` |
| Dev UI | `make desktop-dev` |
| Release `.pkg` | `make desktop-pkg` (requires arm64 host) |
| Sanity check | `make desktop-check` |

Release builds set `LSRequiresNativePlatformEnvironment` and `LSArchitecturePriority: arm64` so the app always runs natively on Apple Silicon.

See also:

- [Desktop UX guide](desktop-ux-guide.md)
- [desktop/distribution/README.md](../../desktop/distribution/README.md)
- [Lab operations](lab-ops.md) — secondary disk and memory tune for single-node labs

---

_Doc version: 2026-06-06T17:27:55Z · hypercluster v0.1.0_
