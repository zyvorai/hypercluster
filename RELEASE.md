# Release checklist

1. Bump [`VERSION`](VERSION) (semver).
2. Confirm defaults in [`config/cluster.conf.example`](config/cluster.conf.example) match what was tested.
3. Regenerate documentation:
   ```bash
   pip3 install -r requirements-docs.txt   # once
   make docs                               # markdown + docs/pdf/ + AGENT-QUICKREF.md
   ```
4. For agent/Cursor work, keep [AGENTS.md](AGENTS.md) and [docs/agents/training.md](docs/agents/training.md) in sync with behavior changes.
5. Run quality gates:
   ```bash
   make lint
   make test-smoke
   make test-inventory
   make test-platform-config
   make test-platform-json
   make test-preflight-json
   make desktop-check
   make desktop-build   # Tauri bundle → desktop/src-tauri/target/release/bundle/
   ```
6. Desktop release artifacts:
   ```bash
   make desktop-pkg    # macOS arm64: Hypercluster-<version>-arm64.pkg with Zyvor EULA
   make desktop-build  # .app / .dmg in desktop/src-tauri/target/release/bundle/macos/
   ```
   Attach `.pkg` or `.dmg` to the GitHub Release. Uninstall: `make desktop-uninstall` (see `desktop/distribution/README.md`).
7. Tag and push:
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```
8. Create a [GitHub Release](https://github.com/ssahani/hypercluster/releases) summarizing:
   - Kubespray version
   - Kubernetes / k3s version (if k3s path tested)
   - KubeVirt / CDI versions (if platform stack tested)
   - Notable changes

Manual E2E (optional, before major releases):

- `./scripts/test-local.sh` — full Kubespray path (Multipass, 20–30 min)
- `./scripts/test-podman.sh` — k3s platform path via hypercluster (Podman containers)
- Remote k3s: `./hypercluster -c cluster.conf deploy && ./hypercluster -c cluster.conf test`
- JSON automation: `./hypercluster -c cluster.conf preflight --json`, `test --json`, and `status --json`
