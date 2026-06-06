SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

HC      := ./hypercluster
CONFIG  ?= cluster.conf
FLAGS   ?=

# Pass CONFIG / FLAGS from make env:  make deploy CONFIG=my.conf FLAGS=-v

.PHONY: help init preflight deploy deploy-remote scale upgrade remove-node \
        fetch-kubeconfig merge-kubeconfig install-kubevirt status destroy check-deps \
        lint test-smoke test-inventory test-platform-config test-platform-json test-preflight-json test-python-pip test-local test-podman \
        test-remote dry-deploy unlock wizard desktop-dev desktop-build desktop-pkg desktop-install desktop-uninstall desktop-brand desktop-icons desktop-preflight desktop-check docs docs-venv \
        lab-setup lab-storage lab-tune lab-storage-status test-lab-config

help: ## 📖  Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'

check-deps: ## 🔍  Verify the script is executable and config exists
	@[[ -x "$(HC)" ]] || { echo "❌  $(HC) is not executable — run: chmod +x $(HC)"; exit 1; }
	@[[ -f "$(CONFIG)" ]] || { \
	  echo "✏️  $(CONFIG) not found — run: make wizard CONFIG=$(CONFIG)"; \
	  exit 1; \
	}

wizard: ## 🧙  Interactive cluster.conf generator
	$(HC) -c $(CONFIG) wizard

init: check-deps ## 🏗️   Clone Kubespray and generate inventory
	$(HC) -c $(CONFIG) $(FLAGS) init

preflight: check-deps ## 🩺  Check local tools + SSH connectivity
	$(HC) -c $(CONFIG) $(FLAGS) preflight

deploy: check-deps ## 🚀  Full end-to-end cluster deployment
	$(HC) -c $(CONFIG) $(FLAGS) deploy

deploy-remote: check-deps ## 🚀  Alias for deploy (remote k3s platform)
	$(HC) -c $(CONFIG) $(FLAGS) deploy

test-remote: check-deps ## 🧪  Platform smoke tests (k3s)
	$(HC) -c $(CONFIG) $(FLAGS) test

scale: check-deps ## ➕  Add nodes from cluster.conf to the cluster
	$(HC) -c $(CONFIG) $(FLAGS) scale

upgrade: check-deps ## ⬆️   Upgrade Kubernetes to version in cluster.conf
	$(HC) -c $(CONFIG) $(FLAGS) upgrade

remove-node: check-deps ## ➖  Remove a node  (make remove-node NODE=worker2)
	@[[ -n "$(NODE)" ]] || { echo "❌  Set NODE=<name>  e.g.  make remove-node NODE=worker2"; exit 1; }
	$(HC) -c $(CONFIG) $(FLAGS) remove-node $(NODE)

fetch-kubeconfig: check-deps ## 📥  Copy admin.conf from control-plane node
	$(HC) -c $(CONFIG) $(FLAGS) fetch-kubeconfig

merge-kubeconfig: check-deps ## 🔀  Merge cluster kubeconfig into ~/.kube/config
	$(HC) -c $(CONFIG) $(FLAGS) merge-kubeconfig

install-kubevirt: check-deps ## 🖥️   Install KubeVirt operator + CDI on the cluster
	$(HC) -c $(CONFIG) $(FLAGS) install-kubevirt

status: check-deps ## 📊  Show cluster node status (kubectl get nodes)
	$(HC) -c $(CONFIG) $(FLAGS) status

destroy: check-deps ## 💥  Destroy the cluster (requires confirmation)
	$(HC) -c $(CONFIG) $(FLAGS) destroy

unlock: check-deps ## 🔓  Remove stale per-cluster lock after a crash
	$(HC) -c $(CONFIG) $(FLAGS) unlock

lab-setup: check-deps ## 🧪  Lab setup: storage + memory tune (cluster.conf LAB_*)
	$(HC) -c $(CONFIG) $(FLAGS) lab setup

lab-storage: check-deps ## 💾  Mount secondary disk + kubevirt StorageClass
	$(HC) -c $(CONFIG) $(FLAGS) lab storage

lab-storage-status: check-deps ## 💾  Show lab storage mount and StorageClass
	$(HC) -c $(CONFIG) $(FLAGS) lab storage --status

lab-tune: check-deps ## 🧠  Scale down HA replicas on single-node lab
	$(HC) -c $(CONFIG) $(FLAGS) lab tune

test-lab-config: ## 🧪  Lab ops config unit tests
	chmod +x tests/test-lab-config.sh
	./tests/test-lab-config.sh

dry-deploy: check-deps ## 🔎  Dry-run deploy (prints plan, no changes)
	$(HC) -c $(CONFIG) $(FLAGS) -n deploy

lint: ## 🔍  Run shellcheck on all scripts
	@command -v shellcheck >/dev/null || { echo "❌  shellcheck not found — install via: brew install shellcheck"; exit 1; }
	shellcheck -S error -x hypercluster lib/*.sh scripts/*.sh

test-smoke: ## 🧪  Quick CLI smoke test (help + config validation)
	@[[ -x "$(HC)" ]] || { echo "❌  $(HC) is not executable"; exit 1; }
	$(HC) -h | grep -q "hypercluster"
	$(HC) -V
	@bash -c 'set -euo pipefail; source config/cluster.conf.example; \
	  [[ -n "$$CLUSTER_NAME" && -n "$$KUBESPRAY_VERSION" && -n "$$KUBE_VERSION" ]]'
	@echo "✅  smoke tests passed"

test-inventory: ## 🧪  Run inventory generation unit tests
	chmod +x tests/test-inventory.sh
	./tests/test-inventory.sh

test-platform-config: ## 🧪  Run k3s platform config unit tests
	chmod +x tests/test-platform-config.sh
	./tests/test-platform-config.sh

test-platform-json: ## 🧪  Run platform test JSON output unit tests
	chmod +x tests/test-platform-test-json.sh
	./tests/test-platform-test-json.sh

test-preflight-json: ## 🧪  Run preflight JSON output unit tests
	chmod +x tests/test-preflight-json.sh
	./tests/test-preflight-json.sh

test-python-pip: ## 🧪  Run pip install fallback helper unit tests
	chmod +x tests/test-python-pip.sh
	./tests/test-python-pip.sh

test-discover-json: ## 🧪  Run discover JSON output unit tests
	chmod +x tests/test-discover-json.sh
	./tests/test-discover-json.sh

test-vms-json: ## 🧪  Run vms JSON output unit tests
	chmod +x tests/test-vms-json.sh
	./tests/test-vms-json.sh

test-workloads-json: ## 🧪  Run workloads + vm create JSON unit tests
	chmod +x tests/test-workloads-json.sh
	./tests/test-workloads-json.sh

test-spec-roundtrip: ## 🧪  ClusterSpec ↔ cluster.conf roundtrip
	cd desktop && npx --yes tsx scripts/test-spec-roundtrip.ts

test-local: ## 🧪  End-to-end test via Multipass VMs (20–30 min)
	chmod +x scripts/test-local.sh
	./scripts/test-local.sh

test-podman: ## 🧪  Fast integration test via Podman containers + k3s
	chmod +x scripts/test-podman.sh
	./scripts/test-podman.sh

desktop-dev: ## 🖥️  Run Hypercluster Desktop (Tauri dev)
	npm install && npm run desktop:dev

desktop-build: ## 🖥️  Build Hypercluster Desktop .app / .dmg (macOS bundle)
	npm install && npm run desktop:build

desktop-pkg: ## 🖥️  Build Hypercluster.pkg with Zyvor EULA (macOS)
	chmod +x scripts/macos/build-hypercluster-pkg.sh scripts/macos/install-hypercluster-app.sh scripts/macos/uninstall-hypercluster-app.sh scripts/macos/Uninstall-Hypercluster.command scripts/lib/hypercluster-trial.sh
	./scripts/macos/build-hypercluster-pkg.sh

desktop-install: ## 🖥️  Install Hypercluster.app to /Applications (accept Zyvor license)
	chmod +x scripts/macos/install-hypercluster-app.sh
	./scripts/macos/install-hypercluster-app.sh

desktop-uninstall: ## 🖥️  Remove Hypercluster.app from /Applications
	chmod +x scripts/macos/uninstall-hypercluster-app.sh
	./scripts/macos/uninstall-hypercluster-app.sh

desktop-preflight: ## 🖥️  macOS Apple Silicon preflight (bash 5, tools, app arch)
	chmod +x scripts/macos/desktop-preflight.sh
	./scripts/macos/desktop-preflight.sh

desktop-brand: ## 🖥️  Sync Zyvor logos from hypersdk-web
	chmod +x scripts/macos/sync-zyvor-brand.sh
	./scripts/macos/sync-zyvor-brand.sh

desktop-icons: ## 🖥️  Regenerate app icons from app-icon.svg (Tauri)
	chmod +x scripts/macos/generate-desktop-icons.sh
	./scripts/macos/generate-desktop-icons.sh

desktop-check: ## 🖥️  Typecheck + cargo check desktop app
	cd desktop && npm install && npm run build
	cd desktop/src-tauri && cargo test -- paths::
	cd desktop/src-tauri && cargo check
	$(MAKE) test-spec-roundtrip test-discover-json test-vms-json test-workloads-json

test-desktop-ux-remote: ## 🧪  UX smoke: CLI JSON + remote libvirt/machina host
	chmod +x scripts/test-desktop-ux-remote.sh scripts/test-remote-libvirt-vm.sh
	./scripts/test-desktop-ux-remote.sh

docs-venv: ## 📚  Create Python venv for doc PDF generation
	python3 -m venv .docs-venv
	.docs-venv/bin/pip install -q --upgrade pip
	.docs-venv/bin/pip install -q -r requirements-docs.txt

docs: docs-venv ## 📚  Generate docs + PDFs (_build/, guides, welcome.html, docs/pdf/)
	chmod +x scripts/generate-docs.sh scripts/generate-doc-pdfs.py
	./scripts/generate-docs.sh

docs-serve: docs ## 📚  Serve docs locally on port 8080
	cd docs && python3 -m http.server 8080
