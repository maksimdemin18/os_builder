#!/bin/bash
# Тестирование Ansible ролей и плейбуков

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Проверка синтаксиса плейбуков
test_playbook_syntax() {
    log_info "Проверка синтаксиса Ansible плейбуков..."
    
    cd "$PROJECT_ROOT/ansible"
    
    local playbooks=(
        "playbooks/base.yml"
        "playbooks/profile.yml"
        "playbooks/verify.yml"
    )
    
    for playbook in "${playbooks[@]}"; do
        if [ -f "$playbook" ]; then
            log_info "Проверка $playbook..."
            if ! ansible-playbook --syntax-check "$playbook"; then
                log_error "Ошибка синтаксиса в $playbook"
                return 1
            fi
        else
            log_warn "Плейбук не найден: $playbook"
        fi
    done
    
    log_info "Синтаксис всех плейбуков корректен"
}

# Проверка ролей
test_roles() {
    log_info "Проверка Ansible ролей..."
    
    cd "$PROJECT_ROOT/ansible"
    
    local roles_dir="roles"
    if [ ! -d "$roles_dir" ]; then
        log_error "Директория ролей не найдена: $roles_dir"
        return 1
    fi
    
    # Проверяем структуру ролей
    for role_dir in "$roles_dir"/*; do
        if [ -d "$role_dir" ]; then
            local role_name=$(basename "$role_dir")
            log_info "Проверка роли: $role_name"
            
            # Проверяем наличие основных файлов
            local tasks_file="$role_dir/tasks/main.yml"
            if [ -f "$tasks_file" ]; then
                # Проверка синтаксиса задач
                if ! ansible-playbook --syntax-check -i /dev/null "$tasks_file" 2>/dev/null; then
                    log_warn "Возможные проблемы в задачах роли $role_name"
                fi
            else
                log_warn "Файл задач не найден для роли $role_name"
            fi
        fi
    done
    
    log_info "Проверка ролей завершена"
}

# Тест с molecule (если доступен)
test_with_molecule() {
    log_info "Проверка наличия Molecule для тестирования..."
    
    if command -v molecule &> /dev/null; then
        log_info "Molecule найден, запуск тестов..."
        cd "$PROJECT_ROOT/ansible"
        
        # Проверяем наличие molecule конфигурации
        if [ -f "molecule/default/molecule.yml" ]; then
            molecule test --all
        else
            log_warn "Molecule конфигурация не найдена"
        fi
    else
        log_warn "Molecule не установлен, пропускаем расширенные тесты"
    fi
}

# Проверка переменных профилей
test_profile_vars() {
    log_info "Проверка переменных профилей..."
    
    local profiles_dir="$PROJECT_ROOT/profiles"
    local vars_dir="$PROJECT_ROOT/ansible/roles/vars"
    
    if [ ! -d "$profiles_dir" ]; then
        log_error "Директория профилей не найдена: $profiles_dir"
        return 1
    fi
    
    for profile_file in "$profiles_dir"/*.yaml; do
        if [ -f "$profile_file" ]; then
            local profile_name=$(basename "$profile_file" .yaml)
            log_info "Проверка профиля: $profile_name"
            
            # Проверка YAML синтаксиса
            if command -v python3 &> /dev/null; then
                if ! python3 -c "import yaml; yaml.safe_load(open('$profile_file'))" 2>/dev/null; then
                    log_error "Некорректный YAML в профиле $profile_name"
                    return 1
                fi
            fi
            
            # Проверка соответствующих переменных
            local vars_file="$vars_dir/${profile_name}.yml"
            if [ -f "$vars_file" ]; then
                log_info "Найдены переменные для профиля $profile_name"
            else
                log_warn "Переменные не найдены для профиля $profile_name"
            fi
        fi
    done
    
    log_info "Проверка профилей завершена"
}

# Основная функция
main() {
    log_info "Запуск тестов Ansible конфигурации..."
    
    # Проверка наличия ansible
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible не установлен"
        exit 1
    fi
    
    test_playbook_syntax || exit 1
    test_roles || exit 1
    test_profile_vars || exit 1
    test_with_molecule
    
    log_info "Все тесты Ansible прошли успешно!"
}

# Запуск если скрипт вызван напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
