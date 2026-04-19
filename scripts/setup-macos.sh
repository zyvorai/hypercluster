#!/usr/bin/env bash
# setup-macos.sh — Install all hypercluster deployer-side dependencies on macOS.
#
# Run once on your Mac before using hypercluster or k8s-deploy.sh.
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
#   - helm          (optional, for add-on management)
#   - multipass     (lightweight Ubuntu VMs for local testing)
#   - Python modules: jinja2, netaddr (required by Kubespray)

set -euo pipefail

_ts()  { date '+%H:%M:%S'; }
info() { printf "[%s] ✅  %s\n" "$(_ts)" "$*"; }
warn() { printf "[%s] ⚠️   %s\n" "$(_ts)" "$*" >&2; }
step() { printf "\n🔷  %s\n%s\n\n" "$*" "$(printf '─%.0s' {1..50})"; }

# ── Homebrew ──────────────────────────────────────────────────────────────────
step "Homebrew"
if command -v brew &>/dev/null; then
  info "Homebrew already installed: $(brew --version | head -1)"
else
  info "Installing Homebrew …"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
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

# Add brew bash to /etc/shells and set as default if not already
if ! grep -qF "$BREW_BASH" /etc/shells 2>/dev/null; then
  warn "$BREW_BASH not in /etc/shells — adding (requires sudo)."
  echo "$BREW_BASH" | sudo tee -a /etc/shells
fi

CURRENT_SHELL=$(dscl . -read ~/ UserShell | awk '{print $2}')
if [[ "$CURRENT_SHELL" != "$BREW_BASH" ]]; then
  warn "Your login shell is $CURRENT_SHELL."
  warn "To use bash 5 as your default: chsh -s $BREW_BASH"
  warn "(Not changed automatically — run the command above if you want it.)"
fi

# Ensure brew bash is early in PATH for this session
export PATH="$(brew --prefix)/bin:$PATH"
info "Active bash: $(bash --version | head -1)"

# ── Ansible ───────────────────────────────────────────────────────────────────
step "Ansible"
if command -v ansible &>/dev/null; then
  info "Ansible already installed: $(ansible --version | head -1)"
else
  info "Installing Ansible via pip3 …"
  pip3 install --user ansible
  export PATH="$HOME/Library/Python/$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/bin:$PATH"
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

# ── helm (optional) ───────────────────────────────────────────────────────────
step "helm (optional)"
if command -v helm &>/dev/null; then
  info "helm already installed: $(helm version --short)"
else
  info "Installing helm via Homebrew …"
  brew install helm
fi

# ── multipass (local test VMs) ────────────────────────────────────────────────
step "Multipass (local test VMs)"
if command -v multipass &>/dev/null; then
  info "Multipass already installed: $(multipass version | head -1)"
else
  info "Installing Multipass …"
  brew install --cask multipass
fi

# ── Python modules (required by Kubespray) ────────────────────────────────────
step "Python modules"
for mod in jinja2 netaddr; do
  if python3 -c "import $mod" &>/dev/null; then
    info "$mod already installed."
  else
    info "Installing $mod …"
    pip3 install --user "$mod"
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
  "export PATH=\"$BREW_PREFIX/bin:\$HOME/Library/Python/$PY_VER/bin:\$PATH\""
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

# ── Summary ───────────────────────────────────────────────────────────────────
step "Summary"
declare -A checks=(
  [bash]="$BREW_PREFIX/bin/bash"
  [ansible]="$(command -v ansible 2>/dev/null || echo '')"
  [ansible-playbook]="$(command -v ansible-playbook 2>/dev/null || echo '')"
  [kubectl]="$(command -v kubectl 2>/dev/null || echo '')"
  [helm]="$(command -v helm 2>/dev/null || echo '')"
  [multipass]="$(command -v multipass 2>/dev/null || echo '')"
  [python3]="$(command -v python3 2>/dev/null || echo '')"
)
for tool in bash ansible ansible-playbook kubectl helm multipass python3; do
  if [[ -n "${checks[$tool]}" && -x "${checks[$tool]}" ]]; then
    info "$tool  →  ${checks[$tool]}"
  else
    warn "$tool  →  NOT FOUND (check PATH or re-run)"
  fi
done

echo ""
info "🎉 Setup complete. Open a new terminal (or run: source $PROFILE) then:"
printf "    cd $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)\n"
printf "    make preflight\n\n"
