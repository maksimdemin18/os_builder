#!/bin/bash
# Запуск всех тестов проекта

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

log_section() {
    echo -e "${BLUE}[SECTION]${NC} $1"
}

# Функция для запуска теста с обработкой ошибок
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    log_section "Запуск теста: $test_name"
    
    if [ -f "$test_script" ] && [ -x "$test_script" ]; then
        if "$test_script"; then
            log_info "✓ $test_name - ПРОЙДЕН"
            return 0
        else
            log_error "✗ $test_name - ПРОВАЛЕН"
            return 1
        fi
    else
        log_error "Тест не найден или не исполняемый: $test_script"
        return 1
    fi
}

# Проверка окружения
check_environment() {
    log_section "Проверка окружения"
    
    # Проверяем что мы в правильной директории
    if [ ! -f "$PROJECT_ROOT/README.md" ]; then
        log_error "Не найден README.md в корне проекта"
        exit 1
    fi
    
    # Проверяем основные директории
    local required_dirs=("packer" "ansible" "profiles" "live-build")
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$PROJECT_ROOT/$dir" ]; then
            log_error "Отсутствует обязательная директория: $dir"
            exit 1
        fi
    done
    
    log_info "Окружение корректно"
}

# Создание отчета
generate_summary_report() {
    local total_tests="$1"
    local passed_tests="$2"
    local failed_tests="$3"
    
    log_section "Генерация итогового отчета"
    
    local report_file="$PROJECT_ROOT/test-results/summary-report.txt"
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
Итоговый отчет тестирования
===========================

Дата: $(date)
Система: $(uname -a)
Проект: Ubuntu 24.04 LTS ISO Builder

Результаты:
-----------
Всего тестов: $total_tests
Пройдено: $passed_tests
Провалено: $failed_tests

Статус: $([ $failed_tests -eq 0 ] && echo "УСПЕШНО" || echo "ЕСТЬ ОШИБКИ")

Детали:
-------
EOF
    
    # Добавляем детали каждого теста
    if [ -f "$PROJECT_ROOT/test-results/test-details.log" ]; then
        cat "$PROJECT_ROOT/test-results/test-details.log" >> "$report_file"
    fi
    
    log_info "Итоговый отчет создан: $report_file"
}

# Основная функция
main() {
    local run_iso_tests=false
    local verbose=false
    
    # Парсинг аргументов
    while [[ $# -gt 0 ]]; do
        case $1 in
            --iso)
                run_iso_tests=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                echo "Использование: $0 [--iso] [--verbose]"
                echo "  --iso      Включить тесты ISO образов (требует sudo)"
                echo "  --verbose  Подробный вывод"
                exit 0
                ;;
            *)
                log_error "Неизвестный параметр: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Запуск полного тестирования проекта Ubuntu 24.04 LTS ISO Builder"
    
    # Создаем директорию для результатов
    mkdir -p "$PROJECT_ROOT/test-results"
    local details_log="$PROJECT_ROOT/test-results/test-details.log"
    echo "Детали тестирования - $(date)" > "$details_log"
    
    check_environment
    
    # Счетчики тестов
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Список тестов для запуска
    local tests=(
        "Packer конфигурация:$SCRIPT_DIR/test-packer.sh"
        "Ansible роли:$SCRIPT_DIR/test-ansible.sh"
    )
    
    # Добавляем ISO тесты если запрошены
    if [ "$run_iso_tests" = true ]; then
        tests+=("ISO образы:$SCRIPT_DIR/test-iso.sh")
    fi
    
    # Запускаем тесты
    for test_entry in "${tests[@]}"; do
        IFS=':' read -r test_name test_script <<< "$test_entry"
        
        total_tests=$((total_tests + 1))
        
        echo "----------------------------------------" >> "$details_log"
        echo "Тест: $test_name" >> "$details_log"
        echo "Время: $(date)" >> "$details_log"
        
        if run_test "$test_name" "$test_script"; then
            passed_tests=$((passed_tests + 1))
            echo "Результат: ПРОЙДЕН" >> "$details_log"
        else
            failed_tests=$((failed_tests + 1))
            echo "Результат: ПРОВАЛЕН" >> "$details_log"
        fi
        
        echo "" >> "$details_log"
    done
    
    # Генерируем итоговый отчет
    generate_summary_report "$total_tests" "$passed_tests" "$failed_tests"
    
    # Выводим итоги
    log_section "ИТОГИ ТЕСТИРОВАНИЯ"
    log_info "Всего тестов: $total_tests"
    log_info "Пройдено: $passed_tests"
    
    if [ $failed_tests -gt 0 ]; then
        log_error "Провалено: $failed_tests"
        log_error "Тестирование завершено с ошибками!"
        exit 1
    else
        log_info "Провалено: $failed_tests"
        log_info "Все тесты пройдены успешно!"
    fi
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
