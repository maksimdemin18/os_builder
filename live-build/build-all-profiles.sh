#!/usr/bin/env bash
# Скрипт для сборки всех профилей

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROFILES=("base" "dw" "atpm" "arm" "prizm" "akts")
PARALLEL_BUILDS="${PARALLEL_BUILDS:-1}"
VERIFY="${VERIFY:-false}"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

# Функция сборки одного профиля
build_profile() {
    local profile="$1"
    local logfile="$SCRIPT_DIR/dist/build-${profile}.log"
    
    log "Building profile: $profile"
    
    mkdir -p "$SCRIPT_DIR/dist"
    
    local verify_flag=""
    if [ "$VERIFY" = "true" ]; then
        verify_flag="--verify"
    fi
    
    if sudo "$SCRIPT_DIR/mkiso.sh" --profile "$profile" $verify_flag > "$logfile" 2>&1; then
        log "Profile $profile built successfully"
        return 0
    else
        error "Profile $profile build failed. Check $logfile for details"
        return 1
    fi
}

# Последовательная сборка
build_sequential() {
    local failed_profiles=()
    
    for profile in "${PROFILES[@]}"; do
        if ! build_profile "$profile"; then
            failed_profiles+=("$profile")
        fi
    done
    
    return ${#failed_profiles[@]}
}

# Параллельная сборка
build_parallel() {
    local pids=()
    local failed_profiles=()
    
    log "Starting parallel build with $PARALLEL_BUILDS concurrent jobs"
    
    # Запуск сборок
    for profile in "${PROFILES[@]}"; do
        # Ожидание свободного слота
        while [ ${#pids[@]} -ge "$PARALLEL_BUILDS" ]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    wait "${pids[$i]}"
                    local exit_code=$?
                    if [ $exit_code -ne 0 ]; then
                        failed_profiles+=("${profiles_running[$i]}")
                    fi
                    unset pids[$i]
                    unset profiles_running[$i]
                fi
            done
            # Пересоздание массивов без пустых элементов
            pids=("${pids[@]}")
            profiles_running=("${profiles_running[@]}")
            sleep 1
        done
        
        # Запуск новой сборки
        build_profile "$profile" &
        pids+=($!)
        profiles_running+=("$profile")
    done
    
    # Ожидание завершения всех процессов
    for pid in "${pids[@]}"; do
        wait "$pid"
        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            # Найти профиль по PID (упрощенно)
            warn "One of the builds failed"
        fi
    done
    
    return ${#failed_profiles[@]}
}

# Создание сводного отчета
create_summary() {
    local timestamp=$(date +%Y%m%d-%H%M)
    local summary_file="$SCRIPT_DIR/dist/build-summary-${timestamp}.txt"
    
    log "Creating build summary..."
    
    cat > "$summary_file" << EOF
Ubuntu 24.04 LTS ISO Build Summary
==================================

Build Date: $(date)
Profiles Built: ${#PROFILES[@]}
Parallel Jobs: $PARALLEL_BUILDS
Verification: $VERIFY

Profiles:
EOF

    for profile in "${PROFILES[@]}"; do
        local iso_file="$SCRIPT_DIR/dist/ubuntu-24.04-${profile}-latest.iso"
        if [ -L "$iso_file" ]; then
            local real_file=$(readlink -f "$iso_file")
            local size=$(du -h "$real_file" | cut -f1)
            local checksum=$(sha256sum "$real_file" | cut -d' ' -f1)
            echo "  ✓ $profile: $size (SHA256: ${checksum:0:16}...)" >> "$summary_file"
        else
            echo "  ✗ $profile: FAILED" >> "$summary_file"
        fi
    done
    
    cat >> "$summary_file" << EOF

Total Size: $(du -sh "$SCRIPT_DIR/dist"/*.iso 2>/dev/null | tail -1 | cut -f1 || echo "0")

Files Created:
$(ls -la "$SCRIPT_DIR/dist"/ | grep -E '\.(iso|txt|json)$' || echo "None")
EOF

    log "Summary created: $(basename "$summary_file")"
    
    # Показать краткую сводку
    echo
    log "Build Summary:"
    grep -E "(✓|✗)" "$summary_file" | while read line; do
        if [[ "$line" == *"✓"* ]]; then
            echo -e "${GREEN}$line${NC}"
        else
            echo -e "${RED}$line${NC}"
        fi
    done
}

# Очистка старых файлов
cleanup_old_files() {
    local keep_days="${KEEP_DAYS:-7}"
    
    log "Cleaning up files older than $keep_days days..."
    
    find "$SCRIPT_DIR/dist" -name "*.iso" -type f -mtime +$keep_days -delete 2>/dev/null || true
    find "$SCRIPT_DIR/dist" -name "*.log" -type f -mtime +$keep_days -delete 2>/dev/null || true
    find "$SCRIPT_DIR/dist" -name "*.txt" -type f -mtime +$keep_days -delete 2>/dev/null || true
    find "$SCRIPT_DIR/dist" -name "*.json" -type f -mtime +$keep_days -delete 2>/dev/null || true
    
    log "Cleanup completed"
}

# Показ справки
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  -j, --jobs N            Number of parallel builds (default: 1)
  -v, --verify            Verify ISOs after creation
  -c, --cleanup           Clean old files before build
  -s, --summary-only      Only create summary from existing files
  -h, --help              Show this help message

Environment variables:
  PARALLEL_BUILDS         Number of parallel builds
  VERIFY                  Verify ISOs (true/false)
  KEEP_DAYS              Days to keep old files (default: 7)

Examples:
  $0                      # Build all profiles sequentially
  $0 -j 3                # Build with 3 parallel jobs
  $0 -v -c               # Clean, build, and verify all
  $0 -s                  # Only create summary

EOF
}

# Обработка аргументов
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -j|--jobs)
                PARALLEL_BUILDS="$2"
                shift 2
                ;;
            -v|--verify)
                VERIFY="true"
                shift
                ;;
            -c|--cleanup)
                cleanup_old_files
                shift
                ;;
            -s|--summary-only)
                create_summary
                exit 0
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
}

# Проверка зависимостей
check_requirements() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
    fi
    
    if [ ! -f "$SCRIPT_DIR/mkiso.sh" ]; then
        error "mkiso.sh not found in $SCRIPT_DIR"
    fi
    
    if ! command -v parallel >/dev/null 2>&1 && [ "$PARALLEL_BUILDS" -gt 1 ]; then
        warn "GNU parallel not found, falling back to sequential build"
        PARALLEL_BUILDS=1
    fi
}

# Основная функция
main() {
    log "Starting batch build of all Ubuntu 24.04 LTS profiles"
    log "Profiles to build: ${PROFILES[*]}"
    log "Parallel jobs: $PARALLEL_BUILDS"
    log "Verification: $VERIFY"
    
    local start_time=$(date +%s)
    local failed_count=0
    
    if [ "$PARALLEL_BUILDS" -gt 1 ]; then
        build_parallel
        failed_count=$?
    else
        build_sequential
        failed_count=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    create_summary
    
    log "Batch build completed in ${duration}s"
    
    if [ $failed_count -eq 0 ]; then
        log "All profiles built successfully!"
        exit 0
    else
        error "$failed_count profile(s) failed to build"
        exit 1
    fi
}

# Запуск
parse_arguments "$@"
check_requirements
main
