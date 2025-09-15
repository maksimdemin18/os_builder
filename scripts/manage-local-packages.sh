#!/bin/bash

# Скрипт для управления локальными пакетами
# Использование: ./manage-local-packages.sh [add|remove|list|build-repo] [package-path]

set -e

LOCAL_PACKAGES_DIR="local-packages"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Создаем директорию для локальных пакетов
mkdir -p "$PROJECT_DIR/$LOCAL_PACKAGES_DIR"

show_help() {
    echo "Управление локальными пакетами для сборки образов"
    echo ""
    echo "Использование: $0 [команда] [параметры]"
    echo ""
    echo "Команды:"
    echo "  add <путь>        Добавить .deb пакет в локальный репозиторий"
    echo "  remove <имя>      Удалить пакет из локального репозитория"
    echo "  list              Показать все локальные пакеты"
    echo "  build-repo        Пересобрать локальный репозиторий"
    echo "  clean             Очистить локальный репозиторий"
    echo "  install-tools     Установить инструменты для работы с пакетами"
    echo ""
    echo "Примеры:"
    echo "  $0 add /path/to/package.deb"
    echo "  $0 remove my-package"
    echo "  $0 list"
    echo "  $0 build-repo"
}

install_tools() {
    echo "Установка инструментов для работы с пакетами..."
    
    # Проверяем наличие dpkg-dev
    if ! command -v dpkg-scanpackages &> /dev/null; then
        echo "Устанавливаем dpkg-dev..."
        sudo apt-get update
        sudo apt-get install -y dpkg-dev
    fi
    
    # Проверяем наличие reprepro (опционально)
    if ! command -v reprepro &> /dev/null; then
        echo "Устанавливаем reprepro (для продвинутого управления репозиторием)..."
        sudo apt-get install -y reprepro
    fi
    
    echo "Инструменты установлены успешно"
}

add_package() {
    local package_path="$1"
    
    if [ -z "$package_path" ]; then
        echo "Ошибка: Укажите путь к .deb пакету"
        exit 1
    fi
    
    if [ ! -f "$package_path" ]; then
        echo "Ошибка: Файл $package_path не найден"
        exit 1
    fi
    
    if [[ ! "$package_path" =~ \.deb$ ]]; then
        echo "Ошибка: Файл должен иметь расширение .deb"
        exit 1
    fi
    
    local package_name=$(basename "$package_path")
    local dest_path="$PROJECT_DIR/$LOCAL_PACKAGES_DIR/$package_name"
    
    echo "Добавляем пакет: $package_name"
    cp "$package_path" "$dest_path"
    
    echo "Пакет добавлен: $dest_path"
    build_repo
}

remove_package() {
    local package_name="$1"
    
    if [ -z "$package_name" ]; then
        echo "Ошибка: Укажите имя пакета для удаления"
        exit 1
    fi
    
    # Ищем пакет по имени (с или без .deb)
    local found_files=()
    while IFS= read -r -d '' file; do
        found_files+=("$file")
    done < <(find "$PROJECT_DIR/$LOCAL_PACKAGES_DIR" -name "*${package_name}*" -name "*.deb" -print0)
    
    if [ ${#found_files[@]} -eq 0 ]; then
        echo "Пакет $package_name не найден"
        exit 1
    fi
    
    echo "Найденные пакеты:"
    for i in "${!found_files[@]}"; do
        echo "$((i+1)). $(basename "${found_files[$i]}")"
    done
    
    if [ ${#found_files[@]} -eq 1 ]; then
        rm "${found_files[0]}"
        echo "Пакет удален: $(basename "${found_files[0]}")"
    else
        echo "Найдено несколько пакетов. Укажите точное имя файла."
        exit 1
    fi
    
    build_repo
}

list_packages() {
    echo "Локальные пакеты в $LOCAL_PACKAGES_DIR:"
    echo "================================================"
    
    if [ ! -d "$PROJECT_DIR/$LOCAL_PACKAGES_DIR" ] || [ -z "$(ls -A "$PROJECT_DIR/$LOCAL_PACKAGES_DIR")" ]; then
        echo "Локальные пакеты не найдены"
        return
    fi
    
    local total_size=0
    
    for deb_file in "$PROJECT_DIR/$LOCAL_PACKAGES_DIR"/*.deb; do
        if [ -f "$deb_file" ]; then
            local size=$(stat -f%z "$deb_file" 2>/dev/null || stat -c%s "$deb_file" 2>/dev/null || echo "0")
            local size_mb=$((size / 1024 / 1024))
            total_size=$((total_size + size))
            
            # Получаем информацию о пакете
            local package_info=$(dpkg-deb -I "$deb_file" | grep -E "Package:|Version:|Description:" | head -3)
            local package_name=$(echo "$package_info" | grep "Package:" | cut -d: -f2 | xargs)
            local version=$(echo "$package_info" | grep "Version:" | cut -d: -f2 | xargs)
            local description=$(echo "$package_info" | grep "Description:" | cut -d: -f2 | xargs)
            
            echo "Файл: $(basename "$deb_file")"
            echo "  Пакет: $package_name"
            echo "  Версия: $version"
            echo "  Размер: ${size_mb} MB"
            echo "  Описание: $description"
            echo ""
        fi
    done
    
    local total_size_mb=$((total_size / 1024 / 1024))
    echo "Общий размер: ${total_size_mb} MB"
}

build_repo() {
    echo "Пересборка локального репозитория..."
    
    cd "$PROJECT_DIR/$LOCAL_PACKAGES_DIR"
    
    # Удаляем старые индексы
    rm -f Packages Packages.gz Release Release.gpg InRelease
    
    # Создаем новые индексы
    if ls *.deb 1> /dev/null 2>&1; then
        dpkg-scanpackages . /dev/null > Packages
        gzip -k Packages
        
        # Создаем Release файл
        cat > Release << EOF
Archive: local
Component: main
Origin: Local Repository
Label: Local Repository
Architecture: amd64
Date: $(date -Ru)
EOF
        
        echo "Локальный репозиторий обновлен"
        echo "Найдено пакетов: $(ls *.deb | wc -l)"
    else
        echo "Пакеты .deb не найдены"
    fi
}

clean_repo() {
    echo "Очистка локального репозитория..."
    rm -rf "$PROJECT_DIR/$LOCAL_PACKAGES_DIR"/*
    echo "Локальный репозиторий очищен"
}

# Основная логика
case "${1:-help}" in
    "add")
        add_package "$2"
        ;;
    "remove")
        remove_package "$2"
        ;;
    "list")
        list_packages
        ;;
    "build-repo")
        build_repo
        ;;
    "clean")
        clean_repo
        ;;
    "install-tools")
        install_tools
        ;;
    "help"|*)
        show_help
        ;;
esac
