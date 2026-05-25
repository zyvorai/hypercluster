# Release checklist

1. Bump [`VERSION`](VERSION) (semver).
2. Confirm defaults in [`config/cluster.conf.example`](config/cluster.conf.example) match what was tested.
3. Run quality gates:
   ```bash
   make lint
   make test-smoke
   make test-inventory
   ```
4. Tag and push:
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```
5. Create a [GitHub Release](https://github.com/ssahani/hypercluster/releases) summarizing:
   - Kubespray version
   - Kubernetes version
   - Notable changes

Manual E2E (optional, before major releases):

- `./scripts/test-local.sh` — full Kubespray path (Multipass, 20–30 min)
- `./scripts/test-podman.sh` — fast k3s path (Podman containers)
