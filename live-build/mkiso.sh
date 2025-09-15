#!/usr/bin/env bash
# Скрипт создания загрузочного ISO с поддержкой профилей
# Поддерживает BIOS и UEFI загрузку

set -euo pipefail

# Конфигурация
ISO_URL="${ISO_URL:-https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso}"
ISO_NAME="$(basename "$ISO_URL")"
WORKDIR="$(cd "$(dirname "$0")" && pwd)"
BUILD="$WORKDIR/build"
STAGING="$WORKDIR/staging"
DIST="$WORKDIR/dist"
OVERLAY="$WORKDIR/overlay"
PROFILES=("base" "dw" "atpm" "arm" "prizm" "akts")
PROFILE="${PROFILE:-base}"
ISO_TITLE="Ubuntu 24.04 LTS Autoinstall"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции логирования
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}" >&2
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*${NC}"
}

# Проверка зависимостей
check_dependencies() {
    local deps=("7z" "xorriso" "curl" "rsync")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing[*]}. Please install them first."
    fi
    
    log "All dependencies satisfied"
}

# Проверка прав доступа
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
    fi
    log "Running with root privileges"
}

# Создание рабочих директорий
setup_directories() {
    log "Setting up working directories..."
    
    mkdir -p "$BUILD" "$STAGING" "$DIST" "$OVERLAY"
    
    # Очистка предыдущих сборок
    if [ -d "$STAGING" ]; then
        rm -rf "$STAGING"
        mkdir -p "$STAGING"
    fi
    
    log "Working directories ready"
}

# Загрузка базового ISO
download_iso() {
    log "Checking base ISO..."
    
    if [ ! -f "$BUILD/$ISO_NAME" ]; then
        log "Downloading Ubuntu ISO: $ISO_URL"
        curl -L --progress-bar "$ISO_URL" -o "$BUILD/$ISO_NAME"
    else
        log "Using existing ISO: $BUILD/$ISO_NAME"
    fi
    
    # Проверка размера файла
    local size=$(stat -c%s "$BUILD/$ISO_NAME")
    if [ "$size" -lt 1000000000 ]; then  # Меньше 1GB
        warn "ISO file seems too small ($size bytes), might be corrupted"
    fi
    
    log "ISO ready: $(du -h "$BUILD/$ISO_NAME" | cut -f1)"
}

# Извлечение ISO
extract_iso() {
    log "Extracting base ISO..."
    
    7z x -o"$STAGING" "$BUILD/$ISO_NAME" >/dev/null 2>&1
    
    # Проверка успешности извлечения
    if [ ! -d "$STAGING/boot" ]; then
        error "Failed to extract ISO or invalid ISO structure"
    fi
    
    log "ISO extracted successfully"
}

# Подготовка overlay файлов
prepare_overlay() {
    log "Preparing overlay files..."
    
    # Создание структуры nocloud
    mkdir -p "$OVERLAY/nocloud"
    
    # Копирование autoinstall файлов
    cp "$WORKDIR/../packer/http/user-data" "$OVERLAY/nocloud/"
    cp "$WORKDIR/../packer/http/meta-data" "$OVERLAY/nocloud/"
    
    # Создание seed директории с firstboot файлами
    mkdir -p "$OVERLAY/seed"
    cp "$WORKDIR/../packer/http/seed/firstboot.service" "$OVERLAY/seed/"
    cp "$WORKDIR/../packer/http/seed/firstboot.sh" "$OVERLAY/seed/"
    
    # Копирование пост-инсталляционных скриптов
    mkdir -p "$OVERLAY/seed/postinstall-common.d"
    if [ -d "$WORKDIR/../packer/http/seed/postinstall-common.d" ]; then
        cp -r "$WORKDIR/../packer/http/seed/postinstall-common.d/"* "$OVERLAY/seed/postinstall-common.d/"
    fi
    
    # Копирование профильных скриптов
    mkdir -p "$OVERLAY/seed/profiles"
    if [ -d "$WORKDIR/../packer/http/seed/profiles" ]; then
        cp -r "$WORKDIR/../packer/http/seed/profiles/"* "$OVERLAY/seed/profiles/"
    fi
    
    log "Overlay files prepared"
}

# Создание GRUB меню с профилями
create_grub_menu() {
    log "Creating GRUB menu with profiles..."
    
    local grub_snippet="$OVERLAY/boot/grub/grub-profiles.cfg"
    mkdir -p "$(dirname "$grub_snippet")"
    
    cat > "$grub_snippet" << 'EOF'
set default=0
set timeout=10

menuentry 'Install Ubuntu 24.04 LTS (Base Profile)' {
    linux /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=base ---
    initrd /casper/initrd
}

menuentry 'Install Ubuntu 24.04 LTS (DW Profile - Data Warehouse)' {
    linux /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=dw ---
    initrd /casper/initrd
}

menuentry 'Install Ubuntu 24.04 LTS (ATPM Profile)' {
    linux /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=atpm ---
    initrd /casper/initrd
}

menuentry 'Install Ubuntu 24.04 LTS (ARM Profile)' {
    linux /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=arm ---
    initrd /casper/initrd
}

menuentry 'Install Ubuntu 24.04 LTS (Prizm Profile)' {
    linux /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=prizm ---
    initrd /casper/initrd
}

menuentry 'Install Ubuntu 24.04 LTS (AKTS Profile - with Docker)' {
    linux /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=akts ---
    initrd /casper/initrd
}

menuentry 'Manual Installation (edit kernel line to add profile=<name>)' {
    linux /casper/vmlinuz autoinstall ds=nocloud;s=/cdrom/nocloud/ ---
    initrd /casper/initrd
}

menuentry 'Try Ubuntu without installing' {
    linux /casper/vmlinuz
    initrd /casper/initrd
}
EOF

    log "GRUB menu created with ${#PROFILES[@]} profiles"
}

# Создание ISOLINUX меню (для BIOS)
create_isolinux_menu() {
    log "Creating ISOLINUX menu for BIOS boot..."
    
    if [ -f "$STAGING/isolinux/txt.cfg" ]; then
        local txt_cfg="$STAGING/isolinux/txt.cfg"
        
        # Создание нового меню
        cat > "$txt_cfg" << EOF
default base
timeout 100
prompt 1

label base
  menu label Install Ubuntu 24.04 LTS (Base Profile)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=base ---

label dw
  menu label Install Ubuntu 24.04 LTS (DW Profile - Data Warehouse)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=dw ---

label atpm
  menu label Install Ubuntu 24.04 LTS (ATPM Profile)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=atpm ---

label arm
  menu label Install Ubuntu 24.04 LTS (ARM Profile)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=arm ---

label prizm
  menu label Install Ubuntu 24.04 LTS (Prizm Profile)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=prizm ---

label akts
  menu label Install Ubuntu 24.04 LTS (AKTS Profile - with Docker)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ profile=akts ---

label manual
  menu label Manual Installation
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ ---

label live
  menu label Try Ubuntu without installing
  kernel /casper/vmlinuz
  append initrd=/casper/initrd
EOF

        log "ISOLINUX menu created"
    else
        warn "ISOLINUX configuration not found, skipping BIOS menu"
    fi
}

# Применение overlay к staging
apply_overlay() {
    log "Applying overlay to staging area..."
    
    # Копирование overlay файлов
    rsync -a "$OVERLAY/" "$STAGING/"
    
    # Обновление GRUB конфигурации
    local grub_cfg="$STAGING/boot/grub/grub.cfg"
    if [ -f "$grub_cfg" ]; then
        if ! grep -q "grub-profiles.cfg" "$grub_cfg"; then
            echo "source /boot/grub/grub-profiles.cfg" >> "$grub_cfg"
        fi
        log "GRUB configuration updated"
    else
        warn "GRUB configuration not found"
    fi
    
    log "Overlay applied successfully"
}

# Создание финального ISO
create_iso() {
    local timestamp=$(date +%Y%m%d-%H%M)
    local output_name="ubuntu-24.04-${PROFILE}-${timestamp}.iso"
    local output_path="$DIST/$output_name"
    
    log "Creating final ISO: $output_name"
    
    # Создание ISO с поддержкой BIOS и UEFI
    xorriso -as mkisofs \
        -r -V "$ISO_TITLE" \
        -o "$output_path" \
        -J -l -iso-level 3 \
        -isohybrid-gpt-basdat \
        -eltorito-boot boot/grub/i386-pc/eltorito.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -eltorito-alt-boot \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
        "$STAGING" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log "ISO created successfully: $output_path"
        
        # Информация о размере
        local size=$(du -h "$output_path" | cut -f1)
        info "ISO size: $size"
        
        # Создание контрольной суммы
        local checksum_file="$DIST/checksums-${timestamp}.txt"
        (cd "$DIST" && sha256sum "$output_name" > "$(basename "$checksum_file")")
        log "Checksum created: $(basename "$checksum_file")"
        
        # Создание символической ссылки на последнюю сборку
        (cd "$DIST" && ln -sf "$output_name" "ubuntu-24.04-${PROFILE}-latest.iso")
        
        return 0
    else
        error "Failed to create ISO"
    fi
}

# Создание манифеста сборки
create_manifest() {
    local timestamp=$(date +%Y%m%d-%H%M)
    local manifest_file="$DIST/manifest-${timestamp}.json"
    
    log "Creating build manifest..."
    
    cat > "$manifest_file" << EOF
{
  "build_info": {
    "timestamp": "$(date -Iseconds)",
    "profile": "$PROFILE",
    "base_iso": "$ISO_NAME",
    "builder_version": "1.0.0"
  },
  "system_info": {
    "builder_host": "$(hostname)",
    "builder_user": "$(whoami)",
    "builder_os": "$(lsb_release -d | cut -f2)",
    "kernel": "$(uname -r)"
  },
  "profiles_available": [
$(printf '    "%s"' "${PROFILES[0]}")
$(printf ',\n    "%s"' "${PROFILES[@]:1}")
  ],
  "components": {
    "packer": "$(packer version 2>/dev/null | head -1 || echo 'not available')",
    "ansible": "$(ansible --version 2>/dev/null | head -1 || echo 'not available')",
    "xorriso": "$(xorriso -version 2>/dev/null | head -1 || echo 'not available')"
  }
}
EOF

    log "Manifest created: $(basename "$manifest_file")"
}

# Очистка временных файлов
cleanup() {
    log "Cleaning up temporary files..."
    
    if [ -d "$STAGING" ]; then
        rm -rf "$STAGING"
    fi
    
    # Очистка старых overlay файлов
    if [ -d "$OVERLAY" ]; then
        find "$OVERLAY" -type f -name "*.tmp" -delete 2>/dev/null || true
    fi
    
    log "Cleanup completed"
}

# Проверка результата
verify_iso() {
    local iso_file="$1"
    
    log "Verifying ISO structure..."
    
    # Проверка наличия ключевых файлов
    local temp_mount=$(mktemp -d)
    mount -o loop "$iso_file" "$temp_mount" 2>/dev/null || {
        error "Failed to mount ISO for verification"
    }
    
    local required_files=(
        "nocloud/user-data"
        "nocloud/meta-data"
        "seed/firstboot.sh"
        "boot/grub/grub.cfg"
        "casper/vmlinuz"
        "casper/initrd"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [ ! -f "$temp_mount/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    umount "$temp_mount"
    rmdir "$temp_mount"
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        error "Missing required files in ISO: ${missing_files[*]}"
    fi
    
    log "ISO verification passed"
}

# Показ справки
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -p, --profile PROFILE    Build ISO for specific profile (default: base)
  -u, --iso-url URL       Use custom Ubuntu ISO URL
  -o, --output DIR        Output directory (default: ./dist)
  -c, --clean             Clean build directories before start
  -v, --verify            Verify ISO after creation
  -h, --help              Show this help message

Profiles:
$(printf "  %s\n" "${PROFILES[@]}")

Environment variables:
  ISO_URL                 Ubuntu ISO download URL
  PROFILE                 Target profile name

Examples:
  $0                      # Build base profile
  $0 -p dw               # Build DW profile
  $0 -p akts -v          # Build AKTS profile with verification
  $0 --clean -p base     # Clean build and create base profile

EOF
}

# Обработка аргументов командной строки
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -u|--iso-url)
                ISO_URL="$2"
                ISO_NAME="$(basename "$ISO_URL")"
                shift 2
                ;;
            -o|--output)
                DIST="$2"
                shift 2
                ;;
            -c|--clean)
                log "Cleaning build directories..."
                rm -rf "$BUILD" "$STAGING" "$OVERLAY"
                shift
                ;;
            -v|--verify)
                VERIFY_ISO=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Проверка валидности профиля
    if [[ ! " ${PROFILES[*]} " =~ " $PROFILE " ]]; then
        error "Invalid profile: $PROFILE. Available: ${PROFILES[*]}"
    fi
    
    log "Building profile: $PROFILE"
}

# Основная функция
main() {
    log "Starting Ubuntu 24.04 LTS ISO builder"
    log "Profile: $PROFILE"
    log "Working directory: $WORKDIR"
    
    # Проверки
    check_dependencies
    check_permissions
    
    # Подготовка
    setup_directories
    download_iso
    extract_iso
    prepare_overlay
    
    # Создание меню
    create_grub_menu
    create_isolinux_menu
    
    # Сборка
    apply_overlay
    create_iso
    create_manifest
    
    # Проверка (если запрошена)
    if [ "${VERIFY_ISO:-false}" = "true" ]; then
        local latest_iso="$DIST/ubuntu-24.04-${PROFILE}-latest.iso"
        if [ -L "$latest_iso" ]; then
            verify_iso "$(readlink -f "$latest_iso")"
        fi
    fi
    
    # Очистка
    cleanup
    
    log "Build completed successfully!"
    info "Output directory: $DIST"
    info "Latest ISO: ubuntu-24.04-${PROFILE}-latest.iso"
}

# Обработка сигналов для корректной очистки
trap cleanup EXIT INT TERM

# Запуск
parse_arguments "$@"
main
