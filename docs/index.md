# Hypercluster Documentation Hub

End-to-end Kubernetes cluster lifecycle — **Kubespray** and **k3s platform** paths. Version **0.1.0** · generated 2026-06-06T19:09:30Z.

---

## Latest

- **Desktop UX guide** — [desktop-ux-guide.md](guides/desktop-ux-guide.md) (Cluster Studio, cockpit, ⌘K / ⌘J AI Copilot)
- **Apple Silicon Desktop** — [desktop-macos-apple-silicon.md](guides/desktop-macos-apple-silicon.md) (M1/M2/M3/M4 PATH, bash 5, SSH)
- **k3s E2E** — `preflight → deploy → test` with `health --json`, `test --json`, `status --json`
- **Hypercluster Desktop** — Tauri app; all actions via CLI ([guide](guides/desktop-ux-guide.md))
- **Doc generator** — `make docs` · `make docs-serve` (port 8080)
- **Agent training** — [AGENTS.md](../AGENTS.md) · [training.md](agents/training.md)

---

## Documentation structure

### Agent training (AI / Cursor)

| Document | Description |
|----------|-------------|
| [AGENTS.md](../AGENTS.md) | Root agent instructions (start here) |
| [Agent training guide](agents/training.md) | Full architecture, workflows, pitfalls |
| [Agent quickref](generated/AGENT-QUICKREF.md) | Auto-generated from repo (`make docs`) |
| [AGENT-TRAINING.pdf](pdf/AGENT-TRAINING.pdf) | Printable training PDF |
| [.cursor/rules/](../.cursor/rules/) | Cursor rules (auto-applied) |

### Getting started

| Document | Description |
|----------|-------------|
| [README](../README.md) | Install, tutorial, troubleshooting |
| [Remote k3s quickstart](../README.md#remote-k3s-platform-quickstart) | Three-command platform deploy |
| [welcome.html](welcome.html) | Offline interactive doc hub (browser) |

### User guides

| Document | Description |
|----------|-------------|
| [Guides index](guides/README.md) | All task-oriented guides |
| [Desktop UX guide](guides/desktop-ux-guide.md) | Liquid Glass UI — full UX reference |
| [Apple Silicon Desktop](guides/desktop-macos-apple-silicon.md) | M-series Mac install and troubleshooting |
| [CLI guide](guides/cli/hypercluster-guide.md) | Commands, flags, JSON, Make |

### Generated reference

| Document | Source |
|----------|--------|
| [CLI reference](generated/CLI.md) | `./hypercluster -h` |
| [cli-reference.txt](_build/cli-reference.txt) | Same (plain text) |
| [Configuration reference](generated/CONFIG-REFERENCE.md) | `config/cluster.conf.example` |
| [Make targets](generated/MAKE-TARGETS.md) | `make help` |

### Printable PDFs

| Document | Description |
|----------|-------------|
| [PDF index](PDF_INDEX.txt) | List of all PDFs |
| [WELCOME.pdf](pdf/WELCOME.pdf) | One-page quick start |
| [Desktop UX guide](pdf/DESKTOP-UX-GUIDE.pdf) | Full desktop UI reference |
| [CLI guide](pdf/CLI-GUIDE.pdf) | Commands and k3s workflow |
| [CLI reference](pdf/CLI-REFERENCE.pdf) | Generated help text |
| [Agent training](pdf/AGENT-TRAINING.pdf) | AI agent training guide |
| [Presentations](pdf/) | Client deck PDFs (when Chrome available) |

### Client presentations

| Document | Description |
|----------|-------------|
| [Presentation index](client-presentations/README.md) | A4 HTML decks (offline / print PDF) |

### Release

| Document | Description |
|----------|-------------|
| [RELEASE.md](../RELEASE.md) | Version bump checklist |
| [desktop/README.md](../desktop/README.md) | Desktop install & npm CLI |

---

## Quick commands

```bash
make docs              # regenerate this tree
make docs-serve        # http://localhost:8080
make test-platform-json
npm run desktop        # Hypercluster Desktop
```

---

**Regenerate:** `make docs` · **Last generated:** 2026-06-06T19:09:30Z
