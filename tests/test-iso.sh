#!/bin/bash
# Тестирование созданных ISO образов

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Конфигурация
DIST_DIR="$PROJECT_ROOT/dist"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"
QEMU_MEMORY="2048"
QEMU_TIMEOUT="300"

# Создание директории для результатов
setup_test_environment() {
    log_info "Настройка тестового окружения..."
    
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Проверка зависимостей
    local deps=("qemu-system-x86_64" "qemu-img")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Зависимость не найдена: $dep"
            exit 1
        fi
    done
    
    log_info "Тестовое окружение готово"
}

# Проверка структуры ISO
test_iso_structure() {
    local iso_file="$1"
    local profile="$2"
    
    log_info "Проверка структуры ISO: $profile"
    
    # Создаем временную директорию для монтирования
    local mount_dir=$(mktemp -d)
    local result_file="$TEST_RESULTS_DIR/${profile}-structure.txt"
    
    # Монтируем ISO
    if sudo mount -o loop,ro "$iso_file" "$mount_dir" 2>/dev/null; then
        log_info "ISO успешно смонтирован"
        
        # Проверяем ключевые файлы
        local key_files=(
            "casper/vmlinuz"
            "casper/initrd"
            "boot/grub/grub.cfg"
            "nocloud/user-data"
            "nocloud/meta-data"
        )
        
        echo "Структура ISO для профиля $profile:" > "$result_file"
        echo "========================================" >> "$result_file"
        
        for file in "${key_files[@]}"; do
            if [ -f "$mount_dir/$file" ]; then
                echo "✓ $file" >> "$result_file"
                log_debug "Найден: $file"
            else
                echo "✗ $file" >> "$result_file"
                log_warn "Отсутствует: $file"
            fi
        done
        
        # Проверяем размеры
        echo "" >> "$result_file"
        echo "Размеры ключевых файлов:" >> "$result_file"
        ls -lh "$mount_dir"/casper/{vmlinuz,initrd} 2>/dev/null >> "$result_file" || true
        
        # Размонтируем
        sudo umount "$mount_dir"
        rmdir "$mount_dir"
        
        log_info "Структура ISO проверена, результаты в $result_file"
    else
        log_error "Не удалось смонтировать ISO: $iso_file"
        return 1
    fi
}

# Тест загрузки в QEMU
test_iso_boot() {
    local iso_file="$1"
    local profile="$2"
    
    log_info "Тестирование загрузки ISO: $profile"
    
    local log_file="$TEST_RESULTS_DIR/${profile}-boot.log"
    local screenshot_file="$TEST_RESULTS_DIR/${profile}-boot.png"
    
    # Создаем временный диск для установки
    local test_disk="$TEST_RESULTS_DIR/${profile}-test.qcow2"
    qemu-img create -f qcow2 "$test_disk" 10G
    
    # Запускаем QEMU с таймаутом
    log_info "Запуск QEMU для профиля $profile (таймаут: ${QEMU_TIMEOUT}s)..."
    
    timeout "$QEMU_TIMEOUT" qemu-system-x86_64 \
        -enable-kvm \
        -m "$QEMU_MEMORY" \
        -cdrom "$iso_file" \
        -drive file="$test_disk",format=qcow2 \
        -boot d \
        -nographic \
        -serial file:"$log_file" \
        -monitor none \
        -display none \
        2>/dev/null || {
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_info "QEMU завершен по таймауту (ожидаемо)"
        else
            log_warn "QEMU завершен с кодом: $exit_code"
        fi
    }
    
    # Анализируем лог
    if [ -f "$log_file" ]; then
        log_info "Анализ лога загрузки..."
        
        # Ищем ключевые события
        if grep -q "cloud-init" "$log_file"; then
            log_info "✓ Cloud-init запущен"
        else
            log_warn "✗ Cloud-init не обнаружен в логе"
        fi
        
        if grep -q "systemd" "$log_file"; then
            log_info "✓ Systemd инициализирован"
        else
            log_warn "✗ Systemd не обнаружен в логе"
        fi
        
        # Проверяем на ошибки
        local error_count=$(grep -c -i "error\|fail\|panic" "$log_file" || true)
        if [ "$error_count" -gt 0 ]; then
            log_warn "Обнаружено $error_count потенциальных ошибок в логе"
        else
            log_info "✓ Критических ошибок не обнаружено"
        fi
    else
        log_error "Лог файл не создан: $log_file"
    fi
    
    # Очищаем временный диск
    rm -f "$test_disk"
    
    log_info "Тест загрузки завершен для профиля $profile"
}

# Проверка контрольных сумм
test_iso_checksums() {
    log_info "Проверка контрольных сумм ISO образов..."
    
    local checksums_file="$DIST_DIR/SHA256SUMS"
    
    if [ -f "$checksums_file" ]; then
        cd "$DIST_DIR"
        if sha256sum -c "$checksums_file"; then
            log_info "✓ Все контрольные суммы корректны"
        else
            log_error "✗ Ошибка проверки контрольных сумм"
            return 1
        fi
    else
        log_warn "Файл контрольных сумм не найден: $checksums_file"
        
        # Создаем контрольные суммы
        log_info "Создание контрольных сумм..."
        cd "$DIST_DIR"
        sha256sum *.iso > SHA256SUMS 2>/dev/null || true
        log_info "Контрольные суммы созданы: $checksums_file"
    fi
}

# Генерация отчета
generate_report() {
    log_info "Генерация отчета тестирования..."
    
    local report_file="$TEST_RESULTS_DIR/test-report.html"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Отчет тестирования ISO образов</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .profile { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        pre { background: #f8f8f8; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Отчет тестирования ISO образов Ubuntu 24.04 LTS</h1>
        <p>Дата: $(date)</p>
        <p>Система: $(uname -a)</p>
    </div>
EOF
    
    # Добавляем информацию о каждом профиле
    for iso_file in "$DIST_DIR"/*.iso; do
        if [ -f "$iso_file" ]; then
            local profile=$(basename "$iso_file" .iso | sed 's/ubuntu-24.04-//')
            
            cat >> "$report_file" << EOF
    <div class="profile">
        <h2>Профиль: $profile</h2>
        <p><strong>Файл:</strong> $(basename "$iso_file")</p>
        <p><strong>Размер:</strong> $(du -h "$iso_file" | cut -f1)</p>
EOF
            
            # Добавляем результаты структуры
            local structure_file="$TEST_RESULTS_DIR/${profile}-structure.txt"
            if [ -f "$structure_file" ]; then
                echo "        <h3>Структура ISO</h3>" >> "$report_file"
                echo "        <pre>$(cat "$structure_file")</pre>" >> "$report_file"
            fi
            
            # Добавляем результаты загрузки
            local boot_log="$TEST_RESULTS_DIR/${profile}-boot.log"
            if [ -f "$boot_log" ]; then
                echo "        <h3>Лог загрузки (последние 50 строк)</h3>" >> "$report_file"
                echo "        <pre>$(tail -50 "$boot_log")</pre>" >> "$report_file"
            fi
            
            echo "    </div>" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << 'EOF'
</body>
</html>
EOF
    
    log_info "Отчет создан: $report_file"
}

# Основная функция
main() {
    local profiles=("$@")
    
    log_info "Запуск тестирования ISO образов..."
    
    setup_test_environment
    
    # Если профили не указаны, тестируем все найденные ISO
    if [ ${#profiles[@]} -eq 0 ]; then
        log_info "Поиск ISO образов в $DIST_DIR..."
        
        if [ ! -d "$DIST_DIR" ]; then
            log_error "Директория dist не найдена: $DIST_DIR"
            exit 1
        fi
        
        for iso_file in "$DIST_DIR"/*.iso; do
            if [ -f "$iso_file" ]; then
                local profile=$(basename "$iso_file" .iso | sed 's/ubuntu-24.04-//')
                profiles+=("$profile")
            fi
        done
        
        if [ ${#profiles[@]} -eq 0 ]; then
            log_error "ISO образы не найдены в $DIST_DIR"
            exit 1
        fi
    fi
    
    log_info "Найдено профилей для тестирования: ${#profiles[@]}"
    
    # Тестируем каждый профиль
    for profile in "${profiles[@]}"; do
        local iso_file="$DIST_DIR/ubuntu-24.04-${profile}.iso"
        
        if [ -f "$iso_file" ]; then
            log_info "Тестирование профиля: $profile"
            
            test_iso_structure "$iso_file" "$profile"
            test_iso_boot "$iso_file" "$profile"
        else
            log_error "ISO файл не найден: $iso_file"
        fi
    done
    
    # Проверяем контрольные суммы
    test_iso_checksums
    
    # Генерируем отчет
    generate_report
    
    log_info "Тестирование завершено! Результаты в $TEST_RESULTS_DIR"
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
