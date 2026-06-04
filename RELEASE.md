# Release checklist

1. Bump [`VERSION`](VERSION) (semver).
2. Confirm defaults in [`config/cluster.conf.example`](config/cluster.conf.example) match what was tested.
3. Run quality gates:
   ```bash
   make lint
   make test-smoke
   make test-inventory
   make test-platform-config
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
- `./scripts/test-podman.sh` — k3s platform path via hypercluster (Podman containers)
- Remote k3s: `./hypercluster -c cluster.conf deploy && ./hypercluster -c cluster.conf test`
