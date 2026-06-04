# hypercluster CLI Guide

Task-oriented reference for the bash CLI. Generated CLI help is also at [`docs/_build/cli-reference.txt`](../../_build/cli-reference.txt) (run `make docs`).

---

## Quick paths

| Goal | Commands |
|------|----------|
| **Remote k3s platform** | `preflight` → `deploy` → `test` |
| **Kubespray HA cluster** | `wizard` or edit conf → `preflight` → `deploy` |
| **Automation / CI** | `test --json`, `status --json` |
| **Day-2 add nodes** | Update `WORKER_IPS` → `scale` |
| **Upgrade K8s** | Bump `KUBE_VERSION` → `upgrade` |

---

## Global flags

| Flag | Meaning |
|------|---------|
| `-c <file>` | Config file (default `./cluster.conf`) |
| `-f` | Force inventory regen; skip destroy confirm; force remove-node |
| `-n` | Dry run |
| `-v` | Verbose Ansible output |
| `-V` | Print version |
| `-h` | Help |

---

## Commands

| Command | k3s | Kubespray | Description |
|---------|-----|-----------|-------------|
| `wizard` | ✓ | ✓ | Interactive `cluster.conf` generator |
| `init` | — | ✓ | Clone Kubespray + inventory |
| `preflight` | ✓ | ✓ | Local tools + SSH checks |
| `deploy` | ✓ | ✓ | Full install |
| `test` | ✓ | — | Platform smoke tests |
| `test --full` | ✓ | — | Extended snapshot checks |
| `test --json` | ✓ | — | Machine-readable results |
| `status` | ✓ | ✓ | Node status |
| `status --json` | ✓ | ✓ | Machine-readable node JSON |
| `scale` | partial | ✓ | Add workers from conf |
| `upgrade` | — | ✓ | Upgrade to `KUBE_VERSION` |
| `remove-node` | ✓ | ✓ | Drain + remove node |
| `fetch-kubeconfig` | ✓ | ✓ | Copy admin kubeconfig |
| `merge-kubeconfig` | ✓ | ✓ | Merge into `~/.kube/config` |
| `install-kubevirt` | ✓ | ✓ | KubeVirt + CDI |
| `destroy` | ✓ | ✓ | Tear down cluster |
| `unlock` | ✓ | ✓ | Clear stale lock |

---

## k3s platform workflow

```bash
cp config/cluster.conf.example cluster.conf
$EDITOR cluster.conf   # K8S_DISTRO=k3s, METALLB_IP_POOL, SSH_*, CONTROL_PLANE_IPS

./hypercluster -c cluster.conf preflight
./hypercluster -c cluster.conf deploy
./hypercluster -c cluster.conf test
./hypercluster -c cluster.conf status --json
```

**Deploy behavior:** skips k3s reinstall when server is healthy. Set `FORCE_K3S_REINSTALL=1` to replace.

**Stack order:** Cilium → cert-manager → MetalLB → KubeVirt/CDI → metrics-server.

---

## JSON output

### `test --json`

Stdout (stderr has human PASS/FAIL lines):

```json
{"pass": 10, "fail": 0, "checks": [{"name": "Cilium healthy", "passed": true}]}
```

### `status --json`

```json
{"ready": 1, "total": 1, "nodes": [{"name": "node1", "ready": true, "roles": "true"}]}
```

---

## Make shortcuts

```bash
make deploy CONFIG=cluster.conf
make test-remote CONFIG=cluster.conf
make status CONFIG=cluster.conf
make docs
```

See [`docs/generated/MAKE-TARGETS.md`](../../generated/MAKE-TARGETS.md) for full list.

---

## Related

- [Desktop UX guide](../desktop-ux-guide.md)
- [Configuration reference](../../generated/CONFIG-REFERENCE.md)
- [Documentation hub](../../index.md)

---

_Doc version: 2026-06-04T16:22:04Z · hypercluster v0.1.0_
