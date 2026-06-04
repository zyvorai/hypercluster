# Hypercluster Documentation Hub

End-to-end Kubernetes cluster lifecycle — **Kubespray** and **k3s platform** paths. Version **0.1.0** · generated 2026-06-04T16:22:04Z.

---

## Latest

- **Desktop UX guide** — [desktop-ux-guide.md](guides/desktop-ux-guide.md) (Dashboard, wizard, operations, ⌘K palette)
- **k3s E2E** — `preflight → deploy → test` with `test --json` / `status --json`
- **Hypercluster Desktop** — Tauri app; all actions via CLI ([guide](guides/desktop-ux-guide.md))
- **Doc generator** — `make docs` · `make docs-serve` (port 8080)

---

## Documentation structure

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
| [CLI guide](guides/cli/hypercluster-guide.md) | Commands, flags, JSON, Make |

### Generated reference

| Document | Source |
|----------|--------|
| [CLI reference](generated/CLI.md) | `./hypercluster -h` |
| [cli-reference.txt](_build/cli-reference.txt) | Same (plain text) |
| [Configuration reference](generated/CONFIG-REFERENCE.md) | `config/cluster.conf.example` |
| [Make targets](generated/MAKE-TARGETS.md) | `make help` |

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

**Regenerate:** `make docs` · **Last generated:** 2026-06-04T16:22:04Z
