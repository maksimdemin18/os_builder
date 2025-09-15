#!/usr/bin/env bash
# Скрипт для тестирования созданных ISO образов

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QEMU_MEMORY="${QEMU_MEMORY:-2048}"
QEMU_CPUS="${QEMU_CPUS:-2}"
QEMU_DISK_SIZE="${QEMU_DISK_SIZE:-20G}"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}" >&2
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*${NC}"
}

# Проверка зависимостей
check_dependencies() {
    local deps=("qemu-system-x86_64" "qemu-img")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        error "Install with: sudo apt-get install qemu-kvm qemu-utils"
        exit 1
    fi
    
    # Проверка KVM
    if [ -r /dev/kvm ]; then
        log "KVM acceleration available"
        QEMU_ACCEL="-enable-kvm"
    else
        warn "KVM not available, using software emulation (slower)"
        QEMU_ACCEL=""
    fi
}

# Создание тестового диска
create_test_disk() {
    local disk_path="$1"
    
    if [ ! -f "$disk_path" ]; then
        log "Creating test disk: $disk_path ($QEMU_DISK_SIZE)"
        qemu-img create -f qcow2 "$disk_path" "$QEMU_DISK_SIZE" >/dev/null
    else
        info "Using existing test disk: $disk_path"
    fi
}

# Тестирование ISO в QEMU
test_iso_boot() {
    local iso_path="$1"
    local profile="$2"
    local test_type="${3:-boot}"  # boot, install, full
    
    log "Testing ISO: $(basename "$iso_path") (profile: $profile, test: $test_type)"
    
    local test_dir="$SCRIPT_DIR/test-results"
    mkdir -p "$test_dir"
    
    local disk_path="$test_dir/test-disk-${profile}.qcow2"
    local log_file="$test_dir/test-${profile}-${test_type}.log"
    local screenshot_path="$test_dir/screenshot-${profile}-${test_type}.ppm"
    
    create_test_disk "$disk_path"
    
    local qemu_args=(
        -m "$QEMU_MEMORY"
        -smp "$QEMU_CPUS"
        -cdrom "$iso_path"
        -drive "file=$disk_path,format=qcow2,if=virtio"
        -netdev user,id=net0
        -device virtio-net,netdev=net0
        -display none
        -serial "file:$log_file"
        -monitor stdio
    )
    
    if [ -n "$QEMU_ACCEL" ]; then
        qemu_args+=($QEMU_ACCEL)
    fi
    
    case "$test_type" in
        "boot")
            # Тест загрузки (30 секунд)
            info "Testing boot process (30s timeout)..."
            timeout 30s qemu-system-x86_64 "${qemu_args[@]}" -boot d || {
                local exit_code=$?
                if [ $exit_code -eq 124 ]; then
                    log "Boot test completed (timeout reached)"
                else
                    error "Boot test failed with exit code $exit_code"
                    return 1
                fi
            }
            ;;
        "install")
            # Тест автоматической установки (20 минут)
            info "Testing automatic installation (20m timeout)..."
            timeout 1200s qemu-system-x86_64 "${qemu_args[@]}" -boot d || {
                local exit_code=$?
                if [ $exit_code -eq 124 ]; then
                    warn "Installation test timed out after 20 minutes"
                    return 1
                else
                    error "Installation test failed with exit code $exit_code"
                    return 1
                fi
            }
            ;;
        "full")
            # Полный тест с проверкой первой загрузки
            info "Testing full installation and first boot (30m timeout)..."
            timeout 1800s qemu-system-x86_64 "${qemu_args[@]}" -boot d || {
                local exit_code=$?
                warn "Full test completed or timed out (exit code: $exit_code)"
            }
            ;;
    esac
    
    # Анализ логов
    analyze_test_logs "$log_file" "$profile" "$test_type"
}

# Анализ логов тестирования
analyze_test_logs() {
    local log_file="$1"
    local profile="$2"
    local test_type="$3"
    
    if [ ! -f "$log_file" ]; then
        warn "Log file not found: $log_file"
        return 1
    fi
    
    log "Analyzing test logs for $profile ($test_type)..."
    
    local issues=()
    
    # Проверка на ошибки загрузки
    if grep -q "Kernel panic" "$log_file"; then
        issues+=("Kernel panic detected")
    fi
    
    if grep -q "Failed to" "$log_file"; then
        issues+=("Failure messages found")
    fi
    
    # Проверка успешной загрузки
    if grep -q "login:" "$log_file" || grep -q "Ubuntu 24.04" "$log_file"; then
        log "System boot detected"
    fi
    
    # Проверка autoinstall
    if grep -q "autoinstall" "$log_file"; then
        log "Autoinstall process detected"
    fi
    
    # Проверка профиля
    if grep -q "profile=$profile" "$log_file"; then
        log "Profile $profile detected in boot parameters"
    fi
    
    if [ ${#issues[@]} -gt 0 ]; then
        error "Issues found in $profile test:"
        printf '  - %s\n' "${issues[@]}"
        return 1
    else
        log "Test analysis passed for $profile"
        return 0
    fi
}

# Тестирование всех ISO
test_all_isos() {
    local test_type="${1:-boot}"
    local profiles=("base" "dw" "atpm" "arm" "prizm" "akts")
    local failed_tests=()
    
    log "Starting batch ISO testing (type: $test_type)"
    
    for profile in "${profiles[@]}"; do
        local iso_path="$SCRIPT_DIR/dist/ubuntu-24.04-${profile}-latest.iso"
        
        if [ -L "$iso_path" ]; then
            local real_iso=$(readlink -f "$iso_path")
            if test_iso_boot "$real_iso" "$profile" "$test_type"; then
                log "✓ $profile test passed"
            else
                error "✗ $profile test failed"
                failed_tests+=("$profile")
            fi
        else
            warn "ISO not found for profile: $profile"
            failed_tests+=("$profile")
        fi
    done
    
    # Сводка результатов
    echo
    log "Test Results Summary:"
    for profile in "${profiles[@]}"; do
        if [[ " ${failed_tests[*]} " =~ " $profile " ]]; then
            echo -e "${RED}  ✗ $profile${NC}"
        else
            echo -e "${GREEN}  ✓ $profile${NC}"
        fi
    done
    
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log "All tests passed!"
        return 0
    else
        error "${#failed_tests[@]} test(s) failed: ${failed_tests[*]}"
        return 1
    fi
}

# Создание отчета о тестировании
create_test_report() {
    local timestamp=$(date +%Y%m%d-%H%M)
    local report_file="$SCRIPT_DIR/test-results/test-report-${timestamp}.html"
    
    log "Creating test report..."
    
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Ubuntu 24.04 LTS ISO Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 10px; border-radius: 5px; }
        .pass { color: green; }
        .fail { color: red; }
        .warn { color: orange; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .log { background: #f8f8f8; padding: 10px; font-family: monospace; white-space: pre-wrap; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Ubuntu 24.04 LTS ISO Test Report</h1>
        <p>Generated: $(date)</p>
        <p>Test Environment: QEMU ${QEMU_MEMORY}MB RAM, ${QEMU_CPUS} CPUs</p>
    </div>
    
    <h2>Test Results</h2>
    <table>
        <tr>
            <th>Profile</th>
            <th>ISO Size</th>
            <th>Boot Test</th>
            <th>Install Test</th>
            <th>Notes</th>
        </tr>
EOF

    # Добавление результатов для каждого профиля
    local profiles=("base" "dw" "atpm" "arm" "prizm" "akts")
    for profile in "${profiles[@]}"; do
        local iso_path="$SCRIPT_DIR/dist/ubuntu-24.04-${profile}-latest.iso"
        local size="N/A"
        local boot_status="Not tested"
        local install_status="Not tested"
        
        if [ -L "$iso_path" ]; then
            local real_iso=$(readlink -f "$iso_path")
            size=$(du -h "$real_iso" | cut -f1)
            
            # Проверка логов тестирования
            local boot_log="$SCRIPT_DIR/test-results/test-${profile}-boot.log"
            local install_log="$SCRIPT_DIR/test-results/test-${profile}-install.log"
            
            if [ -f "$boot_log" ]; then
                if analyze_test_logs "$boot_log" "$profile" "boot" >/dev/null 2>&1; then
                    boot_status='<span class="pass">PASS</span>'
                else
                    boot_status='<span class="fail">FAIL</span>'
                fi
            fi
            
            if [ -f "$install_log" ]; then
                if analyze_test_logs "$install_log" "$profile" "install" >/dev/null 2>&1; then
                    install_status='<span class="pass">PASS</span>'
                else
                    install_status='<span class="fail">FAIL</span>'
                fi
            fi
        fi
        
        cat >> "$report_file" << EOF
        <tr>
            <td>$profile</td>
            <td>$size</td>
            <td>$boot_status</td>
            <td>$install_status</td>
            <td>Profile-specific configuration</td>
        </tr>
EOF
    done
    
    cat >> "$report_file" << 'EOF'
    </table>
    
    <h2>System Information</h2>
    <div class="log">
EOF
    
    # Добавление системной информации
    cat >> "$report_file" << EOF
Host: $(hostname)
OS: $(lsb_release -d | cut -f2)
Kernel: $(uname -r)
QEMU: $(qemu-system-x86_64 --version | head -1)
KVM: $([ -r /dev/kvm ] && echo "Available" || echo "Not available")
    </div>
</body>
</html>
EOF

    log "Test report created: $(basename "$report_file")"
    info "Open in browser: file://$(realpath "$report_file")"
}

# Показ справки
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] [ISO_FILE]

Options:
  -t, --test-type TYPE    Test type: boot, install, full (default: boot)
  -a, --all              Test all available ISOs
  -m, --memory MB        QEMU memory in MB (default: $QEMU_MEMORY)
  -c, --cpus N           QEMU CPU count (default: $QEMU_CPUS)
  -d, --disk-size SIZE   Test disk size (default: $QEMU_DISK_SIZE)
  -r, --report           Generate HTML report
  -h, --help             Show this help message

Test Types:
  boot                   Quick boot test (30s)
  install                Full installation test (20m)
  full                   Installation + first boot (30m)

Examples:
  $0 -a                                    # Test boot of all ISOs
  $0 -a -t install                        # Test installation of all ISOs
  $0 -t full ubuntu-24.04-base-latest.iso # Full test of specific ISO
  $0 -a -r                                # Test all and generate report

EOF
}

# Обработка аргументов
parse_arguments() {
    local test_type="boot"
    local test_all=false
    local generate_report=false
    local iso_file=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--test-type)
                test_type="$2"
                shift 2
                ;;
            -a|--all)
                test_all=true
                shift
                ;;
            -m|--memory)
                QEMU_MEMORY="$2"
                shift 2
                ;;
            -c|--cpus)
                QEMU_CPUS="$2"
                shift 2
                ;;
            -d|--disk-size)
                QEMU_DISK_SIZE="$2"
                shift 2
                ;;
            -r|--report)
                generate_report=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                iso_file="$1"
                shift
                ;;
        esac
    done
    
    # Валидация типа теста
    case "$test_type" in
        boot|install|full)
            ;;
        *)
            error "Invalid test type: $test_type"
            ;;
    esac
    
    # Выполнение тестов
    if [ "$test_all" = true ]; then
        test_all_isos "$test_type"
    elif [ -n "$iso_file" ]; then
        if [ ! -f "$iso_file" ]; then
            error "ISO file not found: $iso_file"
        fi
        local profile=$(basename "$iso_file" | sed 's/ubuntu-24.04-$$[^-]*$$-.*/\1/')
        test_iso_boot "$iso_file" "$profile" "$test_type"
    else
        error "No ISO file specified and --all not used"
    fi
    
    # Генерация отчета
    if [ "$generate_report" = true ]; then
        create_test_report
    fi
}

# Основная функция
main() {
    log "Ubuntu 24.04 LTS ISO Testing Tool"
    
    check_dependencies
    parse_arguments "$@"
}

# Запуск
main "$@"
