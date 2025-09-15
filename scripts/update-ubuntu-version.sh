#!/bin/bash

# Скрипт для обновления версии Ubuntu

set -e

echo "=== Обновление версии Ubuntu ==="

# Функция для получения актуальной информации об Ubuntu
get_ubuntu_info() {
    local version=$1
    local url=""
    local checksum=""
    
    case "$version" in
        "24.04"|"24.04.1")
            echo "Получение информации о Ubuntu 24.04 LTS..."
            url="https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
            # Получаем актуальную контрольную сумму
            checksum=$(curl -s https://releases.ubuntu.com/24.04/SHA256SUMS | grep "live-server-amd64.iso" | awk '{print $1}')
            ;;
        "22.04"|"22.04.3")
            echo "Получение информации о Ubuntu 22.04 LTS..."
            url="https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso"
            checksum=$(curl -s https://releases.ubuntu.com/22.04/SHA256SUMS | grep "live-server-amd64.iso" | awk '{print $1}')
            ;;
        "20.04"|"20.04.6")
            echo "Получение информации о Ubuntu 20.04 LTS..."
            url="https://releases.ubuntu.com/20.04/ubuntu-20.04.6-live-server-amd64.iso"
            checksum=$(curl -s https://releases.ubuntu.com/20.04/SHA256SUMS | grep "live-server-amd64.iso" | awk '{print $1}')
            ;;
        *)
            echo "Неподдерживаемая версия: $version"
            echo "Поддерживаемые версии: 24.04, 22.04, 20.04"
            exit 1
            ;;
    esac
    
    if [ -z "$checksum" ]; then
        echo "Не удалось получить контрольную сумму для версии $version"
        exit 1
    fi
    
    echo "URL: $url"
    echo "Checksum: $checksum"
    
    # Обновляем variables.pkr.hcl
    echo "Обновление packer/variables.pkr.hcl..."
    sed -i "s|default     = \"https://releases.ubuntu.com/[^\"]*\"|default     = \"$url\"|" packer/variables.pkr.hcl
    sed -i "s|default     = \"sha256:[^\"]*\"|default     = \"sha256:$checksum\"|" packer/variables.pkr.hcl
    sed -i "s|default     = \"[0-9][0-9]\\.[0-9][0-9]\"|default     = \"$version\"|" packer/variables.pkr.hcl
    
    echo "✓ Конфигурация обновлена для Ubuntu $version"
}

# Проверка аргументов
if [ $# -eq 0 ]; then
    echo "Использование: $0 <версия>"
    echo "Примеры:"
    echo "  $0 24.04    # Ubuntu 24.04 LTS"
    echo "  $0 22.04    # Ubuntu 22.04 LTS"
    echo "  $0 20.04    # Ubuntu 20.04 LTS"
    exit 1
fi

VERSION=$1

# Проверка подключения к интернету
if ! curl -s --head https://releases.ubuntu.com/ >/dev/null; then
    echo "Ошибка: Нет подключения к интернету или сайт недоступен"
    exit 1
fi

# Создание резервной копии
echo "Создание резервной копии конфигурации..."
cp packer/variables.pkr.hcl packer/variables.pkr.hcl.backup.$(date +%Y%m%d_%H%M%S)

# Обновление версии
get_ubuntu_info "$VERSION"

# Проверка обновленной конфигурации
echo "Проверка обновленной конфигурации..."
if command -v packer >/dev/null 2>&1; then
    cd packer
    if packer validate .; then
        echo "✓ Конфигурация Packer валидна"
    else
        echo "✗ Ошибка в конфигурации Packer"
        echo "Восстанавливаем резервную копию..."
        cp variables.pkr.hcl.backup.* variables.pkr.hcl
        exit 1
    fi
    cd ..
fi

echo ""
echo "=== Обновление завершено ==="
echo ""
echo "Версия Ubuntu обновлена на: $VERSION"
echo "Следующие шаги:"
echo "1. Проверьте конфигурацию: make validate"
echo "2. Пересоберите образы: make clean && make build"
echo ""
echo "Для отката изменений используйте резервную копию:"
echo "cp packer/variables.pkr.hcl.backup.* packer/variables.pkr.hcl"
