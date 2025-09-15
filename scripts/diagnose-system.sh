#!/bin/bash

# Скрипт для полной диагностики системы

echo "=== Полная диагностика системы ==="
echo "Дата: $(date)"
echo "Пользователь: $USER"
echo ""

# Информация о системе
echo "1. ИНФОРМАЦИЯ О СИСТЕМЕ"
echo "========================"
uname -a
echo ""
if [ -f /etc/os-release ]; then
    cat /etc/os-release
fi
echo ""

# Ресурсы системы
echo "2. РЕСУРСЫ СИСТЕМЫ"
echo "=================="
echo "CPU:"
lscpu | grep -E "(Model name|CPU$$s$$|Thread|Core)"
echo ""
echo "Память:"
free -h
echo ""
echo "Диск:"
df -h
echo ""

# Виртуализация
echo "3. ВИРТУАЛИЗАЦИЯ"
echo "================"
echo "KVM поддержка:"
if [ -c /dev/kvm ]; then
    echo "   ✓ /dev/kvm доступен"
    ls -la /dev/kvm
else
    echo "   ✗ /dev/kvm недоступен"
fi
echo ""

echo "Группы пользователя:"
groups
echo ""

echo "Процессы виртуализации:"
ps aux | grep -E "(qemu|kvm|libvirt)" | grep -v grep || echo "Нет активных процессов"
echo ""

# Сетевые настройки
echo "4. СЕТЬ"
echo "======="
echo "Сетевые интерфейсы:"
ip addr show | grep -E "(inet |UP|DOWN)"
echo ""

echo "DNS:"
cat /etc/resolv.conf
echo ""

# Установленные пакеты
echo "5. УСТАНОВЛЕННЫЕ ПАКЕТЫ"
echo "======================="
REQUIRED_PACKAGES=("packer" "ansible" "qemu-system-x86" "qemu-img" "genisoimage" "xorriso")
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if command -v "$pkg" >/dev/null 2>&1; then
        VERSION=$(command -v "$pkg" && "$pkg" --version 2>/dev/null | head -1 || echo "версия неизвестна")
        echo "   ✓ $pkg: $VERSION"
    else
        echo "   ✗ $pkg: НЕ УСТАНОВЛЕН"
    fi
done
echo ""

# Проверка репозиториев
echo "6. РЕПОЗИТОРИИ"
echo "=============="
echo "Sources.list:"
head -10 /etc/apt/sources.list
echo ""

echo "Последнее обновление apt:"
stat /var/lib/apt/lists/ | grep Modify
echo ""

# Проверка проекта
echo "7. ПРОЕКТ"
echo "========="
echo "Структура проекта:"
if [ -f "Makefile" ]; then
    echo "   ✓ Makefile найден"
else
    echo "   ✗ Makefile не найден"
fi

if [ -d "packer" ]; then
    echo "   ✓ Директория packer найдена"
    ls -la packer/
else
    echo "   ✗ Директория packer не найдена"
fi

if [ -d "ansible" ]; then
    echo "   ✓ Директория ansible найдена"
else
    echo "   ✗ Директория ansible не найдена"
fi
echo ""

# Логи ошибок
echo "8. ЛОГИ ОШИБОК"
echo "=============="
echo "Последние ошибки в системном журнале:"
journalctl --since "1 hour ago" --priority=err --no-pager | tail -10 || echo "Нет ошибок"
echo ""

# Рекомендации
echo "9. РЕКОМЕНДАЦИИ"
echo "==============="
MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEM_GB" -lt 4 ]; then
    echo "⚠ ПАМЯТЬ: Рекомендуется минимум 4GB RAM (текущий: ${MEM_GB}GB)"
fi

FREE_GB=$(df -BG . | awk 'NR==2{print $4}' | sed 's/G//')
if [ "$FREE_GB" -lt 20 ]; then
    echo "⚠ ДИСК: Рекомендуется минимум 20GB свободного места (текущий: ${FREE_GB}GB)"
fi

if ! groups | grep -q kvm && [ -c /dev/kvm ]; then
    echo "⚠ KVM: Добавьте пользователя в группу kvm: sudo usermod -a -G kvm $USER"
fi

if ! command -v packer >/dev/null 2>&1; then
    echo "⚠ PACKER: Установите Packer для сборки образов"
fi

echo ""
echo "=== Диагностика завершена ==="
echo ""
echo "Для исправления проблем:"
echo "1. Запустите: ./scripts/fix-repositories.sh"
echo "2. Запустите: ./scripts/install-deps-manual.sh"
echo "3. Запустите: ./scripts/fix-common-issues.sh"
