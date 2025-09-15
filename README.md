# OS Builder - Автоматизированная сборка Ubuntu 24.04 LTS

Система автоматизированной сборки установочных ISO-образов Ubuntu 24.04 LTS с поддержкой различных профилей и полностью автоматической установки.

## Возможности

- 🚀 Автоматизированная сборка ISO с помощью Packer и Ansible
- 📦 Поддержка профилей: `base`, `dw`, `atpm`, `arm`, `prizm`, `akts`
- 🔧 Фиксированная схема разделов (EFI + ext4 root + swap-файл)
- 🎯 Полностью автоматическая установка без участия оператора
- 📊 Встроенный мониторинг (auditd, zabbix-agent2, node_exporter, promtail)
- 🔄 CI/CD пайплайн для автоматической сборки
- 🧪 Автоматическое тестирование и верификация

## Структура проекта

\`\`\`
os-builder/
├── README.md                    # Этот файл
├── docs/                        # Документация
│   ├── HOWTO.md                # Подробное руководство
│   └── PROFILES.md             # Описание профилей
├── packer/                      # Конфигурация Packer
│   ├── main.pkr.hcl            # Основная конфигурация
│   ├── variables.pkr.hcl       # Переменные
│   └── http/                   # Файлы для autoinstall
├── ansible/                     # Роли и плейбуки Ansible
│   ├── inventories/
│   ├── playbooks/
│   └── roles/
├── live-build/                  # Скрипты сборки ISO
├── profiles/                    # Конфигурации профилей
├── tests/                       # Тесты и верификация
└── ci/                         # CI/CD конфигурация
\`\`\`

## Быстрый старт

### Требования

- Ubuntu 22.04+ или аналогичная система
- KVM/QEMU для виртуализации
- Ansible 2.9+
- Packer 1.8+
- 20+ ГБ свободного места

### Установка зависимостей

\`\`\`bash
# Установка системных пакетов
sudo apt-get update
sudo apt-get install -y qemu-kvm libvirt-daemon-system virtinst \
  cloud-image-utils xorriso isolinux p7zip-full curl jq ansible

# Установка Packer
curl -fsSL https://releases.hashicorp.com/packer/1.11.2/packer_1.11.2_linux_amd64.zip -o /tmp/packer.zip
sudo unzip -o /tmp/packer.zip -d /usr/local/bin

# Добавление пользователя в группу libvirt
sudo usermod -a -G libvirt $USER
\`\`\`

### Сборка базового образа

\`\`\`bash
# Клонирование репозитория
git clone <repository-url> os-builder
cd os-builder

# Инициализация Packer
cd packer
packer init .

# Сборка базового образа
packer build .

# Сборка ISO
cd ../live-build
sudo ./mkiso.sh
\`\`\`

## Профили

| Профиль | Описание | Дополнительные компоненты |
|---------|----------|---------------------------|
| `base` | Базовая система | Только основные инструменты |
| `dw` | Data Warehouse | RabbitMQ, MariaDB |
| `atpm` | ATPM система | Специфичные для ATPM пакеты |
| `arm` | ARM система | ARM-специфичные настройки |
| `prizm` | Prizm система | Prizm-специфичные компоненты |
| `akts` | AKTS система | Docker, AKTS-компоненты |

## Управление пакетами

### Добавление пакетов в профиль

Отредактируйте файл `profiles/<profile>.yaml`:

\`\`\`yaml
packages:
  - новый-пакет-1
  - новый-пакет-2
\`\`\`

### Изменение версии Ubuntu

1. Обновите `packer/variables.pkr.hcl`:
```hcl
variable "iso_url" {
  default = "https://releases.ubuntu.com/24.10/ubuntu-24.10-live-server-amd64.iso"
}
