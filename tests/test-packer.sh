#!/bin/bash
# Тестирование Packer конфигурации

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."
    
    local deps=("packer" "qemu-system-x86_64" "ansible")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Отсутствуют зависимости: ${missing[*]}"
        return 1
    fi
    
    log_info "Все зависимости установлены"
}

# Валидация Packer файлов
validate_packer() {
    log_info "Валидация Packer конфигурации..."
    
    cd "$PROJECT_ROOT/packer"
    
    # Проверка синтаксиса
    if ! packer validate .; then
        log_error "Ошибка валидации Packer конфигурации"
        return 1
    fi
    
    log_info "Packer конфигурация валидна"
}

# Проверка autoinstall конфигурации
validate_autoinstall() {
    log_info "Проверка autoinstall конфигурации..."
    
    local user_data="$PROJECT_ROOT/packer/http/user-data"
    
    if [ ! -f "$user_data" ]; then
        log_error "Файл user-data не найден: $user_data"
        return 1
    fi
    
    # Проверка YAML синтаксиса
    if command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$user_data'))" 2>/dev/null; then
            log_error "Некорректный YAML в user-data"
            return 1
        fi
    fi
    
    # Проверка cloud-init схемы (если доступна)
    if command -v cloud-init &> /dev/null; then
        if ! cloud-init schema --config-file "$user_data" &>/dev/null; then
            log_warn "Предупреждения в cloud-init схеме"
        fi
    fi
    
    log_info "Autoinstall конфигурация корректна"
}

# Тест сборки образа (dry-run)
test_build_dryrun() {
    log_info "Тестирование сборки образа (dry-run)..."
    
    cd "$PROJECT_ROOT/packer"
    
    # Используем переменную для быстрого тестирования
    export PKR_VAR_headless=true
    export PKR_VAR_memory=1024
    export PKR_VAR_cpus=1
    
    # Проверяем что можем инициализировать сборку
    if ! timeout 60 packer build -dry-run .; then
        log_error "Ошибка при dry-run сборке"
        return 1
    fi
    
    log_info "Dry-run сборка прошла успешно"
}

# Основная функция
main() {
    log_info "Запуск тестов Packer конфигурации..."
    
    check_dependencies || exit 1
    validate_packer || exit 1
    validate_autoinstall || exit 1
    test_build_dryrun || exit 1
    
    log_info "Все тесты Packer прошли успешно!"
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
