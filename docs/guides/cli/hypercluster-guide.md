# hypercluster CLI Guide

Task-oriented reference for the bash CLI. Generated CLI help is also at [`docs/_build/cli-reference.txt`](../../_build/cli-reference.txt) (run `make docs`).

---

## Quick paths

| Goal | Commands |
|------|----------|
| **Remote k3s platform** | `preflight` → `deploy` → `test` |
| **Kubespray HA cluster** | `wizard` or edit conf → `preflight` → `deploy` |
| **Automation / CI** | `preflight --json`, `test --json`, `status --json` |
| **Desktop / inventory** | `discover --json`, `vms --json`, `workloads --json` |
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
| `init --profile <name>` | ✓ | ✓ | Copy `config/profiles/<name>.conf.example` → `cluster.conf` |
| `init` | — | ✓ | Clone Kubespray + inventory |
| `preflight` | ✓ | ✓ | Local tools + SSH checks |
| `preflight --json` | ✓ | ✓ | Machine-readable preflight JSON |
| `deploy` | ✓ | ✓ | Full install |
| `test` | ✓ | — | Platform smoke tests |
| `test --full` | ✓ | — | Extended snapshot checks |
| `test --json` | ✓ | — | Machine-readable results |
| `status` | ✓ | ✓ | Node status |
| `status --json` | ✓ | ✓ | Machine-readable node JSON |
| `discover --json` | — | — | Discover hosts/VMs (no config required) |
| `vms --json` | ✓ | — | KubeVirt VMIs + template catalog |
| `vm create --json` | ✓ | — | Validate template; create stub (preview) |
| `workloads --json` | ✓ | ✓ | Pod and service inventory |
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
# or:
./hypercluster init --profile k3s-remote

$EDITOR cluster.conf   # K8S_DISTRO=k3s, METALLB_IP_POOL, SSH_*, CONTROL_PLANE_IPS

./hypercluster -c cluster.conf preflight
./hypercluster -c cluster.conf preflight --json
./hypercluster -c cluster.conf deploy
./hypercluster -c cluster.conf test
./hypercluster -c cluster.conf status --json
./hypercluster -c cluster.conf workloads --json
```

**Deploy behavior:** skips k3s reinstall when server is healthy. Set `FORCE_K3S_REINSTALL=1` to replace.

**Stack order:** Cilium → cert-manager → MetalLB → KubeVirt/CDI → metrics-server.

**Per-node SSH (k3s):** set `NODE_SSH_OVERRIDES_JSON` to a JSON array of `{ip, sshUser?, sshKey?, sshPort?}` objects when nodes need different credentials than global `SSH_*`.

---

## Discover (no cluster.conf)

```bash
# CSV fixture (unit test / import preview)
./hypercluster discover --json --source csv --csv tests/fixtures/discover-nodes.csv

# Other sources: libvirt, proxmox, vmware, ssh-scan (see lib/discover.sh)
./hypercluster discover --json --source libvirt --uri qemu:///system
```

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

### `workloads --json`

```json
{"pods": [{"namespace": "kube-system", "name": "cilium-abc", "phase": "Running", "node": "10.0.0.10", "ready": 1, "containers": 1}], "services": [{"namespace": "default", "name": "kubernetes", "type": "ClusterIP", "clusterIp": "10.43.0.1"}]}
```

### `vms --json`

```json
{"vms": [], "templates": [{"id": "ubuntu-22.04", "label": "Ubuntu 22.04 LTS", "os": "linux"}]}
```

### `vm create --json`

```json
{"status": "stub", "message": "VM create from template is not yet implemented — catalog entry validated", "template": {}, "name": "my-vm", "namespace": "default"}
```

---

## Make shortcuts

```bash
make deploy CONFIG=cluster.conf
make test-remote CONFIG=cluster.conf
make status CONFIG=cluster.conf
make desktop-check    # TS build + discover/vms/workloads JSON tests
make docs
```

See [`docs/generated/MAKE-TARGETS.md`](../../generated/MAKE-TARGETS.md) for full list.

---

## Related

- [Desktop UX guide](../desktop-ux-guide.md)
- [Configuration reference](../../generated/CONFIG-REFERENCE.md)
- [Documentation hub](../../index.md)

---

_Doc version: 2026-06-06T14:21:14Z · hypercluster v0.1.0_
