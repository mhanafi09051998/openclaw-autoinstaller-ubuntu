#!/usr/bin/env bash
# OpenClaw Auto-Installer for Ubuntu
# Compatible: Ubuntu 22.04, 24.04, 26.04

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
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
log_cmd()  { echo -e "  ${CYAN}$1${NC}"; }

usage() {
    cat <<EOF
Penggunaan: ./openclaw-ubuntu-installer.sh [opsi]

Opsi:
  --upgrade-system     Jalankan apt upgrade sebelum instalasi
  --yes                Mode non-interaktif (jawab semua konfirmasi dengan ya)
  --reinstall          Lanjutkan pasang ulang jika OpenClaw sudah terpasang
  --start-gateway      Jalankan gateway secara otomatis setelah instalasi
  --log-file PATH      Simpan log ke file tertentu
  -h, --help           Tampilkan bantuan ini
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

    read -r -p "$(echo -e "${BOLD}${prompt}${NC} [${GREEN}y${NC}/${RED}N${NC}]: ")" REPLY
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

check_command() {
    local cmd=$1
    command -v "$cmd" >/dev/null 2>&1
}

check_host_connectivity() {
    local host=$1
    if curl -fsSI --connect-timeout 5 --max-time 10 "https://${host}" >/dev/null 2>&1; then
        log_info "Dapat dijangkau: ${host}"
    else
        log_warn "Tidak dapat menjangkau ${host}. Jaringan atau DNS mungkin akan menghalangi proses instalasi."
    fi
}

ensure_sudo_access() {
    if [[ $EUID -eq 0 ]]; then
        log_warn "Skrip berjalan sebagai root. Hal ini tidak disarankan untuk penggunaan VPS rutin."
        if ! confirm "Lanjutkan sebagai root?"; then
            exit 1
        fi
        return
    fi

    if ! sudo -n true >/dev/null 2>&1; then
        log_info "Akses sudo diperlukan. Anda mungkin akan diminta memasukkan kata sandi."
    fi

    sudo -v || {
        log_error "Autentikasi sudo gagal."
        exit 1
    }
}

preflight_checks() {
    log_info "Menjalankan pemeriksaan awal..."

    if [[ ! -f /etc/os-release ]]; then
        log_error "Tidak dapat mendeteksi sistem operasi."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    VERSION=${VERSION_ID:-unknown}
    OS=${NAME:-unknown}
    DISTRO_ID=${ID:-unknown}

    log_info "Sistem terdeteksi: ${OS} ${VERSION}"

    if [[ "$DISTRO_ID" != "ubuntu" ]]; then
        log_error "Installer ini hanya mendukung Ubuntu. ID distro yang terdeteksi: ${DISTRO_ID}"
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
        log_warn "Ubuntu ${VERSION} berada di luar daftar versi yang telah diuji: ${SUPPORTED_VERSIONS[*]}"
    fi

    for item in "${REQUIRED_COMMANDS[@]}"; do
        if ! check_command "$item"; then
            log_error "Perintah yang diperlukan tidak ditemukan: $item"
            exit 1
        fi
    done

    if ! apt-cache policy >/dev/null 2>&1; then
        log_error "apt-cache tidak berfungsi dengan benar."
        exit 1
    fi

    for item in "${REQUIRED_HOSTS[@]}"; do
        check_host_connectivity "$item"
    done
}

update_packages() {
    log_info "Memperbarui daftar paket..."
    sudo apt update -qq || {
        log_error "Gagal memperbarui daftar paket."
        log_info "Mencoba lagi dengan output lengkap..."
        sudo apt update
    }

    if [[ "$UPGRADE_SYSTEM" -eq 1 ]]; then
        log_info "Memutakhirkan paket sistem..."
        sudo apt upgrade -y -qq || {
            log_warn "apt upgrade mengalami masalah. Melanjutkan proses instalasi."
        }
    else
        log_info "Melewati apt upgrade secara default demi keamanan VPS."
    fi
}

install_dependencies() {
    local deps=(
        curl
        git
        build-essential
        ca-certificates
    )

    log_info "Memasang dependensi..."
    local pkg
    for pkg in "${deps[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            log_info "Memasang ${pkg}..."
            sudo apt install -y -qq "$pkg" || {
                log_error "Gagal memasang ${pkg}."
                exit 1
            }
        else
            log_info "${pkg} sudah terpasang."
        fi
    done
}

install_node() {
    local version=$1
    log_info "Memasang Node.js ${version}..."

    curl -fsSL "https://deb.nodesource.com/setup_${version}.x" | sudo bash - || {
        log_error "Gagal mengonfigurasi NodeSource untuk Node.js ${version}."
        return 1
    }

    sudo apt install -y nodejs || {
        log_error "Gagal memasang Node.js ${version}."
        return 1
    }
}

ensure_node() {
    log_info "Memeriksa Node.js..."

    if check_command node; then
        local node_major
        node_major=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        log_info "Node.js ditemukan: $(node -v)"

        if [[ "$node_major" -ge 24 ]]; then
            log_info "Versi Node.js memenuhi syarat (>=24)."
        elif [[ "$node_major" -ge 22 ]]; then
            log_warn "Node.js 22 terdeteksi. OpenClaw merekomendasikan Node.js 24."
        else
            log_warn "Versi Node.js terlalu lama: $(node -v)"
            install_node 24 || install_node 22 || {
                log_error "Gagal memasang versi Node.js yang didukung."
                exit 1
            }
        fi
    else
        log_info "Node.js tidak ditemukan. Memulai pemasangan..."
        install_node 24 || install_node 22 || {
            log_error "Gagal memasang Node.js."
            exit 1
        }
    fi

    log_info "Node: $(node -v), npm: $(npm -v)"
}

install_openclaw_with_npm() {
    if npm install -g openclaw@latest; then
        return 0
    fi

    log_warn "Mencoba lagi instalasi npm dengan sudo..."
    if sudo npm install -g openclaw@latest; then
        return 0
    fi

    log_error "Instalasi npm gagal."
    log_info "Mencoba dengan SHARP_IGNORE_GLOBAL_LIBVIPS=1..."
    sudo env SHARP_IGNORE_GLOBAL_LIBVIPS=1 npm install -g openclaw@latest || return 1
}

install_openclaw() {
    log_info "Memasang OpenClaw..."

    if curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh; then
        log_info "Menjalankan installer resmi..."
        chmod +x /tmp/openclaw-install.sh
        sudo bash /tmp/openclaw-install.sh || {
            log_warn "Installer resmi gagal. Beralih ke metode npm..."
            install_openclaw_with_npm || exit 1
        }
    else
        log_warn "Tidak dapat mengunduh installer resmi. Beralih ke metode npm..."
        install_openclaw_with_npm || exit 1
    fi
}

verify_installation() {
    log_info "Memverifikasi instalasi..."
    if ! check_command openclaw; then
        log_error "Perintah openclaw tidak ditemukan setelah proses instalasi."
        exit 1
    fi

    log_info "OpenClaw berhasil terpasang: $(openclaw --version)"
    log_info "Menjalankan pemeriksaan kesehatan sistem..."
    openclaw doctor || log_warn "Pemeriksaan melaporkan adanya masalah. Tinjau output di atas."
}

maybe_handle_existing_install() {
    if ! check_command openclaw; then
        return
    fi

    log_warn "OpenClaw sudah terpasang: $(openclaw --version)"
    if [[ "$AUTO_REINSTALL" -eq 1 ]]; then
        log_info "Melanjutkan karena opsi --reinstall diberikan."
        return
    fi

    if ! confirm "Pasang ulang OpenClaw?"; then
        exit 0
    fi
}

maybe_start_gateway() {
    echo ""
    log_info "Instalasi OpenClaw selesai!"
    echo ""
    echo -e "${BLUE}Untuk memulai gateway, jalankan:${NC}"
    log_cmd "openclaw gateway start"
    echo ""
    echo -e "${BLUE}Untuk menjalankan proses onboarding:${NC}"
    log_cmd "openclaw onboard"
    echo ""
    echo -e "${BLUE}Untuk melihat daftar slash commands yang tersedia di dalam sesi:${NC}"
    log_cmd "/help"
    log_cmd "/commands"
    echo ""

    if [[ "$AUTO_START_GATEWAY" -eq 1 ]]; then
        openclaw gateway start
        log_info "Gateway berhasil dijalankan."
        openclaw gateway status || true
        return
    fi

    if confirm "Mulai gateway sekarang?"; then
        openclaw gateway start
        log_info "Gateway berhasil dijalankan."
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
                    log_error "Opsi --log-file membutuhkan argumen berupa jalur file."
                    exit 1
                fi
                LOG_FILE=$1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Opsi tidak dikenal: $1"
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

    echo -e "${CYAN}${BOLD}==========================================${NC}"
    echo -e "${CYAN}${BOLD}  OpenClaw Auto-Installer for Ubuntu${NC}"
    echo -e "${CYAN}${BOLD}==========================================${NC}"
    echo ""
    log_info "File log: ${LOG_FILE}"

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
    log_info "Instalasi selesai!"
}

main "$@"
