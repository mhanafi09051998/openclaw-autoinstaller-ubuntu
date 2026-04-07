#!/usr/bin/env bash
# OpenClaw Auto-Installer for Ubuntu
# Compatible: Ubuntu 22.04, 24.04, 26.04

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Defaults
UPGRADE_SYSTEM=0
NON_INTERACTIVE=0
AUTO_REINSTALL=0
AUTO_START_GATEWAY=0
LOG_DIR="${HOME}/.openclaw-installer/logs"
LOG_FILE=""
SUPPORTED_VERSIONS=("22.04" "24.04" "26.04")
REQUIRED_COMMANDS=("curl" "sudo" "apt" "dpkg")
REQUIRED_HOSTS=("openclaw.ai" "deb.nodesource.com" "registry.npmjs.org" "github.com")

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat <<EOF
Usage: ./openclaw-ubuntu-installer.sh [options]

Options:
  --upgrade-system     Jalankan apt upgrade sebelum instalasi
  --yes                Mode non-interaktif
  --reinstall          Lanjut reinstall jika OpenClaw sudah terpasang
  --start-gateway      Jalankan gateway otomatis setelah instalasi
  --log-file PATH      Simpan log ke file tertentu
  -h, --help           Tampilkan bantuan
EOF
}

setup_logging() {
    if [[ -z "$LOG_FILE" ]]; then
        mkdir -p "$LOG_DIR"
        LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
    else
        mkdir -p "$(dirname "$LOG_FILE")"
    fi

    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

confirm() {
    local prompt=$1
    if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
        return 0
    fi

    read -r -p "$prompt (y/N): " REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

check_command() {
    local cmd=$1
    command -v "$cmd" >/dev/null 2>&1
}

check_host_connectivity() {
    local host=$1
    if curl -fsSI --connect-timeout 5 --max-time 10 "https://${host}" >/dev/null 2>&1; then
        log_info "Reachable: ${host}"
    else
        log_warn "Cannot reach ${host}. Network or DNS may block installation later."
    fi
}

ensure_sudo_access() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Running as root. This is not recommended for routine VPS usage."
        if ! confirm "Continue as root?"; then
            exit 1
        fi
        return
    fi

    if ! sudo -n true >/dev/null 2>&1; then
        log_info "Sudo access is required. You may be prompted for your password."
    fi

    sudo -v || {
        log_error "Sudo authentication failed."
        exit 1
    }
}

preflight_checks() {
    log_info "Running preflight checks..."

    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect operating system."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    VERSION=${VERSION_ID:-unknown}
    OS=${NAME:-unknown}
    DISTRO_ID=${ID:-unknown}

    log_info "Detected: ${OS} ${VERSION}"

    if [[ "$DISTRO_ID" != "ubuntu" ]]; then
        log_error "This installer only supports Ubuntu. Detected distro ID: ${DISTRO_ID}"
        exit 1
    fi

    local supported=0
    local item
    for item in "${SUPPORTED_VERSIONS[@]}"; do
        if [[ "$VERSION" == "$item" ]]; then
            supported=1
            break
        fi
    done

    if [[ "$supported" -eq 0 ]]; then
        log_warn "Ubuntu ${VERSION} is outside the tested list: ${SUPPORTED_VERSIONS[*]}"
    fi

    for item in "${REQUIRED_COMMANDS[@]}"; do
        if ! check_command "$item"; then
            log_error "Required command not found: $item"
            exit 1
        fi
    done

    if ! apt-cache policy >/dev/null 2>&1; then
        log_error "apt-cache is not working correctly."
        exit 1
    fi

    for item in "${REQUIRED_HOSTS[@]}"; do
        check_host_connectivity "$item"
    done
}

update_packages() {
    log_info "Updating package lists..."
    sudo apt update -qq || {
        log_error "Failed to update package lists."
        log_info "Retrying with verbose output..."
        sudo apt update
    }

    if [[ "$UPGRADE_SYSTEM" -eq 1 ]]; then
        log_info "Upgrading system packages..."
        sudo apt upgrade -y -qq || {
            log_warn "apt upgrade encountered issues. Continuing."
        }
    else
        log_info "Skipping apt upgrade by default for safer VPS behavior."
    fi
}

install_dependencies() {
    local deps=(
        curl
        git
        build-essential
        ca-certificates
    )

    log_info "Installing dependencies..."
    local pkg
    for pkg in "${deps[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            log_info "Installing ${pkg}..."
            sudo apt install -y -qq "$pkg" || {
                log_error "Failed to install ${pkg}"
                exit 1
            }
        else
            log_info "${pkg} already installed"
        fi
    done
}

install_node() {
    local version=$1
    log_info "Installing Node.js ${version}..."

    curl -fsSL "https://deb.nodesource.com/setup_${version}.x" | sudo bash - || {
        log_error "Failed to configure NodeSource for Node.js ${version}"
        return 1
    }

    sudo apt install -y nodejs || {
        log_error "Failed to install Node.js ${version}"
        return 1
    }
}

ensure_node() {
    log_info "Checking Node.js..."

    if check_command node; then
        local node_major
        node_major=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        log_info "Found Node.js $(node -v)"

        if [[ "$node_major" -ge 24 ]]; then
            log_info "Node.js version is acceptable (>=24)"
        elif [[ "$node_major" -ge 22 ]]; then
            log_warn "Node.js 22 detected. OpenClaw recommends Node.js 24."
        else
            log_warn "Node.js is too old: $(node -v)"
            install_node 24 || install_node 22 || {
                log_error "Failed to install a supported Node.js version."
                exit 1
            }
        fi
    else
        log_info "Node.js not found. Installing..."
        install_node 24 || install_node 22 || {
            log_error "Failed to install Node.js."
            exit 1
        }
    fi

    log_info "Node: $(node -v), npm: $(npm -v)"
}

install_openclaw_with_npm() {
    if npm install -g openclaw@latest; then
        return 0
    fi

    log_warn "Retrying npm install with sudo..."
    sudo npm install -g openclaw@latest || {
        log_error "npm install failed"
        log_info "Trying with SHARP_IGNORE_GLOBAL_LIBVIPS=1..."
        sudo env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest
    }
}

install_openclaw() {
    log_info "Installing OpenClaw..."

    if curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh; then
        log_info "Running official installer..."
        chmod +x /tmp/openclaw-install.sh
        sudo bash /tmp/openclaw-install.sh || {
            log_warn "Official installer failed. Falling back to npm..."
            install_openclaw_with_npm || exit 1
        }
    else
        log_warn "Could not download official installer. Falling back to npm..."
        install_openclaw_with_npm || exit 1
    fi
}

verify_installation() {
    log_info "Verifying installation..."
    if ! check_command openclaw; then
        log_error "OpenClaw command not found after installation."
        exit 1
    fi

    log_info "OpenClaw installed: $(openclaw --version)"
    log_info "Running health check..."
    openclaw doctor || log_warn "Doctor reported issues. Review the output above."
}

maybe_handle_existing_install() {
    if ! check_command openclaw; then
        return
    fi

    log_warn "OpenClaw is already installed: $(openclaw --version)"
    if [[ "$AUTO_REINSTALL" -eq 1 ]]; then
        log_info "Continuing because --reinstall was provided."
        return
    fi

    if ! confirm "Reinstall OpenClaw?"; then
        exit 0
    fi
}

maybe_start_gateway() {
    echo ""
    log_info "OpenClaw installation complete!"
    echo ""
    echo "To start the gateway:"
    echo "  openclaw gateway start"
    echo ""
    echo "To run onboarding:"
    echo "  openclaw onboard"
    echo ""

    if [[ "$AUTO_START_GATEWAY" -eq 1 ]]; then
        openclaw gateway start
        log_info "Gateway started."
        openclaw gateway status || true
        return
    fi

    if confirm "Start gateway now?"; then
        openclaw gateway start
        log_info "Gateway started."
        openclaw gateway status || true
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --upgrade-system)
                UPGRADE_SYSTEM=1
                ;;
            --yes)
                NON_INTERACTIVE=1
                AUTO_REINSTALL=1
                ;;
            --reinstall)
                AUTO_REINSTALL=1
                ;;
            --start-gateway)
                AUTO_START_GATEWAY=1
                ;;
            --log-file)
                shift
                if [[ $# -eq 0 ]]; then
                    log_error "--log-file requires a path."
                    exit 1
                fi
                LOG_FILE=$1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"
    setup_logging

    echo "=========================================="
    echo "  OpenClaw Auto-Installer for Ubuntu"
    echo "=========================================="
    echo ""
    log_info "Log file: ${LOG_FILE}"

    ensure_sudo_access
    preflight_checks
    maybe_handle_existing_install
    update_packages
    install_dependencies
    ensure_node
    install_openclaw
    verify_installation
    maybe_start_gateway

    echo ""
    log_info "Installation complete!"
}

main "$@"
