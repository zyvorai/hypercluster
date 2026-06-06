# hypercluster — Agent Training Guide

Version: see [VERSION](../../VERSION) · Regenerate quickref: `make docs`

This document trains AI agents to deploy, debug, extend, and document hypercluster correctly.

---

## 1. Mission

hypercluster wraps **Kubespray** and **k3s** into one `cluster.conf`-driven workflow:

- **Deployer:** laptop or bastion with bash 4+, ssh, kubectl, helm (k3s path).
- **Targets:** Linux nodes over SSH (no cloud API).
- **Output:** kubeconfig at `KUBECONFIG_OUTPUT`, optional remote `~/.kube/config`.

Agents must prefer **`./hypercluster`** over manual helm/kubectl/ssh scripts unless explicitly debugging.

---

## 2. Architecture

### Kubespray path (`K8S_DISTRO=kubespray`)

```
cluster.conf → hypercluster → clone .kubespray → inventory (hosts.yaml)
                             → ansible-playbook cluster.yml
                             → fetch kubeconfig
```

Key modules: `lib/inventory.sh`, `lib/kubespray.sh`, `lib/preflight.sh`.

### k3s platform path (`K8S_DISTRO=k3s`)

```
cluster.conf → hypercluster → SSH install k3s (no flannel/traefik/servicelb/kube-proxy)
                             → fetch kubeconfig
                             → Helm from laptop: platform-stack.sh
                             → platform-test.sh (smoke)
```

Key modules: `lib/k3s.sh`, `lib/platform-stack.sh`, `lib/platform-test.sh`, `lib/platform-tools.sh`.

### Platform stack install order (critical)

1. **Cilium** — CNI; must exist before workloads need pod→API routing.
2. **cert-manager**
3. **MetalLB** (if enabled; requires `METALLB_IP_POOL`)
4. **snapshot-controller**, **metrics-server**
5. **KubeVirt**, **CDI**, CSI, optional CNAO/SSP

After cert-manager / KubeVirt / CDI installs, **recycle pods** that started with bad CNI routes (`platform-stack.sh`).

### Desktop app

```
React UI → Tauri invoke → hypercluster.rs → bash exec hypercluster -c <conf> <cmd>
```

JSON for dashboard: `status --json`, `test --json`, `preflight --json` via `run_sync()` in `hypercluster.rs`.

Cluster **detail view**: node table (`status --json`), smoke panel (`test --json`), preflight panel (`preflight --json`). **ConfEditor** (Monaco) uses `read_cluster_conf_cmd` / `write_cluster_conf_cmd`; registry delete uses `delete_cluster_cmd` (not `destroy`).

Profiles: `./hypercluster init --profile k3s-remote` copies `config/profiles/*.conf.example`.

Registry: `~/Library/Application Support/Hypercluster/clusters.json`.

---

## 3. Configuration contract

Single source: **`cluster.conf`** (shell-sourced, gitignored).

| Variable | k3s notes |
|----------|-----------|
| `K8S_DISTRO` | `k3s` for platform path |
| `K3S_VERSION` | e.g. `v1.35.5+k3s1` (empty = latest channel) |
| `K3S_EXEC_ARGS` | Must include `--disable-kube-proxy` with Cilium |
| `PLATFORM_STACK_ENABLED` | `true` for full stack on deploy |
| `METALLB_IP_POOL` | Required when MetalLB enabled |
| `KUBEVIRT_VERSION` / `CDI_VERSION` | Tested: v1.8.x / v1.65.x on k8s v1.35.x |
| `KUBECONFIG_OUTPUT` | Laptop kubeconfig path |

Template: `config/cluster.conf.example` · Generated ref: `docs/generated/CONFIG-REFERENCE.md`.

---

## 4. CLI reference

```bash
./hypercluster -c cluster.conf <command> [args]
```

| Command | Notes |
|---------|-------|
| `wizard` | Interactive conf generator |
| `preflight` | Tools + SSH + MetalLB pool validation; `--json` |
| `deploy` | Full install; k3s skips reinstall if healthy |
| `test` | k3s smoke only; `--json`, `--full` |
| `status` | `--json` for automation |
| `destroy -f` | k3s: helm uninstall + k3s uninstall |
| `unlock` | Clear stale lock after crash |

Flags: `-c` config, `-f` force, `-n` dry-run, `-v` verbose.

---

## 5. JSON automation

### `preflight --json`

Stdout:

```json
{"ok": true, "checks": [{"name": "Command ssh", "passed": true, "detail": "/usr/bin/ssh"}]}
```

### `test --json`

Stdout:

```json
{"pass": 10, "fail": 0, "checks": [{"name": "Cilium healthy", "passed": true}]}
```

Human PASS/FAIL lines on **stderr** only.

### `status --json`

```json
{"ready": 1, "total": 1, "nodes": [{"name": "node1", "ready": true, "roles": "true"}]}
```

Desktop `hc_preflight_json` / `hc_test_json` / `hc_status_json` / `hc_health_json` parse stdout as JSON. Optional `ai_chat_cmd` for LLM (settings in app registry).

### `health --json`

```json
{"cluster":"lab","connected":true,"state":"healthy","issues":[],"summary":{"nodes_ready":1,"nodes_total":1,"pods_running":10,"pods_total":10,"pods_pending":0,"pods_failed":0,"services":5,"vms_running":0,"vms_total":0},"status":{},"workloads":{},"vms":{},"tests":null}
```

Use for dashboard fleet refresh and automation. `--with-test` runs platform smoke (k3s, slower).

---

## 6. Agent workflows

### Verify a k3s cluster is healthy

```bash
./hypercluster -c cluster.conf health --json
./hypercluster -c cluster.conf test --json 2>/dev/null
```

Expect `state: "healthy"` (or investigate `issues[]`), and `fail: 0` on full platform test.

### Fix platform stack after CNI issues

1. Confirm `K3S_EXEC_ARGS` includes `--disable-kube-proxy`.
2. Confirm Cilium installs before cert-manager in `platform-stack.sh`.
3. Re-run `./hypercluster -c cluster.conf deploy` (skips k3s if healthy).
4. Run `./hypercluster -c cluster.conf test`.

### Add a platform component

1. Extend `config/cluster.conf.example` with toggle/version vars.
2. Add install function in `lib/platform-stack.sh` in correct order.
3. Add smoke check in `lib/platform-test.sh`.
4. Update wizard or Desktop `ClusterSpec` if user-facing (`lib/wizard.sh`, `desktop/src/lib/clusterSpec.ts`, `desktop/src/lib/api.ts`).
5. Run `make test-platform-config`, `make docs`.

### Change Desktop behavior

1. **Never** shell out to helm/kubectl for lifecycle — use `run_hypercluster` / `run_sync`.
2. Update `docs/guides/desktop-ux-guide.md` and `make docs`.
3. Run `make desktop-check`.

---

## 7. Testing matrix

| Target | Command | Needs cluster |
|--------|---------|---------------|
| shellcheck | `make lint` | No |
| CLI smoke | `make test-smoke` | No |
| inventory | `make test-inventory` | No |
| platform config | `make test-platform-config` | No |
| JSON shape | `make test-platform-json` `make test-platform-health-json` | No |
| desktop | `make desktop-check` | No (includes spec roundtrip + discover/vms/workloads/ai insights JSON) |
| Podman k3s | `scripts/test-podman.sh` | Containers |
| Remote k3s | `deploy` + `test` | Remote host |

Always run unit tests before claiming a fix is complete.

---

## 8. Documentation pipeline

```bash
make docs
```

Produces:

- `docs/index.md`, `docs/welcome.html`
- `docs/generated/*` (CLI, config, make targets, **AGENT-QUICKREF**)
- `docs/pdf/*` (fpdf2 + Chrome headless for HTML decks)
- Stamped guide footers

Agents editing CLI or config **must** run `make docs` and commit generated artifacts when the user asks for doc updates.

---

## 9. Do not

- Install cert-manager before Cilium on k3s.
- Commit secrets, `cluster.conf`, or kubeconfigs.
- Use `helm`/`kubectl` in Desktop for deploy/test/destroy.
- Break `test --json` stdout purity (JSON only on stdout).
- Force k3s reinstall on every deploy without user request.
- Add large abstractions for one-line helpers.

---

## 10. Related files

| File | Role |
|------|------|
| `hypercluster` | CLI dispatch |
| `lib/platform-stack.sh` | Helm platform |
| `lib/platform-test.sh` | Smoke + JSON |
| `lib/k3s.sh` | k3s SSH install |
| `desktop/src-tauri/src/hypercluster.rs` | Process spawn |
| `desktop/src/App.tsx` | Main UI |
| `scripts/generate-docs.sh` | Doc generator |
| `scripts/generate-doc-pdfs.py` | PDF generator |
| `AGENTS.md` | Root agent summary |

---

_Doc version: hand-maintained — run `make docs` for generated quickref stamp._
