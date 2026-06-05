#!/usr/bin/env bash
# setup-macos.sh — Install all hypercluster deployer-side dependencies on macOS.
#
# Run once on your Mac before using hypercluster or remote-k8s-deploy.sh.
#
# Usage:
#   chmod +x scripts/setup-macos.sh
#   ./scripts/setup-macos.sh
#
# What it installs:
#   - Homebrew (if missing)
#   - bash 5        (macOS ships with bash 3.2; hypercluster needs 4.3+)
#   - ansible       (cluster deployment engine)
#   - kubectl       (cluster access)
#   - helm          (chart management)
#   - cilium CLI    (Cilium CNI management)
#   - virtctl       (KubeVirt VM management)
#   - podman        (local testing + preferred container runtime)
#   - Python modules: jinja2, netaddr (required by Kubespray)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export HYPERCLUSTER_SCRIPT_DIR="$REPO_DIR"
# shellcheck source=lib/log.sh
source "$REPO_DIR/lib/log.sh"
# shellcheck source=lib/python-pip.sh
source "$REPO_DIR/lib/python-pip.sh"

# ── Homebrew ──────────────────────────────────────────────────────────────────
step "Homebrew"
if command -v brew &>/dev/null; then
  info "Homebrew already installed: $(brew --version | head -1)"
else
  info "Installing Homebrew …"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# ── bash 5 ────────────────────────────────────────────────────────────────────
step "bash 5"
BREW_BASH="$(brew --prefix)/bin/bash"
if [[ -x "$BREW_BASH" ]]; then
  info "bash 5 already installed: $("$BREW_BASH" --version | head -1)"
else
  info "Installing bash 5 …"
  brew install bash
fi

if ! grep -qF "$BREW_BASH" /etc/shells 2>/dev/null; then
  if sudo -n true 2>/dev/null; then
    echo "$BREW_BASH" | sudo tee -a /etc/shells >/dev/null
    info "$BREW_BASH added to /etc/shells"
  else
    warn "$BREW_BASH not in /etc/shells — to add it run: echo $BREW_BASH | sudo tee -a /etc/shells"
  fi
fi

CURRENT_SHELL=$(dscl . -read ~/ UserShell | awk '{print $2}')
if [[ "$CURRENT_SHELL" != "$BREW_BASH" ]]; then
  warn "Your login shell is $CURRENT_SHELL. To use bash 5: chsh -s $BREW_BASH"
fi

export PATH="$(brew --prefix)/bin:$PATH"
info "Active bash: $(bash --version | head -1)"

# ── Ansible ───────────────────────────────────────────────────────────────────
step "Ansible"
if command -v ansible &>/dev/null; then
  info "Ansible already installed: $(ansible --version | head -1)"
else
  info "Installing Ansible via Homebrew …"
  brew install ansible
  info "Ansible installed: $(ansible --version | head -1)"
fi

# ── kubectl ───────────────────────────────────────────────────────────────────
step "kubectl"
if command -v kubectl &>/dev/null; then
  info "kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
  info "Installing kubectl via Homebrew …"
  brew install kubectl
fi

# ── helm ──────────────────────────────────────────────────────────────────────
step "helm"
if command -v helm &>/dev/null; then
  info "helm already installed: $(helm version --short)"
else
  info "Installing helm via Homebrew …"
  brew install helm
fi

# ── Cilium CLI ────────────────────────────────────────────────────────────────
step "Cilium CLI"
if command -v cilium &>/dev/null; then
  info "cilium CLI already installed: $(cilium version --client 2>/dev/null | head -1)"
else
  info "Installing Cilium CLI via Homebrew …"
  brew install cilium-cli
  info "cilium CLI installed: $(cilium version --client 2>/dev/null | head -1)"
fi

# ── virtctl (KubeVirt) ────────────────────────────────────────────────────────
step "virtctl (KubeVirt)"
if command -v virtctl &>/dev/null; then
  info "virtctl already installed: $(virtctl version --client 2>/dev/null | head -1)"
else
  info "Installing virtctl …"
  VIRTCTL_VER="v1.3.1"
  ARCH="$(uname -m)"
  [[ "$ARCH" == "arm64" ]] && ARCH="arm64" || ARCH="amd64"
  curl -L -o /tmp/virtctl \
    "https://github.com/kubevirt/kubevirt/releases/download/$VIRTCTL_VER/virtctl-$VIRTCTL_VER-darwin-$ARCH"
  chmod +x /tmp/virtctl
  sudo mv /tmp/virtctl /usr/local/bin/virtctl
  info "virtctl installed: $(virtctl version --client 2>/dev/null | head -1 || echo $VIRTCTL_VER)"
fi

# ── Podman ────────────────────────────────────────────────────────────────────
step "Podman (local testing + container runtime)"
if command -v podman &>/dev/null; then
  info "podman already installed: $(podman --version)"
else
  info "Installing Podman via Homebrew …"
  brew install podman
fi

# Init podman machine if not exists
if ! podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
  info "Initialising Podman machine …"
  podman machine init --cpus 2 --memory 2048 --disk-size 20
fi

if ! podman machine list --format '{{.LastUp}}' 2>/dev/null | grep -qi "running"; then
  info "Starting Podman machine …"
  podman machine start
fi
info "Podman machine: $(podman machine list --format '{{.Name}} {{.LastUp}}' 2>/dev/null | head -1)"

# ── Python modules (required by Kubespray) ────────────────────────────────────
# Modern macOS Python is PEP 668 "externally managed" — use --break-system-packages
step "Python modules"
for mod in jinja2 netaddr; do
  if python3 -c "import $mod" &>/dev/null; then
    info "$mod already installed."
  else
    info "Installing $mod …"
    pip::install --user "$mod"
    info "$mod installed."
  fi
done

# ── Shell profile update ──────────────────────────────────────────────────────
step "Shell profile"
PROFILE="$HOME/.zshrc"
[[ "$SHELL" == */bash ]] && PROFILE="$HOME/.bash_profile"

BREW_PREFIX="$(brew --prefix)"
PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

LINES=(
  "# hypercluster — added by setup-macos.sh"
  "export PATH=\"$BREW_PREFIX/bin:$BREW_PREFIX/opt/ansible/bin:\$HOME/Library/Python/$PY_VER/bin:/usr/local/bin:\$PATH\""
)

ALREADY_SET=true
for line in "${LINES[@]}"; do
  grep -qF "$line" "$PROFILE" 2>/dev/null || { ALREADY_SET=false; break; }
done

if [[ "$ALREADY_SET" == false ]]; then
  printf '\n%s\n%s\n' "${LINES[0]}" "${LINES[1]}" >> "$PROFILE"
  info "PATH updated in $PROFILE"
else
  info "PATH already configured in $PROFILE"
fi

# ── Summary ───────────────────────────────────────────────name───────────────
step "Summary"
declare -A checks=(
  [bash]="$BREW_PREFIX/bin/bash"
  [ansible]="$(command -v ansible 2>/dev/null || echo '')"
  [ansible-playbook]="$(command -v ansible-playbook 2>/dev/null || echo '')"
  [kubectl]="$(command -v kubectl 2>/dev/null || echo '')"
  [helm]="$(command -v helm 2>/dev/null || echo '')"
  [cilium]="$(command -v cilium 2>/dev/null || echo '')"
  [virtctl]="$(command -v virtctl 2>/dev/null || echo '')"
  [podman]="$(command -v podman 2>/dev/null || echo '')"
  [python3]="$(command -v python3 2>/dev/null || echo '')"
)
for tool in bash ansible ansible-playbook kubectl helm cilium virtctl podman python3; do
  if [[ -n "${checks[$tool]:-}" && -x "${checks[$tool]}" ]]; then
    info "$tool  →  ${checks[$tool]}"
  else
    warn "$tool  →  NOT FOUND (check PATH or re-run)"
  fi
done

echo ""
info "🎉 Setup complete. Open a new terminal (or run: source $PROFILE) then:"
printf "    cd $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)\n"
printf "    make preflight\n\n"
