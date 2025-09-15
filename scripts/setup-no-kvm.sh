#!/bin/bash

# Скрипт для настройки сборки без KVM
# Использование: ./setup-no-kvm.sh

set -e

echo "=== Настройка сборки без KVM ==="

# Проверяем текущую конфигурацию
if grep -q 'accelerator.*=.*"kvm"' packer/main.pkr.hcl; then
    echo "Обнаружена KVM конфигурация, переключаем на TCG..."
    
    # Создаем резервную копию
    cp packer/main.pkr.hcl packer/main.pkr.hcl.backup.$(date +%Y%m%d_%H%M%S)
    
    # Заменяем KVM на TCG
    sed -i 's/accelerator.*=.*"kvm"/accelerator      = "tcg"/' packer/main.pkr.hcl
    
    echo "✓ Переключено на программную эмуляцию (TCG)"
else
    echo "✓ KVM уже отключен или не настроен"
fi

# Проверяем и настраиваем QEMU параметры для лучшей производительности без KVM
echo "Оптимизация QEMU параметров для работы без KVM..."

# Создаем оптимизированный конфиг для виртуальных машин
cat > packer/qemu-no-kvm.pkrvars.hcl << 'EOF'
# Конфигурация для работы без KVM (на виртуальных машинах)

# Уменьшаем ресурсы для стабильной работы
memory = "1536"
cpus = "1"

# Увеличиваем таймауты
ssh_timeout = "60m"
boot_wait = "10s"

# Дополнительные QEMU аргументы для оптимизации
qemu_args = [
  ["-cpu", "qemu64"],
  ["-machine", "type=pc,accel=tcg"],
  ["-netdev", "user,id=net0,hostfwd=tcp::{{ .SSHHostPort }}-:22"],
  ["-device", "e1000,netdev=net0"],
  ["-rtc", "base=utc"],
  ["-no-hpet"],
  ["-no-shutdown"]
]
EOF

echo "✓ Создан оптимизированный конфиг: packer/qemu-no-kvm.pkrvars.hcl"

# Проверяем доступность QEMU
if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "⚠ QEMU не найден. Устанавливаем..."
    
    # Определяем дистрибутив
    if [ -f /etc/debian_version ]; then
        sudo apt-get update
        sudo apt-get install -y qemu-system-x86 qemu-utils
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y qemu-kvm qemu-img
    else
        echo "Неизвестный дистрибутив. Установите QEMU вручную."
        exit 1
    fi
else
    echo "✓ QEMU найден: $(qemu-system-x86_64 --version | head -1)"
fi

# Создаем скрипт для сборки без KVM
cat > build-no-kvm.sh << 'EOF'
#!/bin/bash

# Скрипт сборки образов без KVM
set -e

echo "=== Сборка образов без KVM ==="

# Проверяем наличие локальных пакетов
if [ -d "local-packages" ] && [ "$(ls -A local-packages)" ]; then
    echo "Найдены локальные пакеты:"
    ls -la local-packages/
else
    echo "Локальные пакеты не найдены. Создаем пустую директорию..."
    mkdir -p local-packages
fi

# Запускаем сборку с оптимизированными параметрами
cd packer

echo "Запуск Packer с TCG ускорением..."
PACKER_LOG=1 packer build \
    -var-file="qemu-no-kvm.pkrvars.hcl" \
    -var-file="variables.pkr.hcl" \
    .

echo "✓ Сборка завершена"
echo "Образы доступны в директории: output/"
EOF

chmod +x build-no-kvm.sh

echo "✓ Создан скрипт сборки: build-no-kvm.sh"

# Создаем README для работы без KVM
cat > docs/NO_KVM_SETUP.md << 'EOF'
# Работа без KVM

Данная конфигурация предназначена для сборки образов на виртуальных машинах, где KVM недоступен.

## Особенности

- Использует программную эмуляцию TCG вместо KVM
- Оптимизированные параметры для стабильной работы
- Уменьшенные ресурсы (1.5GB RAM, 1 CPU)
- Увеличенные таймауты

## Использование

1. **Настройка**:
   ```bash
   ./scripts/setup-no-kvm.sh
