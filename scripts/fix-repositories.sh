#!/bin/bash

# Скрипт для исправления проблем с репозиториями Ubuntu

set -e

echo "=== Исправление репозиториев Ubuntu ==="

# Проверка, что это Ubuntu
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$NAME" != *"Ubuntu"* ]]; then
        echo "Этот скрипт предназначен только для Ubuntu"
        exit 1
    fi
else
    echo "Не удалось определить дистрибутив"
    exit 1
fi

echo "Обнаружен: $PRETTY_NAME"

# Резервная копия sources.list
echo "1. Создание резервной копии sources.list..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)

# Определение кодового имени версии
CODENAME=$(lsb_release -cs)
echo "Кодовое имя версии: $CODENAME"

# Исправление репозиториев для нестабильных версий
case "$CODENAME" in
    "oracular"|"plucky"|"noble")
        echo "2. Обнаружена новая/нестабильная версия Ubuntu"
        echo "   Переключаемся на стабильные репозитории..."
        
        # Используем jammy (22.04 LTS) как стабильную базу
        cat << EOF | sudo tee /etc/apt/sources.list
# Стабильные репозитории Ubuntu 22.04 LTS (Jammy)
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

# Дополнительные репозитории
deb http://archive.canonical.com/ubuntu jammy partner
EOF
        ;;
    "jammy"|"focal"|"bionic")
        echo "2. Обнаружена стабильная версия Ubuntu"
        echo "   Проверяем и исправляем репозитории..."
        
        cat << EOF | sudo tee /etc/apt/sources.list
# Основные репозитории Ubuntu $VERSION_ID ($CODENAME)
deb http://archive.ubuntu.com/ubuntu/ $CODENAME main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $CODENAME-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $CODENAME-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ $CODENAME-security main restricted universe multiverse

# Дополнительные репозитории
deb http://archive.canonical.com/ubuntu $CODENAME partner
EOF
        ;;
    *)
        echo "2. Неизвестная версия Ubuntu: $CODENAME"
        echo "   Используем универсальные репозитории..."
        
        cat << EOF | sudo tee /etc/apt/sources.list
# Универсальные репозитории Ubuntu
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOF
        ;;
esac

# Очистка кэша пакетов
echo "3. Очистка кэша пакетов..."
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Обновление списка пакетов
echo "4. Обновление списка пакетов..."
sudo apt-get update

# Проверка доступности ключевых пакетов
echo "5. Проверка доступности пакетов..."
PACKAGES=("build-essential" "curl" "wget" "git" "python3")
for pkg in "${PACKAGES[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        echo "   ✓ $pkg доступен"
    else
        echo "   ✗ $pkg недоступен"
    fi
done

echo ""
echo "=== Исправление репозиториев завершено ==="
echo ""
echo "Если проблемы остались:"
echo "1. Проверьте подключение к интернету"
echo "2. Попробуйте другие зеркала: sudo apt-get update -o Acquire::http::Proxy=false"
echo "3. Восстановите оригинальный sources.list из резервной копии"
