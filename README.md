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
├── README.md                          # Основная документация
├── Makefile                          # Команды сборки и управления
├── .gitignore                        # Игнорируемые файлы
├── LICENSE                           # Лицензия проекта
│
├── docs/                             # Документация
│   ├── BEGINNER_GUIDE.md            # Руководство для начинающих
│   ├── QUICK_START.md               # Быстрый старт
│   ├── LOCAL_PACKAGES.md            # Управление локальными пакетами
│   ├── TROUBLESHOOTING.md           # Решение проблем
│   └── VERSION_MANAGEMENT.md        # Управление версиями
│
├── packer/                          # Конфигурация Packer
│   ├── main.pkr.hcl                # Основная конфигурация
│   ├── variables.pkr.hcl           # Переменные
│   └── http/                       # Файлы для autoinstall
│       ├── user-data               # Конфигурация autoinstall
│       ├── meta-data               # Метаданные
│       └── seed/                   # Скрипты первого запуска
│           ├── firstboot.sh        # Скрипт первого запуска
│           └── firstboot.service   # Systemd сервис
│
├── ansible/                        # Конфигурация Ansible
│   ├── inventories/                # Инвентори
│   │   └── local                   # Локальный инвентори
│   ├── playbooks/                  # Playbook'и
│   │   ├── base.yml               # Базовая настройка
│   │   ├── profile.yml            # Настройка профилей
│   │   └── verify.yml             # Проверка системы
│   └── roles/                      # Роли Ansible
│       ├── baseline/               # Базовые настройки
│       ├── tooling/               # Инструменты
│       ├── monitoring/            # Мониторинг
│       ├── docker/                # Docker
│       └── profile/               # Профили
│           ├── base/              # Базовый профиль
│           ├── dw/                # Профиль DW
│           ├── atpm/              # Профиль ATPM
│           ├── arm/               # Профиль ARM
│           ├── prizm/             # Профиль PRIZM
│           └── akts/              # Профиль AKTS
│
├── profiles/                       # Конфигурации профилей
│   ├── base.yaml                   # Базовый профиль
│   ├── dw.yaml                     # Профиль DW
│   ├── atpm.yaml                   # Профиль ATPM
│   ├── arm.yaml                    # Профиль ARM
│   ├── prizm.yaml                  # Профиль PRIZM
│   └── akts.yaml                   # Профиль AKTS
│
├── live-build/                     # Скрипты создания ISO
│   ├── mkiso.sh                    # Основной скрипт создания ISO
│   ├── build-all-profiles.sh      # Сборка всех профилей
│   ├── test-iso.sh                 # Тестирование ISO
│   └── templates/                  # Шаблоны
│       └── grub.cfg.template       # Шаблон GRUB
│
├── scripts/                        # Утилиты и скрипты
│   ├── manage-local-packages.sh    # Управление локальными пакетами
│   ├── setup-no-kvm.sh            # Настройка без KVM
│   ├── update-ubuntu-version.sh   # Обновление версии Ubuntu
│   ├── fix-common-issues.sh       # Исправление проблем
│   ├── check-system.sh            # Проверка системы
│   ├── install-deps-manual.sh     # Ручная установка зависимостей
│   ├── fix-repositories.sh        # Исправление репозиториев
│   └── diagnose-system.sh          # Диагностика системы
│
├── local-packages/                 # Локальные пакеты
│   ├── debs/                       # .deb файлы
│   ├── sources/                    # Исходники пакетов
│   └── repo/                       # Локальный репозиторий
│
├── tests/                          # Тесты
│   ├── test-packer.sh             # Тесты Packer
│   ├── test-ansible.sh            # Тесты Ansible
│   ├── test-iso.sh                # Тесты ISO
│   ├── run-all-tests.sh           # Запуск всех тестов
│   └── molecule/                   # Molecule тесты
│       └── default/
│           ├── molecule.yml        # Конфигурация Molecule
│           ├── converge.yml        # Тест конвергенции
│           └── verify.yml          # Проверка результатов
│
├── ci/                             # CI/CD конфигурация
│   ├── docker-compose.yml         # Docker Compose для CI
│   └── setup-local-ci.sh          # Настройка локального CI
│
├── .github/                        # GitHub Actions
│   └── workflows/
│       ├── build-iso.yml          # Сборка ISO
│       ├── test-iso.yml           # Тестирование ISO
│       ├── update-base-image.yml  # Обновление базового образа
│       └── security-scan.yml      # Сканирование безопасности
│
└── dist/                           # Готовые образы
    ├── ubuntu-24.04-base.iso      # Базовый образ
    ├── ubuntu-24.04-dw.iso        # Образ DW
    ├── ubuntu-24.04-atpm.iso      # Образ ATPM
    ├── ubuntu-24.04-arm.iso       # Образ ARM
    ├── ubuntu-24.04-prizm.iso     # Образ PRIZM
    └── ubuntu-24.04-akts.iso      # Образ AKTS
\`\`\`

## Быстрый старт

1. **Клонируйте проект**:
   \`\`\`bash
   # Скачайте ZIP файл из v0 или создайте Git репозиторий
   git init
   git add .
   git commit -m "Initial commit"
   \`\`\`

2. **Установите зависимости**:
   \`\`\`bash
   chmod +x scripts/*.sh
   ./scripts/install-deps-manual.sh
   \`\`\`

3. **Настройте систему**:
   \`\`\`bash
   ./scripts/setup-no-kvm.sh  # Если работаете на ВМ
   ./scripts/fix-common-issues.sh
   \`\`\`

4. **Соберите образ**:
   \`\`\`bash
   make build-profile PROFILE=base
   \`\`\`

## Основные команды

\`\`\`bash
# Установка зависимостей
make install-deps

# Валидация конфигурации
make validate

# Сборка всех профилей
make build-all

# Сборка конкретного профиля
make build-profile PROFILE=base

# Сборка без KVM
make build-no-kvm

# Тестирование
make test

# Очистка
make clean
\`\`\`

## Управление пакетами

\`\`\`bash
# Добавить локальный пакет
./scripts/manage-local-packages.sh add package.deb

# Создать пакет из исходников
./scripts/manage-local-packages.sh build-from-source /path/to/source

# Обновить локальный репозиторий
./scripts/manage-local-packages.sh update-repo
\`\`\`

## Смена версии Ubuntu

\`\`\`bash
# Обновить до Ubuntu 24.04
./scripts/update-ubuntu-version.sh 24.04

# Проверить доступные версии
./scripts/update-ubuntu-version.sh --list
\`\`\`

## Поддержка

- 📖 [Руководство для начинающих](docs/BEGINNER_GUIDE.md)
- 🚀 [Быстрый старт](docs/QUICK_START.md)
- 📦 [Управление пакетами](docs/LOCAL_PACKAGES.md)
- 🔧 [Решение проблем](docs/TROUBLESHOOTING.md)
- 🔄 [Управление версиями](docs/VERSION_MANAGEMENT.md)

## Лицензия

MIT License - см. файл LICENSE для деталей.
\`\`\`

```makefile file="" isHidden
```


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
