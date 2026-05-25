SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

HC      := ./hypercluster
CONFIG  ?= cluster.conf
FLAGS   ?=

# Pass CONFIG / FLAGS from make env:  make deploy CONFIG=my.conf FLAGS=-v

.PHONY: help init preflight deploy scale upgrade remove-node \
        fetch-kubeconfig merge-kubeconfig install-kubevirt status destroy check-deps \
        lint test-smoke test-inventory test-local test-podman dry-deploy unlock

help: ## 📖  Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'

check-deps: ## 🔍  Verify the script is executable and config exists
	@[[ -x "$(HC)" ]] || { echo "❌  $(HC) is not executable — run: chmod +x $(HC)"; exit 1; }
	@[[ -f "$(CONFIG)" ]] || { \
	  cp config/cluster.conf.example $(CONFIG); \
	  echo "✏️  $(CONFIG) created from example — edit it before continuing."; \
	  exit 1; \
	}

init: check-deps ## 🏗️   Clone Kubespray and generate inventory
	$(HC) -c $(CONFIG) $(FLAGS) init

preflight: check-deps ## 🩺  Check local tools + SSH connectivity
	$(HC) -c $(CONFIG) $(FLAGS) preflight

deploy: check-deps ## 🚀  Full end-to-end cluster deployment
	$(HC) -c $(CONFIG) $(FLAGS) deploy

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

test-local: ## 🧪  End-to-end test via Multipass VMs (20–30 min)
	chmod +x scripts/test-local.sh
	./scripts/test-local.sh

test-podman: ## 🧪  Fast integration test via Podman containers + k3s
	chmod +x scripts/test-podman.sh
	./scripts/test-podman.sh
