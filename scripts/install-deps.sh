#!/bin/bash
# Vendored from hyper2kvm — scripts/install-deps.sh
# Source:      ../hyper2kvm-/scripts/install-deps.sh
# Last synced: 2026-04-19
# To update:   cp ../hyper2kvm-/scripts/install-deps.sh scripts/install-deps.sh
set -euo pipefail
# ============================================
# hyper2kvm — Install all dependencies
# ============================================
# Production-grade installer for govc, OVF Tool, pyvmomi,
# qemu-img, libguestfs, libvirt, OVMF, and hyper2kvm.
#
# Supports: Fedora, RHEL/CentOS, Ubuntu/Debian, openSUSE
#
# Usage:
#   sudo ./scripts/install-deps.sh          # install everything
#   sudo ./scripts/install-deps.sh --govc   # install only govc
#   sudo ./scripts/install-deps.sh --verify # check all tools
#   sudo ./scripts/install-deps.sh --all    # install everything
#
# Individual components:
#   --python   --govc    --ovftool  --pyvmomi
#   --qemu     --guestfs --libvirt  --ovmf
#   --hyper2kvm --verify
#
# Environment:
#   DRY_RUN=true    Preview without installing
#   LOG_FILE=path   Custom log path
# ============================================

trap 'echo -e "\n[FATAL] install-deps failed at line $LINENO"; exit 1' ERR

# ── Config ──
DRY_RUN="${DRY_RUN:-false}"
LOG_FILE="${LOG_FILE:-/var/log/hyper2kvm-install.log}"
START_TIME=$(date +%s)

# ── Helpers ──
info()  { echo "✅ $*"; }
warn()  { echo "⚠️ $*"; }
error() { echo "❌ $*"; }
step()  { echo "🔹$*"; }

run() {
    if [ "$DRY_RUN" = "true" ]; then
        echo "    [dry-run] $*"
    else
        "$@"
    fi
}

retry() {
    local attempts=3 delay=2
    for i in $(seq 1 "$attempts"); do
        "$@" && return 0
        warn "Attempt $i/$attempts failed, retrying in ${delay}s..."
        sleep "$delay"
        delay=$((delay * 2))
    done
    error "Failed after $attempts attempts: $*"
    return 1
}

elapsed() {
    echo "$(($(date +%s) - START_TIME))s"
}

# PEP 668: modern distros block bare pip install.
PIP_EXTRA_ARGS=""
pip_setup() {
    if python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)" 2>/dev/null; then
        local stdlib_path
        stdlib_path="$(python3 -c 'import sysconfig; print(sysconfig.get_path("stdlib"))' 2>/dev/null)"
        if [ -f "${stdlib_path}/../EXTERNALLY-MANAGED" ] 2>/dev/null; then
            PIP_EXTRA_ARGS="--break-system-packages"
        fi
    fi
}

pip_install() {
    run pip3 install $PIP_EXTRA_ARGS --quiet "$@"
}

# ── Logging ──
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || LOG_FILE="/tmp/hyper2kvm-install.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

# ── Detect distro ──
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID}"
        DISTRO_FAMILY="${ID_LIKE:-$ID}"
    else
        error "Cannot detect distribution"
        exit 1
    fi

    case "$DISTRO_ID" in
        fedora)                 PKG_MGR="dnf" ;;
        rhel|centos|rocky|alma) PKG_MGR="dnf" ;;
        ubuntu|debian|pop)      PKG_MGR="apt" ;;
        opensuse*|sles)         PKG_MGR="zypper" ;;
        *)
            if echo "$DISTRO_FAMILY" | grep -q "rhel\|fedora"; then
                PKG_MGR="dnf"
            elif echo "$DISTRO_FAMILY" | grep -q "debian"; then
                PKG_MGR="apt"
            elif echo "$DISTRO_FAMILY" | grep -q "suse"; then
                PKG_MGR="zypper"
            else
                error "Unsupported distribution: $DISTRO_ID"
                exit 1
            fi
            ;;
    esac

    info "Detected: ${DISTRO_ID} (${PKG_MGR}) — $(uname -m)"
}

# ── Python3 + pip ──
install_python() {
    if command -v python3 &>/dev/null && command -v pip3 &>/dev/null; then
        info "Python3 already installed: $(python3 --version)"
        return
    fi

    step "Installing Python3 and pip"
    case "$PKG_MGR" in
        dnf)    run dnf install -y python3 python3-pip python3-virtualenv ;;
        apt)    run apt-get update -qq && run apt-get install -y -qq python3 python3-pip python3-venv ;;
        zypper) run zypper install -y python3 python3-pip python3-virtualenv ;;
    esac
    info "Python3 installed: $(python3 --version)"
}

# ── govc ──
install_govc() {
    if command -v govc &>/dev/null; then
        info "govc already installed: $(govc version)"
        return
    fi

    step "Installing govc"
    local arch
    case "$(uname -m)" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="arm64" ;;
        *)       error "Unsupported arch: $(uname -m)"; return 1 ;;
    esac

    local url="https://github.com/vmware/govmomi/releases/latest/download/govc_Linux_${arch}.tar.gz"
    local tmpfile
    tmpfile=$(mktemp)
    retry curl -fsSL "$url" -o "$tmpfile"
    tar xzf "$tmpfile" -C /usr/local/bin govc
    rm -f "$tmpfile"
    chmod +x /usr/local/bin/govc
    info "govc installed: $(govc version)"
}

# ── OVF Tool ──
install_ovftool() {
    if command -v ovftool &>/dev/null; then
        info "OVF Tool already installed: $(ovftool --version 2>/dev/null | head -1)"
        return
    fi

    # Check if zip or bundle exists in current dir
    local installer
    installer=$(ls VMware-ovftool-*.zip 2>/dev/null | head -1)
    if [ -n "$installer" ]; then
        step "Installing OVF Tool from $installer"
        run mkdir -p /opt/ovftool
        run unzip -o "$installer" -d /opt/ovftool
        run ln -sf /opt/ovftool/ovftool /usr/local/bin/ovftool 2>/dev/null || true
        info "OVF Tool installed: $(ovftool --version 2>/dev/null | head -1)"
        return
    fi

    # Legacy bundle installer (OVF Tool 4.x)
    installer=$(ls VMware-ovftool-*.bundle 2>/dev/null | head -1)
    if [ -n "$installer" ]; then
        step "Installing OVF Tool from $installer"
        run chmod +x "$installer"
        run ./"$installer" --eulas-agreed --required
        if [ -d /opt/ovftool ]; then
            run ln -sf /opt/ovftool/ovftool /usr/local/bin/ovftool 2>/dev/null || true
            info "OVF Tool installed: $(ovftool --version 2>/dev/null | head -1)"
        fi
        return
    fi

    warn "OVF Tool: download from https://developer.broadcom.com/tools/open-virtualization-format-ovf-tool/latest"
}

# ── pyvmomi ──
install_pyvmomi() {
    if python3 -c "import pyVmomi" 2>/dev/null; then
        info "pyvmomi already installed"
        return
    fi

    step "Installing pyvmomi"
    pip_install pyvmomi
    info "pyvmomi installed"
}

# ── qemu-img ──
install_qemu() {
    if command -v qemu-img &>/dev/null; then
        info "qemu-img already installed: $(qemu-img --version | head -1)"
        return
    fi

    step "Installing qemu-img"
    case "$PKG_MGR" in
        dnf)    run dnf install -y qemu-img ;;
        apt)    run apt-get update -qq && run apt-get install -y -qq qemu-utils ;;
        zypper) run zypper install -y qemu-tools ;;
    esac
    info "qemu-img installed"
}

# ── libguestfs (recommended — auto-used for LVM/LUKS disks) ──
install_guestfs() {
    if command -v guestfish &>/dev/null && python3 -c "import guestfs" 2>/dev/null; then
        info "libguestfs + Python bindings already installed"
        return
    fi

    step "Installing libguestfs + Python bindings (recommended — auto-used for LVM/LUKS)"
    case "$PKG_MGR" in
        dnf)    run dnf install -y libguestfs-tools python3-libguestfs supermin ;;
        apt)    run apt-get update -qq && run apt-get install -y -qq libguestfs-tools python3-guestfs supermin ;;
        zypper) run zypper install -y guestfs-tools python3-libguestfs supermin ;;
    esac
    info "libguestfs installed"
}

# ── libvirt + KVM + kernel modules ──
install_libvirt() {
    if command -v virsh &>/dev/null; then
        info "libvirt already installed: $(virsh --version)"
        return
    fi

    step "Installing libvirt + KVM"
    case "$PKG_MGR" in
        dnf)
            run dnf install -y libvirt-daemon libvirt-client \
                libvirt-daemon-kvm qemu-kvm virt-install
            ;;
        apt)
            run apt-get update -qq && run apt-get install -y -qq \
                libvirt-daemon-system libvirt-clients \
                qemu-kvm virtinst
            ;;
        zypper)
            run zypper install -y libvirt libvirt-client \
                qemu-kvm virt-install
            ;;
    esac

    # Enable services
    run systemctl enable --now libvirtd 2>/dev/null || true
    run virsh net-start default 2>/dev/null || true
    run virsh net-autostart default 2>/dev/null || true

    # Load kernel modules
    step "Loading kernel modules"
    for mod in nbd kvm vhost_net; do
        if modprobe "$mod" 2>/dev/null; then
            info "Loaded: $mod"
        else
            warn "Failed to load: $mod"
        fi
    done

    # CPU-specific KVM module
    if grep -q "GenuineIntel" /proc/cpuinfo 2>/dev/null; then
        modprobe kvm_intel 2>/dev/null && info "Loaded: kvm_intel" || warn "kvm_intel failed (check BIOS VT-x)"
    elif grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
        modprobe kvm_amd 2>/dev/null && info "Loaded: kvm_amd" || warn "kvm_amd failed (check BIOS SVM)"
    fi

    # Persist modules across reboots
    cat > /etc/modules-load.d/hyper2kvm.conf << 'MODEOF'
nbd
kvm
vhost_net
MODEOF
    cat > /etc/modprobe.d/hyper2kvm-nbd.conf << 'MODEOF'
options nbd nbds_max=128 max_part=16
MODEOF

    info "libvirt + kernel modules installed"
}

# ── OVMF (UEFI firmware) ──
install_ovmf() {
    for p in /usr/share/OVMF/OVMF_CODE.fd \
             /usr/share/edk2/ovmf/OVMF_CODE.fd \
             /usr/share/qemu/ovmf-x86_64-code.bin; do
        if [ -f "$p" ]; then
            info "OVMF already installed: $p"
            return
        fi
    done

    step "Installing OVMF"
    case "$PKG_MGR" in
        dnf)    run dnf install -y edk2-ovmf ;;
        apt)    run apt-get update -qq && run apt-get install -y -qq ovmf ;;
        zypper) run zypper install -y qemu-ovmf-x86_64 ;;
    esac
    info "OVMF installed"
}

# ── mkosi (appliance VM builder) ──
install_mkosi() {
    if command -v mkosi &>/dev/null; then
        info "mkosi already installed: $(mkosi --version 2>/dev/null)"
        return
    fi

    step "Installing mkosi (from git for latest version)"
    # Install runtime deps first
    case "$PKG_MGR" in
        dnf)    run dnf install -y systemd-container bubblewrap 2>/dev/null || true ;;
        apt)    run apt-get update -qq; run apt-get install -y -qq systemd-container bubblewrap 2>/dev/null || true ;;
        zypper) run zypper install -y systemd-container 2>/dev/null || true ;;
    esac
    # Always install mkosi from git (distro packages are often too old)
    pip_install git+https://github.com/systemd/mkosi.git
    info "mkosi installed: $(mkosi --version 2>/dev/null || echo 'check PATH')"
}

# ── hyper2kvm itself ──
install_hyper2kvm() {
    if command -v h2kvmctl &>/dev/null; then
        info "hyper2kvm already installed: $(h2kvmctl --version 2>/dev/null | head -1)"
        return
    fi

    step "Installing hyper2kvm"

    # If we're inside the repo, install from source
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -f "$script_dir/pyproject.toml" ] && grep -q "hyper2kvm" "$script_dir/pyproject.toml" 2>/dev/null; then
        info "Installing from source: $script_dir"
        pip_install -e "$script_dir"
    else
        pip_install hyper2kvm
    fi
    info "hyper2kvm installed: $(h2kvmctl --version 2>/dev/null | head -1)"
}

# ── hivex + bsdtar (Windows registry access + ISO extraction) ──
install_hivex() {
    step "Installing python3-hivex + bsdtar (Windows registry + VirtIO ISO)"

    # Install system packages (hivex C library + headers + bsdtar)
    case "$PKG_MGR" in
        dnf)    run dnf install -y python3-hivex hivex-devel bsdtar 2>/dev/null || true ;;
        apt)    run apt-get update -qq && run apt-get install -y -qq python3-hivex libhivex-dev libarchive-tools 2>/dev/null || true ;;
        zypper) run zypper install -y python3-hivex hivex-devel bsdtar 2>/dev/null || true ;;
    esac

    # Find the Python that h2kvmctl uses (may differ from system python3)
    local active_py=""
    for py in python3.12 python3.11 python3.10; do
        if command -v "$py" &>/dev/null; then
            active_py="$py"
            break
        fi
    done
    active_py="${active_py:-python3}"

    # If the active Python can already import hivex, we're done
    if $active_py -c "import hivex" 2>/dev/null; then
        info "hivex + bsdtar installed ($active_py)"
        return
    fi

    # System python3-hivex targets a different Python version — rebuild from source
    if [ "$PKG_MGR" = "dnf" ] && command -v rpmbuild &>/dev/null; then
        info "Rebuilding hivex Python bindings for $active_py..."
        run dnf install -y hivex-devel "$active_py"-devel gcc make 2>/dev/null || true

        local build_dir="/tmp/hivex-build-$$"
        mkdir -p "$build_dir" && cd "$build_dir"
        dnf download --source hivex 2>/dev/null
        rpm2cpio hivex-*.src.rpm 2>/dev/null | cpio -idm 2>/dev/null
        local hivex_ver
        hivex_ver=$(rpm -q --qf '%{VERSION}' hivex 2>/dev/null)
        tar xf "hivex-${hivex_ver}.tar.gz" 2>/dev/null || tar xf hivex-*.tar.* 2>/dev/null

        if [ -d "hivex-${hivex_ver}" ]; then
            cd "hivex-${hivex_ver}"
            PYTHON="$active_py" ./configure --prefix=/usr 2>/dev/null
            make -j"$(nproc)" 2>/dev/null
            make -C python install 2>/dev/null
        fi
        rm -rf "$build_dir"
        cd /
    fi

    if $active_py -c "import hivex" 2>/dev/null; then
        info "hivex + bsdtar installed ($active_py, built from source)"
    else
        warn "hivex C extension not available for $active_py — Windows registry editing will be skipped"
    fi
}

# ── boto3 (AWS EC2 provider) ──
install_boto3() {
    if python3 -c "import boto3" 2>/dev/null; then
        info "boto3 already installed"
        return
    fi

    step "Installing boto3 (AWS EC2 provider)"
    pip_install boto3 || warn "boto3 install failed — AWS EC2 provider will not be available"
    info "boto3 installed"
}

# ── VirtIO Windows drivers ──
install_virtio_win() {
    step "Installing VirtIO Windows drivers"

    local iso="/var/lib/hyper2kvm/virtio-win.iso"
    local cache="/var/lib/hyper2kvm/virtio-win-extracted"
    local url="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"

    if [ -f "$iso" ]; then
        info "virtio-win.iso: $iso"
    else
        mkdir -p /var/lib/hyper2kvm
        info "Downloading virtio-win.iso..."
        if retry curl -fSL "$url" -o "$iso"; then
            info "virtio-win.iso installed: $iso"
        else
            warn "Download failed — Windows migrations will use SATA/e1000 fallback"
            warn "Manual: curl -fSL $url -o $iso"
            rm -f "$iso"
            return
        fi
    fi

    # Pre-extract ISO for faster Windows migrations (cached, one-time)
    if [ -d "$cache/viostor" ]; then
        info "VirtIO ISO cache: $cache (already extracted)"
    elif command -v bsdtar &>/dev/null && [ -f "$iso" ]; then
        info "Pre-extracting VirtIO ISO (one-time, cached for all future runs)..."
        rm -rf "$cache"
        mkdir -p "$cache"
        bsdtar xf "$iso" -C "$cache" 2>/dev/null || true
        if [ -d "$cache/viostor" ]; then
            stat -c %Y "$iso" > "$cache/.iso_mtime"
            info "VirtIO ISO extracted: $cache"
        else
            warn "bsdtar extraction incomplete — hyper2kvm will extract on first Windows migration"
        fi
    fi
}

# ── Verify all ──
verify_all() {
    echo ""
    step "Verification"
    local ok=0 fail=0 opt=0

    # Required tools
    for tool in h2kvmctl qemu-img qemu-nbd virsh govc; do
        if command -v "$tool" &>/dev/null; then
            info "$tool: $(command -v "$tool")"
            ok=$((ok + 1))
        else
            error "$tool: NOT FOUND"
            fail=$((fail + 1))
        fi
    done

    # Optional tools
    for tool in guestfish ovftool virt-install kubectl; do
        if command -v "$tool" &>/dev/null; then
            info "$tool: $(command -v "$tool")"
            ok=$((ok + 1))
        else
            warn "$tool: not installed (optional)"
            opt=$((opt + 1))
        fi
    done

    # pyvmomi
    if python3 -c "import pyVmomi" 2>/dev/null; then
        info "pyvmomi: OK"
        ok=$((ok + 1))
    else
        warn "pyvmomi: not installed (optional)"
        opt=$((opt + 1))
    fi

    # OVMF
    local ovmf_path=""
    for p in /usr/share/OVMF/OVMF_CODE.fd \
             /usr/share/edk2/ovmf/OVMF_CODE.fd \
             /usr/share/qemu/ovmf-x86_64-code.bin; do
        [ -f "$p" ] && ovmf_path="$p" && break
    done
    if [ -n "$ovmf_path" ]; then
        info "OVMF: $ovmf_path"
        ok=$((ok + 1))
    else
        warn "OVMF: not found"
        fail=$((fail + 1))
    fi

    # VirtIO Windows drivers
    if [ -f /var/lib/hyper2kvm/virtio-win.iso ]; then
        info "virtio-win: /var/lib/hyper2kvm/virtio-win.iso"; ok=$((ok + 1))
    else
        warn "virtio-win: not found (install with --virtio-win)"; opt=$((opt + 1))
    fi

    # nbd module
    if lsmod | grep -q "^nbd " || [ -e /dev/nbd0 ]; then
        info "nbd module: loaded"
        ok=$((ok + 1))
    else
        warn "nbd module: not loaded (run: sudo modprobe nbd)"
        fail=$((fail + 1))
    fi

    # KVM
    if [ -e /dev/kvm ]; then
        info "/dev/kvm: available"
        ok=$((ok + 1))
    else
        warn "/dev/kvm: not available (emulation only)"
    fi

    echo ""
    info "$ok components ready, $fail missing, $opt optional skipped ($(elapsed))"
}

# ── Main ──
main() {
    if [ "$(id -u)" -ne 0 ] && [ "${1:-}" != "--pyvmomi" ] && [ "${1:-}" != "--verify" ]; then
        error "Run as root: sudo $0 $*"
        exit 1
    fi

    # Setup logging (only for full installs)
    if [ $# -eq 0 ] || [ "${1:-}" = "--all" ]; then
        setup_logging
    fi

    if [ "$DRY_RUN" = "true" ]; then
        warn "DRY RUN — no changes will be made"
    fi

    detect_distro
    pip_setup

    if [ $# -eq 0 ] || [ "${1:-}" = "--all" ]; then
        echo ""
        echo "hyper2kvm Dependency Installer"
        echo ""
        install_python
        install_qemu
        install_guestfs
        install_libvirt
        install_ovmf
        install_govc
        install_pyvmomi
        install_ovftool
        install_hivex
        install_boto3
        install_hyper2kvm
        install_virtio_win
        verify_all
        return
    fi

    for arg in "$@"; do
        case "$arg" in
            --python)    install_python ;;
            --govc)      install_govc ;;
            --ovftool)   install_ovftool ;;
            --pyvmomi)   install_pyvmomi ;;
            --qemu)      install_qemu ;;
            --guestfs)   install_guestfs ;;
            --libvirt)   install_libvirt ;;
            --ovmf)      install_ovmf ;;
            --mkosi)     install_mkosi ;;
            --hivex)     install_hivex ;;
            --boto3)     install_boto3 ;;
            --hyper2kvm)   install_hyper2kvm ;;
            --virtio-win)  install_virtio_win ;;
            --verify)      verify_all ;;
            --all)         ;; # handled above
            --help|-h)
                echo "Usage: sudo $0 [--all|--verify|--govc|--qemu|--libvirt|...]"
                echo ""
                echo "Flags: --python --govc --ovftool --pyvmomi --qemu --hivex --boto3"
                echo "       --guestfs --libvirt --ovmf --mkosi --hyper2kvm --virtio-win --verify"
                echo ""
                echo "Env:   DRY_RUN=true  LOG_FILE=/path/to/log"
                exit 0
                ;;
            *)           error "Unknown option: $arg (try --help)"; exit 1 ;;
        esac
    done
}

main "$@"
