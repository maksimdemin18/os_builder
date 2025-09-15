#!/bin/bash

# Скрипт для ручной установки зависимостей

set -e

echo "=== Установка зависимостей вручную ==="

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

# Обновление списка пакетов
echo "1. Обновление списка пакетов..."
case "$OS" in
    *Ubuntu*|*Debian*)
        sudo apt-get update
        ;;
    *CentOS*|*Red\ Hat*)
        sudo yum update -y
        ;;
    *Fedora*)
        sudo dnf update -y
        ;;
esac

# Установка базовых пакетов
echo "2. Установка базовых пакетов..."
case "$OS" in
    *Ubuntu*|*Debian*)
        sudo apt-get install -y \
            curl \
            wget \
            gnupg \
            software-properties-common \
            apt-transport-https \
            ca-certificates \
            lsb-release
        ;;
    *CentOS*|*Red\ Hat*)
        sudo yum install -y \
            curl \
            wget \
            gnupg2 \
            yum-utils
        ;;
    *Fedora*)
        sudo dnf install -y \
            curl \
            wget \
            gnupg2 \
            dnf-plugins-core
        ;;
esac

# Установка Packer
echo "3. Установка Packer..."
if ! command -v packer >/dev/null 2>&1; then
    case "$OS" in
        *Ubuntu*|*Debian*)
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
            sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
            sudo apt-get update
            sudo apt-get install -y packer
            ;;
        *CentOS*|*Red\ Hat*|*Fedora*)
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum install -y packer
            ;;
    esac
else
    echo "   ✓ Packer уже установлен"
fi

# Установка Ansible
echo "4. Установка Ansible..."
if ! command -v ansible >/dev/null 2>&1; then
    case "$OS" in
        *Ubuntu*|*Debian*)
            sudo apt-get install -y ansible
            ;;
        *CentOS*|*Red\ Hat*)
            sudo yum install -y epel-release
            sudo yum install -y ansible
            ;;
        *Fedora*)
            sudo dnf install -y ansible
            ;;
    esac
else
    echo "   ✓ Ansible уже установлен"
fi

# Установка QEMU
echo "5. Установка QEMU..."
case "$OS" in
    *Ubuntu*|*Debian*)
        sudo apt-get install -y \
            qemu-system-x86 \
            qemu-utils \
            qemu-kvm \
            libvirt-daemon-system \
            libvirt-clients \
            bridge-utils
        ;;
    *CentOS*|*Red\ Hat*)
        sudo yum install -y \
            qemu-kvm \
            qemu-img \
            libvirt \
            libvirt-python \
            libguestfs-tools \
            virt-install
        ;;
    *Fedora*)
        sudo dnf install -y \
            qemu-kvm \
            qemu-img \
            libvirt \
            libvirt-python \
            libguestfs-tools \
            virt-install
        ;;
esac

# Установка инструментов для создания ISO
echo "6. Установка инструментов для создания ISO..."
case "$OS" in
    *Ubuntu*|*Debian*)
        sudo apt-get install -y \
            genisoimage \
            xorriso \
            isolinux \
            syslinux-utils \
            squashfs-tools \
            mtools
        ;;
    *CentOS*|*Red\ Hat*|*Fedora*)
        sudo yum install -y \
            genisoimage \
            xorriso \
            syslinux \
            squashfs-tools \
            mtools
        ;;
esac

# Установка дополнительных инструментов
echo "7. Установка дополнительных инструментов..."
case "$OS" in
    *Ubuntu*|*Debian*)
        sudo apt-get install -y \
            make \
            git \
            jq \
            python3 \
            python3-pip \
            cloud-image-utils
        ;;
    *CentOS*|*Red\ Hat*|*Fedora*)
        sudo yum install -y \
            make \
            git \
            jq \
            python3 \
            python3-pip \
            cloud-utils
        ;;
esac

# Настройка KVM
echo "8. Настройка KVM..."
if [ -c /dev/kvm ]; then
    sudo usermod -a -G kvm $USER
    sudo usermod -a -G libvirt $USER
    echo "   ✓ Пользователь добавлен в группы kvm и libvirt"
    echo "   ⚠ ВАЖНО: Перелогиньтесь для применения изменений!"
else
    echo "   ⚠ /dev/kvm недоступен. Проверьте поддержку виртуализации в BIOS"
fi

# Создание необходимых директорий
echo "9. Создание директорий..."
mkdir -p dist
mkdir -p test-results
mkdir -p packer/output
mkdir -p live-build/work
mkdir -p logs

echo ""
echo "=== Установка завершена ==="
echo ""
echo "Следующие шаги:"
echo "1. Перелогиньтесь для применения изменений групп"
echo "2. Проверьте систему: ./scripts/check-system.sh"
echo "3. Исправьте проблемы: ./scripts/fix-common-issues.sh"
echo "4. Запустите валидацию: make validate"
