# hypercluster

End-to-end Kubernetes cluster lifecycle wrapper around [Kubespray](https://github.com/kubernetes-sigs/kubespray).
Deploys upstream Kubernetes with **Podman** as the container runtime, entirely over SSH — no cloud provider, no special agents on the nodes.

---

## 📋 Table of Contents

1. [How it works](#how-it-works)
2. [Prerequisites](#prerequisites)
3. [macOS setup & local testing](#macos-setup--local-testing)
4. [Remote k3s platform quickstart](#remote-k3s-platform-quickstart)
5. [Documentation](#documentation)
6. [Installation](#installation)
7. [Configuration](#configuration)
8. [Tutorial: first cluster](#tutorial-first-cluster)
   - [Step 1 — Prepare your nodes](#step-1--prepare-your-nodes)
   - [Step 2 — Create your config](#step-2--create-your-config)
   - [Step 3 — Run preflight checks](#step-3--run-preflight-checks)
   - [Step 4 — Deploy](#step-4--deploy)
   - [Step 5 — Access the cluster](#step-5--access-the-cluster)
9. [Day-2 operations](#day-2-operations)
10. [Standalone scripts (legacy)](#standalone-scripts-legacy)
11. [Command reference](#command-reference)
12. [Project layout](#project-layout)
13. [Podman notes](#podman-notes)
14. [Troubleshooting](#troubleshooting)

---

## How it works

hypercluster supports two deployment paths, selected by `K8S_DISTRO` in `cluster.conf`:

**Kubespray (default)** — upstream Kubernetes via Ansible:

```
cluster.conf  ──►  hypercluster  ──►  Kubespray (Ansible)  ──►  nodes via SSH
                        │
                        ├─ clones Kubespray into .kubespray/
                        ├─ generates hosts.yaml + group_vars from your config
                        ├─ runs cluster.yml / scale.yml / upgrade_cluster.yml
                        └─ fetches kubeconfig to your workstation
```

**k3s** — lightweight remote platform with virtualization stack (Cilium, MetalLB, KubeVirt, CDI, …):

```
cluster.conf  ──►  hypercluster  ──►  SSH to remote host
                        │
                        ├─ installs k3s (no Flannel / Traefik / servicelb)
                        ├─ fetches kubeconfig (laptop + remote ~/.kube/config)
                        ├─ Helm from laptop: cert-manager → Cilium → MetalLB → KubeVirt …
                        └─ ./hypercluster test  — automated smoke tests
```

For Kubespray, hypercluster is a **thin shell wrapper** — it delegates cluster operations to Ansible playbooks. For k3s, it orchestrates SSH bootstrap plus Helm-based platform installs from your laptop.

---

## macOS setup & local testing

### Why macOS needs extra steps

| Issue | Detail |
|-------|--------|
| **bash 3.2** | macOS ships with bash 3.2 (GPL licensing). hypercluster requires bash 4.3+ for nameref arrays (`local -n`) and associative arrays (`declare -A`). |
| **`flock` missing** | Linux locking tool not present on macOS — hypercluster uses `mkdir`-based locking instead (POSIX-portable). |
| **`ansible` missing** | Not bundled with macOS — installed via pip. |

### One-command setup

```bash
chmod +x scripts/setup-macos.sh
./scripts/setup-macos.sh
```

This script installs (via Homebrew + pip3, idempotent — safe to re-run):

| Tool | Purpose |
|------|---------|
| bash 5 | Required for nameref arrays and `declare -A` |
| ansible + ansible-playbook | Kubespray deployment engine |
| kubectl | Cluster access |
| helm | Add-on management (optional) |
| multipass | Lightweight Ubuntu VMs for local testing |
| jinja2, netaddr | Python modules required by Kubespray |

After the script finishes, open a new terminal (or `source ~/.zshrc`) to pick up the PATH changes.

### Local end-to-end test with Multipass

`scripts/test-local.sh` automates a complete local test:

1. 🖥️ Creates 3 Multipass VMs (1 control-plane + 2 workers, Ubuntu 22.04)
2. 🔑 Generates a test SSH key and injects it into every VM
3. 📋 Writes a `cluster-test.conf` from the actual VM IPs
4. 🚀 Runs `hypercluster deploy` end-to-end
5. ✅ Verifies all nodes reach `Ready` state

```bash
# Full test (20–30 min first run)
chmod +x scripts/test-local.sh
./scripts/test-local.sh

# Just create VMs and print IPs (no deploy)
./scripts/test-local.sh --vms-only

# Tear down everything when done
./scripts/test-local.sh --clean
```

After a successful test:

```bash
export KUBECONFIG=~/.kube/hc-test.yaml
kubectl get nodes -o wide
```

### Fast integration test with Podman

`scripts/test-podman.sh` uses Podman containers as SSH nodes and deploys via the **hypercluster k3s path** (`preflight` → `deploy` → `test`). No sudo required on the deployer.

| Test script | What it validates | Runtime |
|-------------|-------------------|---------|
| `scripts/test-local.sh` | Full Kubespray path via `hypercluster deploy` | 20–30 min |
| `scripts/test-podman.sh` | k3s platform path via `hypercluster deploy` + `test` | ~15–25 min |

```bash
# Fast k3s integration test (Podman containers, no sudo)
chmod +x scripts/test-podman.sh
./scripts/test-podman.sh

# Preflight SSH check only
./scripts/test-podman.sh --preflight

# Tear down containers and test config
./scripts/test-podman.sh --clean
```

### Automated checks (no VMs required)

```bash
make lint                  # shellcheck on all scripts
make test-smoke            # CLI help, version, config validation
make test-inventory        # inventory generation unit tests
make test-platform-config  # k3s platform config generation (Cilium values, etc.)
make test-platform-json    # test --json output shape (no cluster)
make desktop-check         # TypeScript + cargo check + JSON/spec tests
make docs                  # regenerate docs/ from sources
```

These run automatically in CI on every push/PR (except `make docs`, run before releases).

---

## Remote k3s platform quickstart

Deploy a full virtualization stack on a remote Linux host (AlmaLinux, Rocky, Ubuntu) from your laptop in three commands.

### Prerequisites

| Where | Requirements |
|-------|--------------|
| **Laptop** | `bash` 4+, `ssh`, `scp`, `curl`, `kubectl`, `helm` (optional: `cilium` CLI for Hubble) |
| **Remote host** | Linux with KVM (`/dev/kvm`), passwordless `sudo` for `SSH_USER`, port 6443 reachable |

### Configure

```bash
cp config/cluster.conf.example cluster.conf
$EDITOR cluster.conf
```

Key settings for a single-node remote host:

```bash
K8S_DISTRO="k3s"
CONTROL_PLANE_IPS="192.168.1.100"
SSH_USER="admin"
SSH_KEY="$HOME/.ssh/id_ed25519"
METALLB_ENABLED="true"
METALLB_IP_POOL="192.168.1.240-192.168.1.250"   # required when MetalLB enabled
PLATFORM_STACK_ENABLED="true"
KUBEVIRT_ENABLED="true"
KUBEVIRT_DISKS_PROVIDER="true"
KUBECONFIG_OUTPUT="$HOME/.kube/k3s-remote.yaml"
KUBECONFIG_MERGE_DEFAULT="false"   # set true to merge into ~/.kube/config
```

Run `./hypercluster wizard` for an interactive generator (supports k3s vs Kubespray, MetalLB pool, KubeVirt).

### Deploy and verify

```bash
./hypercluster -c cluster.conf preflight   # SSH, sudo, tools, MetalLB pool
./hypercluster -c cluster.conf deploy      # full install (skips k3s reinstall if healthy)
./hypercluster -c cluster.conf test        # automated smoke (~5 min)
./hypercluster -c cluster.conf status      # day-2 node status
```

JSON output for automation and the desktop app:

```bash
./hypercluster -c cluster.conf test --json       # stdout: {"pass", "fail", "checks"}
./hypercluster -c cluster.conf status --json     # stdout: {"ready", "total", "nodes"}
./hypercluster -c cluster.conf preflight --json
./hypercluster -c cluster.conf workloads --json  # pods + services
./hypercluster -c cluster.conf vms --json        # KubeVirt VMIs + templates
./hypercluster discover --json --source csv --csv tests/fixtures/discover-nodes.csv
./hypercluster -c cluster.conf test --json --full
```

Human-readable logs from `test --json` go to **stderr**; stdout is JSON only.

Makefile aliases:

```bash
make deploy-remote CONFIG=cluster.conf
make test-remote CONFIG=cluster.conf
```

After deploy:

- Laptop kubeconfig at `KUBECONFIG_OUTPUT`
- Remote user gets `~/.kube/config`, `kubectl`, `virtctl`, and `/usr/local/bin/cluster-info`
- Stack includes Cilium (installed **before** cert-manager), cert-manager, MetalLB, snapshot-controller, metrics-server, KubeVirt, CDI, CSI, CNAO, SSP (when charts available)
- Re-run `deploy` on a healthy cluster skips k3s reinstall; set `FORCE_K3S_REINSTALL=1` to replace the server

Extended snapshot smoke: `./hypercluster -c cluster.conf test --full`

Destroy (with `-f` to also helm-uninstall platform releases first):

```bash
./hypercluster -c cluster.conf -f destroy
```

On macOS, run `./scripts/setup-macos.sh` first (installs bash 5, helm, kubectl). The `hypercluster` shebang re-execs with Homebrew bash automatically.

---

## Documentation

| Document | Description |
|----------|-------------|
| [`docs/index.md`](docs/index.md) | Documentation hub (hyper2kvm-style) |
| [`docs/welcome.html`](docs/welcome.html) | Offline interactive doc browser |
| [`docs/pdf/`](docs/pdf/) | **Printable PDFs** (guides + presentations) |
| [`docs/PDF_INDEX.txt`](docs/PDF_INDEX.txt) | PDF catalog |
| [`docs/guides/desktop-ux-guide.md`](docs/guides/desktop-ux-guide.md) | **Desktop UX** — full UI reference |
| [`docs/guides/cli/hypercluster-guide.md`](docs/guides/cli/hypercluster-guide.md) | CLI commands, JSON, k3s workflow |
| [`AGENTS.md`](AGENTS.md) | **AI agent instructions** (start here for agents) |
| [`docs/agents/training.md`](docs/agents/training.md) | Full agent training guide |
| [`docs/generated/AGENT-QUICKREF.md`](docs/generated/AGENT-QUICKREF.md) | Auto-generated agent quickref |
| [`.cursor/rules/`](.cursor/rules/) | Cursor rules (auto-applied) |
| [`docs/generated/CLI.md`](docs/generated/CLI.md) | Auto-generated CLI help |
| [`docs/generated/CONFIG-REFERENCE.md`](docs/generated/CONFIG-REFERENCE.md) | `cluster.conf` variables |
| [`desktop/README.md`](desktop/README.md) | Desktop install |
| [`docs/client-presentations/`](docs/client-presentations/) | HTML client decks |
| [`RELEASE.md`](RELEASE.md) | Release checklist |

Regenerate from sources:

```bash
make docs          # markdown + HTML + docs/pdf/ (uses .docs-venv + fpdf2)
make docs-serve    # http://localhost:8080
```

---

## Prerequisites

### On your deployer machine (laptop / bastion host)

| Tool | Minimum version | Install |
|------|----------------|---------|
| Bash | 4.0+ | bundled on Linux; `brew install bash` on macOS |
| Ansible | 2.14+ | `pip3 install ansible` |
| Python | 3.9+ | `python3 --version` |
| Git | any | `apt install git` / `brew install git` |
| kubectl | matches cluster version | see [Step 5](#step-5--access-the-cluster) |

```bash
# Install Python dependencies (required by Kubespray)
pip3 install jinja2 netaddr

# Verify
ansible --version
python3 -c "import jinja2, netaddr; print('ok')"
```

> **macOS note:** the system Bash is 3.x. Install `brew install bash` and ensure `/opt/homebrew/bin/bash` appears before `/bin/bash` in your `PATH`, or invoke `hypercluster` with `bash hypercluster`.

### On every target node

- Linux (Ubuntu 22.04 LTS or Rocky Linux 9 recommended)
- `sudo`-capable user or direct `root` access via SSH
- Swap **disabled** (`swapoff -a` + remove from `/etc/fstab`)
- Port `6443` open between deployer and control-plane nodes
- Internet access (to pull container images and packages)

---

## Installation

```bash
git clone https://github.com/ssahani/hypercluster.git
cd hypercluster
chmod +x hypercluster
./hypercluster -h
```

From the repo root you can also use the npm shim:

```bash
npm install
npx hypercluster preflight --json
npx hypercluster init --profile k3s-remote
```

Cluster profiles live in [`config/profiles/`](config/profiles/) (`k3s-remote`, `kubespray-ha`).

### Desktop app (optional)

A Tauri-based Liquid Glass UI lives in [`desktop/`](desktop/). It runs **all** cluster operations through the `hypercluster` CLI — **Cluster Creation Studio** (`ClusterSpec` → `cluster.conf`), Quick Deploy, and a 14-section cluster cockpit (workloads, VMs, platform tests).

Install once from the repo root (npm workspaces, like the Cursor `agent` CLI):

```bash
npm install
npm run desktop          # or: npx hypercluster-desktop
```

Global install (available as `hypercluster-desktop` / `hc-desktop` anywhere):

```bash
npm install -g ./desktop
hypercluster-desktop
```

Commands:

| Command | Action |
|---------|--------|
| `hypercluster-desktop` | Start dev app (default) |
| `hypercluster-desktop build` | Build native bundle |
| `hypercluster-desktop run` | Open built `.app` |

See [`desktop/README.md`](desktop/README.md) for details.

Optionally add the CLI to your `PATH`:

```bash
export PATH="$PATH:$(pwd)"
```

---

## Configuration

All cluster settings live in a single shell-sourced file — `cluster.conf`.

### Interactive wizard

New to hypercluster? Generate a config interactively:

```bash
./hypercluster wizard
# or create config then init in one step:
./hypercluster init --wizard

# via Make
make wizard CONFIG=cluster.conf
```

The wizard prompts for cluster name, node IPs, SSH credentials, CNI plugin, container runtime, and KubeVirt.

### Manual config

```bash
cp config/cluster.conf.example cluster.conf
$EDITOR cluster.conf
```

The file is gitignored by default so secrets (SSH key paths) never end up in version control.

### Key variables

```bash
# ── Identity ─────────────────────────────────────────────────────────────────
CLUSTER_NAME="mycluster"           # used as inventory dir name and kubeconfig context

# ── Kubespray source ──────────────────────────────────────────────────────────
KUBESPRAY_VERSION="v2.30.0"        # any git tag from the Kubespray repo
KUBESPRAY_DIR=".kubespray"         # where to clone it (relative or absolute)

# ── Kubernetes ────────────────────────────────────────────────────────────────
KUBE_VERSION="v1.32.0"
CONTAINER_MANAGER="podman"         # podman | containerd | docker
CNI_PLUGIN="calico"                # calico | cilium | flannel | kube-ovn

KUBE_PODS_SUBNET="10.233.64.0/18"
KUBE_SERVICE_ADDRESSES="10.233.0.0/18"

# ── SSH access ────────────────────────────────────────────────────────────────
SSH_USER="root"
SSH_KEY="$HOME/.ssh/id_rsa"
SSH_EXTRA_ARGS=""                   # e.g. "-o ProxyJump=bastion"

# ── Nodes (space-separated IPs) ───────────────────────────────────────────────
CONTROL_PLANE_IPS="192.168.1.100"
WORKER_IPS="192.168.1.101 192.168.1.102"

# ── Add-ons ───────────────────────────────────────────────────────────────────
METRICS_SERVER_ENABLED="true"
INGRESS_NGINX_ENABLED="false"
DASHBOARD_ENABLED="false"

# ── Output ────────────────────────────────────────────────────────────────────
KUBECONFIG_OUTPUT="$HOME/.kube/${CLUSTER_NAME}.yaml"
```

### CIDR planning

The pod and service subnets must **not overlap** with your node network.

| Your node network | Safe pods subnet | Safe service subnet |
|---|---|---|
| `192.168.0.0/16` | `10.233.64.0/18` ✅ | `10.233.0.0/18` ✅ |
| `10.233.0.0/16` ⚠️ | pick `172.16.0.0/18` | pick `172.16.64.0/18` |
| `10.0.0.0/8` ⚠️ | pick `192.168.64.0/18` | pick `192.168.0.0/18` |

---

## Tutorial: first cluster

This tutorial deploys a 3-node cluster:

| Role | IP |
|------|-----|
| Control plane | `192.168.1.100` |
| Worker 1 | `192.168.1.101` |
| Worker 2 | `192.168.1.102` |

### Step 1 — Prepare your nodes

Run the following on **each node** (or automate it with your provisioning tool):

```bash
# Disable swap (Kubernetes requires this)
swapoff -a
sed -i '/swap/d' /etc/fstab

# Ensure time sync is running (kubelet is sensitive to clock skew)
systemctl enable --now chronyd   # or systemd-timesyncd

# Open required ports (if using firewalld)
firewall-cmd --permanent --add-port=6443/tcp   # API server
firewall-cmd --permanent --add-port=2379-2380/tcp  # etcd
firewall-cmd --permanent --add-port=10250/tcp  # kubelet
firewall-cmd --reload

# Or simply disable the firewall for a lab environment
systemctl stop firewalld && systemctl disable firewalld
```

Set up **passwordless SSH** from your deployer machine:

```bash
# Generate a key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/id_hypercluster -C "hypercluster deployer"

# Copy it to each node
for ip in 192.168.1.100 192.168.1.101 192.168.1.102; do
  ssh-copy-id -i ~/.ssh/id_hypercluster.pub root@$ip
done

# Verify
ssh -i ~/.ssh/id_hypercluster root@192.168.1.100 "hostname"
```

---

### Step 2 — Create your config

```bash
cp config/cluster.conf.example cluster.conf
```

Edit `cluster.conf` with your values:

```bash
CLUSTER_NAME="mycluster"
KUBESPRAY_VERSION="v2.30.0"
KUBE_VERSION="v1.32.0"
CONTAINER_MANAGER="podman"
CNI_PLUGIN="calico"

KUBE_PODS_SUBNET="10.233.64.0/18"
KUBE_SERVICE_ADDRESSES="10.233.0.0/18"

SSH_USER="root"
SSH_KEY="$HOME/.ssh/id_hypercluster"

CONTROL_PLANE_IPS="192.168.1.100"
WORKER_IPS="192.168.1.101 192.168.1.102"

METRICS_SERVER_ENABLED="true"
INGRESS_NGINX_ENABLED="false"
DASHBOARD_ENABLED="false"

KUBECONFIG_OUTPUT="$HOME/.kube/mycluster.yaml"
```

> **HA control plane:** set `CONTROL_PLANE_IPS` to 3 (or 5) IPs separated by spaces.
> hypercluster will put all of them in `kube_control_plane` and `etcd` groups automatically.

---

### Step 3 — Run preflight checks

```bash
make preflight
# or:  ./hypercluster preflight
```

This will:

1. ✅ Check that `ansible`, `ansible-playbook`, `python3`, `ssh`, `scp`, `git` are on your `PATH`
2. ✅ Check that Python modules `jinja2` and `netaddr` are importable
3. ✅ Check and fix SSH key permissions (`chmod 600`)
4. ✅ Open an SSH connection to every node and verify it responds

Example output:

```
🔷  Preflight checks
────────────────────────────────────────────────────────────

[10:42:01] ➜  Testing SSH → root@192.168.1.100 …
[10:42:01] ✅  root@192.168.1.100 reachable
[10:42:02] ➜  Testing SSH → root@192.168.1.101 …
[10:42:02] ✅  root@192.168.1.101 reachable
[10:42:03] ➜  Testing SSH → root@192.168.1.102 …
[10:42:03] ✅  root@192.168.1.102 reachable
[10:42:03] ✅  Preflight passed. 🚀
```

Fix any failures before proceeding — the preflight output tells you exactly what is missing.

---

### Step 4 — Deploy

```bash
make deploy
# or:  ./hypercluster deploy
```

`deploy` runs four stages in sequence:

| Stage | What happens |
|-------|-------------|
| **preflight** | Verifies local tools and SSH connectivity to all nodes |
| **init** | Clones Kubespray at `KUBESPRAY_VERSION`, installs Python requirements, generates `hosts.yaml` and `group_vars` from your config |
| **cluster.yml** | Kubespray's main playbook — installs Podman, bootstraps etcd, initialises the control plane with kubeadm, joins workers, deploys Cilium (or your configured CNI), CoreDNS, metrics-server |
| **fetch-kubeconfig** | Copies `admin.conf` from the first control-plane node and patches the server address |

Typical runtime: **15–30 minutes** depending on node speed and network.

You can watch progress in real time; pass `-v` for full Ansible output:

```bash
./hypercluster -v deploy
# or
make deploy FLAGS=-v
```

To test the config path without touching nodes:

```bash
make dry-deploy          # skips all playbook + scp calls
```

During a real deploy, hypercluster shows **stage progress** (1/4 … 4/4) and a **spinner** while Kubespray runs (when stdout is a TTY). Use `-v` for full Ansible output instead.

After a successful deploy, a **Next steps** section lists kubeconfig export, Cilium/Hubble, KubeVirt, and dashboard commands tailored to your config.

---

### Step 5 — Access the cluster

After a successful deploy, hypercluster prints:

```
[10:58:44] ✅  kubeconfig saved → /Users/you/.kube/mycluster.yaml
[10:58:44] ➜  To use:
    export KUBECONFIG=/Users/you/.kube/mycluster.yaml
    kubectl get nodes
```

```bash
export KUBECONFIG=~/.kube/mycluster.yaml
kubectl get nodes -o wide
```

Expected output:

```
NAME      STATUS   ROLES           AGE   VERSION   INTERNAL-IP     OS-IMAGE
master1   Ready    control-plane   5m    v1.32.0   192.168.1.100   Ubuntu 22.04
worker1   Ready    <none>          4m    v1.32.0   192.168.1.101   Ubuntu 22.04
worker2   Ready    <none>          4m    v1.32.0   192.168.1.102   Ubuntu 22.04
```

#### Install kubectl (if not already installed)

```bash
# Linux
curl -LO "https://dl.k8s.io/release/v1.32.0/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# macOS
brew install kubectl
```

#### Merge into the default kubeconfig

If you manage multiple clusters and want them all in `~/.kube/config`:

```bash
make merge-kubeconfig
# then switch contexts with:
kubectl config use-context mycluster
```

#### Verify add-ons

```bash
# metrics-server
kubectl top nodes

# CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Cilium (default CNI)
kubectl get pods -n kube-system -l k8s-app=cilium
```

---

## Day-2 operations

### Add worker nodes

1. Add the new IP(s) to `WORKER_IPS` in `cluster.conf`.
2. Ensure SSH access is configured on the new node (same key, same user).
3. Run:

```bash
make scale
# or:  ./hypercluster scale
```

`scale` regenerates `hosts.yaml` from the updated config and then runs `scale.yml`, which only touches nodes not yet in the cluster.

---

### Upgrade Kubernetes

1. Update `KUBE_VERSION` in `cluster.conf` (e.g. `v1.32.0` → `v1.33.0`).
2. Optionally update `KUBESPRAY_VERSION` to a release that supports the new Kubernetes version.
3. Run:

```bash
make upgrade
# or:  ./hypercluster upgrade
```

Kubespray upgrades nodes one at a time: it cordons each node, drains it, upgrades the components, then uncordons it. Workloads keep running as long as you have replicas spread across nodes.

> ⚠️ **Skip no minor versions.** Kubernetes only supports upgrading one minor version at a time (e.g. 1.30 → 1.31 → 1.32). Never jump 1.30 → 1.32 directly.

---

### Remove a node

**Graceful removal** (drains pods first — recommended):

```bash
make remove-node NODE=worker2
# or:  ./hypercluster remove-node worker2
```

**Forced removal** (skips drain — use only if node is already dead):

```bash
./hypercluster -f remove-node worker2
```

After removal, update `WORKER_IPS` in `cluster.conf` to keep it in sync with the actual cluster state.

---

### Destroy the cluster

Runs Kubespray's `reset.yml`, which uninstalls all Kubernetes components and reverts node configuration. **This is irreversible.**

```bash
make destroy
# or:  ./hypercluster destroy
```

You will be prompted to type the cluster name to confirm:

```
Type the cluster name to confirm destruction (mycluster): mycluster
```

Skip the prompt (for CI pipelines):

```bash
./hypercluster -f destroy
```

---

## Command reference

### CLI flags

| Flag | Meaning |
|------|---------|
| `-c <file>` | Config file path (default: `./cluster.conf`) |
| `-f` | Force: overwrite existing inventory; ungraceful node removal; skip destroy confirmation |
| `-n` | Dry run: skip all playbook and scp calls |
| `-v` | Verbose Ansible output |
| `-h` | Show help |

### Commands

| Command | Make target | Description |
|---------|------------|-------------|
| `init` | `make init` | Clone Kubespray + generate inventory |
| `wizard` | `make wizard` | Interactive cluster.conf generator |
| `preflight` | `make preflight` | Check local tools + SSH connectivity |
| `deploy` | `make deploy` | Full deployment (Kubespray or k3s platform) |
| `deploy` | `make deploy-remote` | Alias for deploy (k3s remote platform) |
| `test` | `make test-remote` | Platform smoke tests (k3s only; `--full`, `--json`) |
| `scale` | `make scale` | Add nodes from updated config |
| `upgrade` | `make upgrade` | Upgrade to `KUBE_VERSION` |
| `remove-node <name>` | `make remove-node NODE=<name>` | Drain and remove one node |
| `fetch-kubeconfig` | `make fetch-kubeconfig` | Copy admin.conf from first control-plane node |
| `merge-kubeconfig` | `make merge-kubeconfig` | Merge into `~/.kube/config` |
| `status` | `make status` | Node status (`--json` for automation) |
| `destroy` | `make destroy` | Reset the cluster |
| `unlock` | `make unlock` | Remove stale per-cluster lock after a crash |

### JSON output (`test --json`, `status --json`)

| Field | Command | Meaning |
|-------|---------|---------|
| `pass` / `fail` | `test --json` | Count of passed / failed checks |
| `checks[]` | `test --json` | `{name, passed}` per smoke test |
| `ready` / `total` | `status --json` | Ready node count / total nodes |
| `nodes[]` | `status --json` | `{name, ready, roles}` per node |

### Version

```bash
./hypercluster -V
# or read VERSION file at repo root
```

### Multiple clusters / environments

```bash
# Production cluster
./hypercluster -c prod.conf deploy

# Staging cluster
./hypercluster -c staging.conf deploy

# Or with Make
make deploy CONFIG=prod.conf
make status CONFIG=prod.conf

make deploy CONFIG=staging.conf FLAGS=-v
```

---

## Project layout

```
hypercluster/
├── hypercluster                  ← CLI entrypoint (chmod +x)
├── Makefile                      ← convenience targets (deploy, lint, test-smoke, docs, …)
├── package.json                  ← npm workspaces (desktop launcher)
├── VERSION                       ← release version (shown by hypercluster -V)
├── cluster.conf                  ← your config (gitignored)
├── .gitignore
├── docs/
│   ├── README.md                 ← documentation index
│   ├── generated/                ← auto-generated (make docs)
│   └── client-presentations/     ← HTML client decks
├── desktop/                      ← Tauri 2 + React desktop app
├── config/
│   ├── cluster.conf.example      ← template — copy and edit
│   └── k3s/                      ← Helm values templates (Cilium, KubeVirt, CDI)
├── lib/
│   ├── log.sh                    ← emoji logging (info/ok/warn/error/section/debug)
│   ├── preflight.sh              ← dependency + SSH key + connectivity checks
│   ├── inventory.sh              ← hosts.yaml + group_vars generation
│   ├── kubespray.sh              ← Kubespray clone + playbook runner
│   ├── k3s.sh                    ← k3s SSH install, remote kubeconfig, destroy
│   ├── platform-stack.sh         ← Helm platform stack (Cilium, KubeVirt, …)
│   ├── platform-tools.sh         ← remote kubectl/virtctl/cluster-info
│   ├── platform-test.sh          ← k3s platform smoke tests (+ --json)
│   ├── kubeconfig.sh             ← kubeconfig fetch + merge
│   ├── wizard.sh                 ← interactive cluster.conf generator
│   ├── progress.sh               ← deploy stage + spinner (TTY)
│   └── postdeploy.sh             ← post-deploy next-step hints
├── tests/
│   ├── test-inventory.sh         ← unit tests for inventory generation
│   ├── test-platform-config.sh   ← k3s platform config unit tests
│   └── test-platform-test-json.sh ← test --json output unit tests
└── scripts/
    ├── generate-docs.sh          ← regenerate docs/ from sources
    ├── remote-k8s-deploy.sh      ← legacy standalone k3s/kubeadm deployer
    ├── remote-k3s-deploy.sh      ← legacy single-host k3s + Cilium + KubeVirt
    ├── install-deps.sh           ← KVM/virt host dependency installer (hyper2kvm)
    ├── setup-macos.sh            ← install all deployer-side deps on macOS
    ├── test-local.sh             ← Kubespray E2E test using Multipass VMs
    ├── test-podman.sh            ← fast k3s integration test using Podman containers
    ├── entrypoint.sh             ← container entrypoint helper (test harness)
    ├── Dockerfile.node           ← systemd-enabled Ubuntu image for container tests
    └── zyvor-branding/           ← shared Zyvor product branding assets
```

**Generated at runtime (gitignored):**

```
.kubespray/                       ← Kubespray checkout
.kubespray-venv/                  ← isolated Python venv for Ansible deps
.kubespray/inventory/mycluster/
    hosts.yaml                    ← generated from CONTROL_PLANE_IPS / WORKER_IPS
    group_vars/
        all/all.yml               ← SSH user + key
        k8s_cluster/
            k8s-cluster.yml       ← kube version, container runtime, CNI, CIDRs
            addons.yml            ← metrics-server, ingress, dashboard
    artifacts/
        admin.conf                ← written by Kubespray after deploy
```

---

## Podman notes

Kubernetes requires a CRI-compatible container runtime. Podman supports this via `cri-o` (which Kubespray installs as the CRI shim when `container_manager: podman` is set).

| Concern | How hypercluster handles it |
|---------|----------------------------|
| Rootful vs rootless | Kubespray configures Podman in rootful mode via systemd — required by kubelet |
| Cgroup driver | `kubelet_cgroup_driver: systemd` is set in generated `k8s-cluster.yml` |
| CNI conflict | Podman's built-in network is disabled; the Kubernetes CNI plugin (Cilium by default) owns all pod networking |
| Image pulls | Podman pulls images the same way containerd does — no configuration change needed |

To use a different runtime, set `CONTAINER_MANAGER` in `cluster.conf`:

```bash
CONTAINER_MANAGER="containerd"   # production default upstream
CONTAINER_MANAGER="docker"       # legacy; not recommended for new clusters
```

---

## Troubleshooting

### ❌ `Config file not found: ./cluster.conf`

```bash
cp config/cluster.conf.example cluster.conf
$EDITOR cluster.conf
```

### ❌ `Missing required variables in cluster.conf: SSH_KEY CONTROL_PLANE_IPS`

Open `cluster.conf` — those variables are either commented out or left as empty strings. All variables in the "required" list must be set to non-empty values.

### ❌ `Another hypercluster instance is already running`

If a previous run crashed, the lock directory may be stale:

```bash
./hypercluster unlock
# or: make unlock
```

If the lock dir exists without a PID file, remove it manually:

```bash
rm -rf /tmp/hypercluster-<CLUSTER_NAME>.lock
```

### ❌ SSH connectivity check fails

```
[10:42:01] ❌  Cannot reach root@192.168.1.101
```

Check in order:
1. Can you ping the node? `ping 192.168.1.101`
2. Does the SSH key match what was copied to the node? `ssh -i "$SSH_KEY" root@192.168.1.101`
3. Is `SSH_USER` correct? (e.g. `ubuntu` on Ubuntu cloud images, not `root`)
4. Is port 22 open? `nc -zv 192.168.1.101 22`
5. Add `-o StrictHostKeyChecking=no` to `SSH_EXTRA_ARGS` if the host key has changed.

### ❌ `Inventory already exists`

You already ran `init` or `deploy`. To regenerate from your current `cluster.conf`:

```bash
./hypercluster -f init
```

### ❌ `pip3 install failed`

Kubespray dependencies are installed into an isolated venv at `.kubespray-venv/`:

```bash
source .kubespray-venv/bin/activate
pip install --upgrade pip
pip install -r .kubespray/requirements.txt
```

### ❌ kubeadm times out waiting for API server

Usually a firewall issue. On the control-plane node:

```bash
# Disable firewall temporarily to test
systemctl stop firewalld
# Retry deploy, then re-enable and configure rules properly
```

### ❌ Podman error: `cannot create cgroup`

cgroup v2 is not properly enabled. Add the following to the kernel command line and reboot:

```
systemd.unified_cgroup_hierarchy=1
```

On GRUB-based systems:

```bash
grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"
reboot
```

### 🐛 Enable debug logging

```bash
./hypercluster -v deploy          # verbose Ansible output
VERBOSE=1 ./hypercluster deploy   # also enables log::debug messages in lib/
```

---

## Standalone scripts (legacy)

> **Prefer `./hypercluster` with `K8S_DISTRO=k3s`** for remote k3s platform deploys. The scripts below are kept for reference and one-off use; they are not the canonical path.

`scripts/remote-k3s-deploy.sh` and `scripts/remote-k8s-deploy.sh` are self-contained alternatives that predate the integrated k3s workflow in hypercluster.

### What it does

1. **Installs host dependencies** via `scripts/install-deps.sh` — libvirt, QEMU, govc, pyvmomi, and the rest of the KVM/virtualization toolchain needed to manage the VMs that will become your cluster nodes.
2. **Installs the container runtime** (Podman or Docker) on every node over SSH.
3. **Deploys Kubernetes** — either k3s (single `curl | sh` per node) or kubeadm (full upstream bootstrap).
4. **Fetches and merges kubeconfig** to your local `~/.kube/config`.

### Quick start

```bash
# Edit the CONFIGURATION block at the top of the script
$EDITOR scripts/remote-k8s-deploy.sh

chmod +x scripts/remote-k8s-deploy.sh
./scripts/remote-k8s-deploy.sh
```

### Key configuration variables

```bash
MASTER_IP="192.168.1.100"
WORKERS=("192.168.1.101:root:~/.ssh/id_rsa" "192.168.1.102:root:~/.ssh/id_rsa")

K8S_DISTRO="k3s"           # "k3s" or "kubeadm"
CONTAINER_RUNTIME="podman" # "podman", "docker", or "none"

# Host dependency installer (bundled copy of hyper2kvm install-deps.sh)
INSTALL_HYPER2KVM_DEPS=true
HYPER2KVM_DEPS_SCRIPT="./install-deps.sh"   # relative to scripts/
```

Set `INSTALL_HYPER2KVM_DEPS=false` to skip the host dependency step if your deployer machine already has libvirt/QEMU installed.

### `scripts/install-deps.sh`

This is a copy of the [hyper2kvm](https://github.com/ssahani/hyper2kvm) dependency installer, bundled here for self-contained operation. It installs:

| Component | Purpose |
|-----------|---------|
| `qemu-img` / `qemu-nbd` | Disk image conversion and NBD mounting |
| `libvirt` + `KVM` | VM lifecycle management |
| `OVMF` | UEFI firmware for VMs |
| `govc` | VMware vSphere CLI |
| `pyvmomi` | VMware Python SDK |
| `libguestfs` | Guest filesystem access (LVM/LUKS) |
| `hivex` + `bsdtar` | Windows registry editing + ISO extraction |
| `boto3` | AWS EC2 provider support |
| VirtIO Windows drivers | Paravirtual drivers for Windows VMs |

Run it standalone to set up just the host tools:

```bash
# Install everything
sudo ./scripts/install-deps.sh

# Install specific components
sudo ./scripts/install-deps.sh --govc --libvirt --qemu

# Verify what is installed
sudo ./scripts/install-deps.sh --verify

# Preview without making changes
DRY_RUN=true sudo ./scripts/install-deps.sh
```

### When to use which deploy path

| Path | Best for |
|------|----------|
| **`hypercluster` + Kubespray** | Production upstream Kubernetes, HA control plane, day-2 ops (scale/upgrade/remove-node) |
| **`hypercluster` + k3s** | Remote virtualization platform (Cilium, MetalLB, KubeVirt, CDI, automated `test`) — **preferred over legacy scripts** |
| **`remote-k8s-deploy.sh`** *(legacy)* | Quick k3s or kubeadm without Ansible; config-in-script |
| **`remote-k3s-deploy.sh`** *(legacy)* | Single-node k3s + Cilium + KubeVirt + CDI (superseded by hypercluster k3s) |

### Comparison: deploy paths

| | `hypercluster` k3s | `remote-k3s-deploy.sh` | `hypercluster` Kubespray |
|---|---|---|---|
| Setup time | ~20–40 min | ~10 min | ~15–30 min (first run) |
| Kubernetes flavour | k3s | k3s only | Upstream (kubeadm) |
| Full platform stack | ✅ Helm + smoke `test` | ⚠️ partial | ✅ optional KubeVirt |
| MetalLB + snapshots | ✅ | ❌ | via add-ons |
| Remote CLI tools | ✅ kubectl/virtctl/cluster-info | ❌ | ❌ |
| Idempotent re-runs | ✅ | ⚠️ partial | ✅ full |
| Day-2 operations | status / test / destroy | ❌ manual | scale / upgrade / remove-node |

---

## Releases

Version is tracked in the [`VERSION`](VERSION) file and shown by `./hypercluster -V`.

**Release process:**

1. Update `VERSION` (semver, e.g. `0.1.0`)
2. Verify tested version combo in `config/cluster.conf.example` (Kubespray + Kubernetes)
3. Run `make lint && make test-smoke && make test-inventory`
4. Tag: `git tag -a v0.1.0 -m "v0.1.0"`
5. Push tag and create a GitHub Release noting supported Kubespray/K8s versions

**Current defaults** (see `config/cluster.conf.example`):

| Component | Version |
|-----------|---------|
| Kubespray | v2.30.0 |
| Kubernetes | v1.32.0 |
| KubeVirt | v1.3.1 |
| CDI | v1.59.0 |
## License

**Proprietary — ZyvorAI Labs Private Limited** ([zyvor.dev](https://zyvor.dev)). All rights reserved. See [LICENSE](LICENSE). No redistribution without written permission.
