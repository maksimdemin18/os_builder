#!/bin/bash

# Скрипт для исправления типичных проблем при установке

set -e

echo "=== Исправление типичных проблем ==="

# Определение дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo "Не удалось определить дистрибутив"
    exit 1
fi

echo "Обнаружен дистрибутив: $OS $VER"

# Исправление проблем с пакетами QEMU
echo "1. Исправление пакетов QEMU..."
case "$OS" in
    *Ubuntu*|*Debian*)
        # Для Ubuntu/Debian правильное название пакета qemu-system-x86
        if ! dpkg -l | grep -q qemu-system-x86; then
            echo "Устанавливаем qemu-system-x86..."
            sudo apt-get update
            sudo apt-get install -y qemu-system-x86 qemu-utils
        fi
        ;;
    *CentOS*|*Red\ Hat*)
        if ! rpm -qa | grep -q qemu-kvm; then
            echo "Устанавливаем qemu-kvm..."
            sudo yum install -y qemu-kvm qemu-img
        fi
        ;;
    *Fedora*)
        if ! rpm -qa | grep -q qemu-kvm; then
            echo "Устанавливаем qemu-kvm..."
            sudo dnf install -y qemu-kvm qemu-img
        fi
        ;;
esac

# Проверка и установка Packer
echo "2. Проверка Packer..."
if ! command -v packer >/dev/null 2>&1; then
    echo "Устанавливаем Packer..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install -y packer
fi

# Проверка и установка Ansible
echo "3. Проверка Ansible..."
if ! command -v ansible >/dev/null 2>&1; then
    echo "Устанавливаем Ansible..."
    case "$OS" in
        *Ubuntu*|*Debian*)
            sudo apt-get install -y ansible
            ;;
        *CentOS*|*Red\ Hat*)
            sudo yum install -y ansible
            ;;
        *Fedora*)
            sudo dnf install -y ansible
            ;;
    esac
fi

# Проверка прав доступа к KVM
echo "4. Проверка прав доступа к KVM..."
if [ -c /dev/kvm ]; then
    if ! groups | grep -q kvm; then
        echo "Добавляем пользователя в группу kvm..."
        sudo usermod -a -G kvm $USER
        echo "ВНИМАНИЕ: Перелогиньтесь для применения изменений группы!"
    fi
else
    echo "ПРЕДУПРЕЖДЕНИЕ: /dev/kvm не найден. KVM может быть недоступен."
fi

# Создание необходимых директорий
echo "5. Создание директорий..."
mkdir -p dist
mkdir -p test-results
mkdir -p packer/output
mkdir -p live-build/work

echo "6. Исправление синтаксиса Packer файлов..."
if command -v packer >/dev/null 2>&1; then
    if [ -d "packer" ]; then
        cd packer
        if ! packer validate . 2>/dev/null; then
            echo "Исправляем синтаксис main.pkr.hcl..."
            if [ -f "main.pkr.hcl" ]; then
                # Создаем резервную копию
                cp main.pkr.hcl main.pkr.hcl.backup
                
                # Исправляем синтаксис переменных - каждая переменная на новой строке
                sed -i '/^variable /,/}$/{
                    s/variable "$$[^"]*$$" *{ *type *= *$$[^}]*$$ *default *= *$$[^}]*$$ *}/variable "\1" {\n  type = \2\n  default = \3\n}/
                }' main.pkr.hcl
            else
                echo "Файл main.pkr.hcl не найден в директории packer/"
            fi
        fi
        cd ..
    else
        echo "Директория packer/ не найдена"
    fi
fi

echo "=== Исправление завершено ==="
echo ""
echo "Следующие шаги:"
echo "1. Если вы были добавлены в группу kvm, перелогиньтесь"
echo "2. Запустите: make validate"
echo "3. Если валидация прошла успешно, запустите: make build-profile PROFILE=base"
