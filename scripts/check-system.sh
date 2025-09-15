#!/bin/bash

# Скрипт для проверки системных требований

echo "=== Проверка системных требований ==="

# Проверка ОС
echo "1. Операционная система:"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "   ✓ $PRETTY_NAME"
else
    echo "   ✗ Не удалось определить ОС"
    exit 1
fi

# Проверка архитектуры
echo "2. Архитектура:"
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    echo "   ✓ $ARCH (поддерживается)"
else
    echo "   ⚠ $ARCH (может не поддерживаться)"
fi

# Проверка памяти
echo "3. Оперативная память:"
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEM_GB" -ge 4 ]; then
    echo "   ✓ ${MEM_GB}GB (достаточно)"
else
    echo "   ⚠ ${MEM_GB}GB (рекомендуется минимум 4GB)"
fi

# Проверка свободного места
echo "4. Свободное место на диске:"
FREE_GB=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$FREE_GB" -ge 20 ]; then
    echo "   ✓ ${FREE_GB}GB (достаточно)"
else
    echo "   ⚠ ${FREE_GB}GB (рекомендуется минимум 20GB)"
fi

# Проверка KVM
echo "5. Виртуализация KVM:"
if [ -c /dev/kvm ]; then
    echo "   ✓ /dev/kvm доступен"
    if groups | grep -q kvm; then
        echo "   ✓ Пользователь в группе kvm"
    else
        echo "   ⚠ Пользователь НЕ в группе kvm (выполните: sudo usermod -a -G kvm $USER)"
    fi
else
    echo "   ✗ /dev/kvm недоступен (проверьте поддержку виртуализации в BIOS)"
fi

# Проверка команд
echo "6. Необходимые команды:"
COMMANDS=("packer" "ansible" "qemu-system-x86_64" "qemu-img" "genisoimage" "xorriso")
for cmd in "${COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "   ✓ $cmd"
    else
        # Проверяем альтернативные названия
        case "$cmd" in
            "qemu-system-x86_64")
                if command -v qemu-system-x86 >/dev/null 2>&1; then
                    echo "   ✓ qemu-system-x86 (альтернатива qemu-system-x86_64)"
                else
                    echo "   ✗ $cmd (установите: apt install qemu-system-x86)"
                fi
                ;;
            *)
                echo "   ✗ $cmd"
                ;;
        esac
    fi
done

echo ""
echo "=== Рекомендации ==="
if [ "$MEM_GB" -lt 4 ]; then
    echo "⚠ Увеличьте объем RAM до минимум 4GB для стабильной работы"
fi

if [ "$FREE_GB" -lt 20 ]; then
    echo "⚠ Освободите место на диске (рекомендуется минимум 20GB)"
fi

if ! groups | grep -q kvm && [ -c /dev/kvm ]; then
    echo "⚠ Добавьте пользователя в группу kvm: sudo usermod -a -G kvm $USER"
    echo "  После этого перелогиньтесь или выполните: newgrp kvm"
fi

echo ""
echo "Для исправления проблем запустите: ./scripts/fix-common-issues.sh"
