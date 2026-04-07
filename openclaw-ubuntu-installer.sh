#!/bin/bash
# OpenClaw Auto-Installer for Ubuntu
# Compatible: Ubuntu 22.04, 24.04, 26.04

set -e

echo "=========================================="
echo "  OpenClaw Auto-Installer for Ubuntu"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_warn "Running as root - this is NOT recommended for security reasons"
   log_warn "Creating a non-root user is recommended"
   echo ""
   read -p "Continue anyway? (y/N): " -n 1 -r
   echo ""
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

# Detect Ubuntu version
log_info "Detecting Ubuntu version..."
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    VERSION=$VERSION_ID
    OS=$NAME
else
    log_error "Cannot detect Ubuntu version"
    exit 1
fi

log_info "Detected: $OS $VERSION"

# Check supported version
if [[ "$VERSION" != "22.04" && "$VERSION" != "24.04" && "$VERSION" != "26.04" ]]; then
    log_warn "This version may not be officially supported: $VERSION"
    log_warn "Supported: 22.04, 24.04, 26.04"
fi

# Check if already installed
if command -v openclaw &> /dev/null; then
    log_warn "OpenClaw is already installed!"
    openclaw --version
    echo ""
    read -p "Reinstall? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Update system
log_info "Updating system packages..."
sudo apt update -qq || {
    log_error "Failed to update package lists"
    log_info "Trying with more verbose output..."
    sudo apt update || exit 1
}
log_info "Upgrading system packages..."
sudo apt upgrade -y -qq || {
    log_warn "Upgrade had some issues, continuing anyway..."
}

# Install dependencies
log_info "Installing dependencies..."
DEPS=(
    curl
    git
    build-essential
    ca-certificates
)

for pkg in "${DEPS[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        log_info "Installing $pkg..."
        sudo apt install -y -qq "$pkg" || {
            log_error "Failed to install $pkg"
            exit 1
        }
    else
        log_info "$pkg already installed"
    fi
done

# Check and install Node.js 24 or 22
log_info "Checking Node.js..."

install_node() {
    local version=$1
    log_info "Installing Node.js $version..."
    
    # Add NodeSource repository
    curl -fsSL "https://deb.nodesource.com/setup_$version.x" | sudo bash - || {
        log_error "Failed to setup NodeSource for Node $version"
        return 1
    }
    
    sudo apt install -y nodejs || {
        log_error "Failed to install Node.js $version"
        return 1
    }
}

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    log_info "Found Node.js v$(node -v)"
    
    if [[ "$NODE_VERSION" -ge 24 ]]; then
        log_info "Node.js version is good (>=24)"
    elif [[ "$NODE_VERSION" -ge 22 ]]; then
        log_warn "Node.js version is 22.x - recommended is 24.x"
        log_info "Continuing with Node 22..."
    else
        log_warn "Node.js version is too old: $NODE_VERSION"
        log_info "Installing Node.js 24..."
        install_node 24
    fi
else
    log_info "Node.js not found, installing..."
    install_node 24 || install_node 22 || {
        log_error "Failed to install Node.js"
        exit 1
    }
fi

# Verify Node.js
NODE_VERSION=$(node -v)
NPM_VERSION=$(npm -v)
log_info "Node: $NODE_VERSION, npm: $NPM_VERSION"

# Install OpenClaw
log_info "Installing OpenClaw..."

# Try official installer first
if curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh; then
    log_info "Running official installer..."
    chmod +x /tmp/openclaw-install.sh
    sudo bash /tmp/openclaw-install.sh || {
        log_warn "Official installer failed, trying npm method..."
        # Fallback to npm
        npm install -g openclaw@latest || {
            log_error "npm install failed"
            log_info "Trying with SHARP ignore global libvips..."
            SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest || exit 1
        }
    }
else
    log_warn "Could not download installer, trying npm..."
    npm install -g openclaw@latest || {
        log_error "npm install failed"
        exit 1
    }
fi

# Verify installation
log_info "Verifying installation..."
if command -v openclaw &> /dev/null; then
    log_info "OpenClaw installed: $(openclaw --version)"
else
    log_error "OpenClaw command not found after installation"
    exit 1
fi

# Run doctor check
log_info "Running health check..."
openclaw doctor || log_warn "Doctor found some issues (see above)"

# Install daemon (optional)
echo ""
log_info "OpenClaw installation complete!"
echo ""
echo "To start the gateway:"
echo "  openclaw gateway start"
echo ""
echo "To run onboarding:"
echo "  openclaw onboard"
echo ""

read -p "Start gateway now? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    openclaw gateway start
    log_info "Gateway started!"
    openclaw gateway status
fi

echo ""
log_info "Installation complete! 🎉"