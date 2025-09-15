# Полное руководство для начинающих - OS Builder

## Что это такое?

OS Builder - это система для автоматического создания установочных дисков Ubuntu 24.04 LTS. Представьте, что вам нужно установить Ubuntu на 100 компьютеров с одинаковыми настройками - вместо ручной установки каждого, эта система создает "умный" установочный диск, который сам все настроит.

Подготовка системы

### Проверка системы

Убедитесь, что у вас Ubuntu 22.04 или новее:
\`\`\`bash
lsb_release -a
\`\`\`

Должно показать что-то вроде:
\`\`\`
Distributor ID: Ubuntu
Description:    Ubuntu 22.04.3 LTS
Release:        22.04
Codename:       jammy
\`\`\`

### Проверка свободного места

Нужно минимум 20 ГБ свободного места:
\`\`\`bash
df -h /
\`\`\`

Посмотрите на колонку "Avail" - там должно быть больше 20G.

### Проверка виртуализации

Проверьте, поддерживает ли ваш процессор виртуalizацию:
\`\`\`bash
egrep -c '(vmx|svm)' /proc/cpuinfo
\`\`\`

Если результат больше 0 - все хорошо. Если 0 - виртуализация не поддерживается или отключена в BIOS.

## Шаг 3: Установка зависимостей

### Автоматическая установка (рекомендуется)

Запустите скрипт автоматической установки:
\`\`\`bash
chmod +x scripts/install-deps-manual.sh
./scripts/install-deps-manual.sh
\`\`\`

Скрипт спросит пароль sudo несколько раз - это нормально.

### Ручная установка (если автоматическая не работает)

1. **Обновите систему:**
   \`\`\`bash
   sudo apt update
   sudo apt upgrade -y
   \`\`\`

2. **Установите основные пакеты:**
   \`\`\`bash
   sudo apt install -y \
     qemu-kvm libvirt-daemon-system libvirt-clients virtinst \
     cloud-image-utils xorriso isolinux syslinux-utils \
     p7zip-full curl jq wget git ansible python3-pip \
     build-essential
   \`\`\`

3. **Установите Packer:**
   \`\`\`bash
   # Скачиваем Packer
   PACKER_VERSION="1.11.2"
   curl -fsSL "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" -o /tmp/packer.zip
   
   # Устанавливаем
   sudo unzip -o /tmp/packer.zip -d /usr/local/bin
   sudo chmod +x /usr/local/bin/packer
   
   # Проверяем
   packer version
   \`\`\`

4. **Настройте права доступа:**
   \`\`\`bash
   # Добавляем пользователя в группы
   sudo usermod -a -G libvirt,kvm $USER
   
   # Перезагружаем группы (или перелогиньтесь)
   newgrp libvirt
   \`\`\`

5. **Проверьте установку:**
   \`\`\`bash
   # Проверяем KVM
   kvm-ok
   
   # Проверяем libvirt
   virsh list --all
   
   # Проверяем Packer
   packer version
   
   # Проверяем Ansible
   ansible --version
   \`\`\`

## Шаг 4: Исправление проблем с репозиториями

Если у вас Ubuntu 24.10 или возникают ошибки с репозиториями:

\`\`\`bash
chmod +x scripts/fix-repositories.sh
./scripts/fix-repositories.sh
\`\`\`

Этот скрипт автоматически переключит на стабильные репозитории Ubuntu 24.04.

## Шаг 5: Первая сборка

### Диагностика системы

Перед началом проверьте готовность системы:
\`\`\`bash
chmod +x scripts/diagnose-system.sh
./scripts/diagnose-system.sh
\`\`\`

Скрипт покажет, что работает, а что нужно исправить.

### Инициализация Packer

\`\`\`bash
cd packer
packer init .
cd ..
\`\`\`

### Генерация SSH ключей

Создайте SSH ключи для доступа к собранным системам:
\`\`\`bash
# Создаем директорию для ключей
mkdir -p keys

# Генерируем ключ для технической поддержки
ssh-keygen -t ed25519 -f keys/support_key -N "" -C "support@company.local"

# Генерируем ключ для администраторов
ssh-keygen -t ed25519 -f keys/admin_key -N "" -C "admin@company.local"

# Показываем публичные ключи (скопируйте их)
echo "=== Ключ поддержки ==="
cat keys/support_key.pub
echo "=== Ключ администратора ==="
cat keys/admin_key.pub
\`\`\`

### Настройка паролей

Создайте хеши паролей для пользователей:
\`\`\`bash
# Создаем хеш пароля для пользователя support
echo "Введите пароль для пользователя support:"
python3 -c "import crypt; print(crypt.crypt(input(), crypt.mksalt(crypt.METHOD_SHA512)))"

# Создаем хеш пароля для пользователя admin  
echo "Введите пароль для пользователя admin:"
python3 -c "import crypt; print(crypt.crypt(input(), crypt.mksalt(crypt.METHOD_SHA512)))"
\`\`\`

Сохраните полученные хеши - они понадобятся для настройки.

### Настройка autoinstall

Отредактируйте файл `packer/http/user-data` и добавьте ваши SSH ключи и пароли:

\`\`\`bash
nano packer/http/user-data
\`\`\`

Найдите секцию `identity` и обновите:
\`\`\`yaml
identity:
  hostname: ubuntu-server
  password: "$6$ваш_хеш_пароля_root"
  username: ubuntu
\`\`\`

Найдите секцию `user-data` и добавьте ваши ключи:
\`\`\`yaml
ssh_authorized_keys:
  - "ssh-ed25519 AAAA... support@company.local"
  - "ssh-ed25519 AAAA... admin@company.local"
\`\`\`

### Сборка базового образа

Теперь соберем базовый образ:

\`\`\`bash
cd packer

# Запускаем сборку с подробным выводом
PACKER_LOG=1 packer build -var 'profile=base' .
\`\`\`

Процесс займет 15-30 минут. Вы увидите:
1. Скачивание Ubuntu ISO (если еще не скачан)
2. Создание виртуальной машины
3. Автоматическую установку Ubuntu
4. Настройку системы через Ansible
5. Создание образа

### Создание установочного ISO

После успешной сборки базового образа создайте ISO:

\`\`\`bash
cd ../live-build

# Делаем скрипт исполняемым
chmod +x mkiso.sh

# Создаем ISO для профиля base
sudo ./mkiso.sh base
\`\`\`

Готовый ISO будет в папке `dist/`:
\`\`\`bash
ls -lh dist/
\`\`\`

## Шаг 6: Тестирование

### Быстрый тест

Проверьте созданный ISO:
\`\`\`bash
# Делаем скрипт тестирования исполняемым
chmod +x live-build/test-iso.sh

# Запускаем тест
./live-build/test-iso.sh dist/ubuntu-24.04-base.iso
\`\`\`

### Полный тест в виртуальной машине

Запустите ISO в QEMU для полного тестирования:
\`\`\`bash
# Создаем виртуальный диск для установки
qemu-img create -f qcow2 /tmp/test-disk.qcow2 20G

# Запускаем виртуальную машину
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048 \
  -cpu host \
  -cdrom dist/ubuntu-24.04-base.iso \
  -hda /tmp/test-disk.qcow2 \
  -boot d \
  -vnc :1
\`\`\`

Подключитесь к VNC на порту 5901 для просмотра установки.

## Шаг 7: Создание других профилей

### Сборка профиля для рабочих станций (dw)

\`\`\`bash
cd packer
packer build -var 'profile=dw' .
cd ../live-build
sudo ./mkiso.sh dw
\`\`\`

### Сборка всех профилей

\`\`\`bash
# Делаем скрипт исполняемым
chmod +x live-build/build-all-profiles.sh

# Запускаем сборку всех профилей
./live-build/build-all-profiles.sh
\`\`\`

## Шаг 8: Настройка профилей

### Добавление пакетов в профиль

Отредактируйте файл профиля, например `profiles/base.yaml`:

\`\`\`bash
nano profiles/base.yaml
\`\`\`

Добавьте нужные пакеты в секцию `packages`:
\`\`\`yaml
packages:
  - htop
  - mc
  - vim
  - curl
  - wget
  - git
  - ваш-новый-пакет
\`\`\`

### Создание собственного профиля

1. Скопируйте базовый профиль:
   \`\`\`bash
   cp profiles/base.yaml profiles/myprofile.yaml
   \`\`\`

2. Отредактируйте новый профиль:
   \`\`\`bash
   nano profiles/myprofile.yaml
   \`\`\`

3. Измените название и описание:
   \`\`\`yaml
   name: "MyProfile"
   description: "Мой собственный профиль"
   \`\`\`

4. Добавьте нужные пакеты и настройки

5. Создайте Ansible роль:
   \`\`\`bash
   mkdir -p ansible/roles/profile/myprofile/tasks
   nano ansible/roles/profile/myprofile/tasks/main.yml
   \`\`\`

6. Соберите новый профиль:
   \`\`\`bash
   cd packer
   packer build -var 'profile=myprofile' .
   cd ../live-build
   sudo ./mkiso.sh myprofile
   \`\`\`

## Шаг 9: Изменение версии Ubuntu

### Обновление на Ubuntu 24.10

1. Найдите актуальный ISO:
   \`\`\`bash
   curl -s https://releases.ubuntu.com/24.10/ | grep "live-server-amd64.iso"
   \`\`\`

2. Получите контрольную сумму:
   \`\`\`bash
   curl -s https://releases.ubuntu.com/24.10/SHA256SUMS | grep live-server-amd64.iso
   \`\`\`

3. Обновите конфигурацию:
   \`\`\`bash
   nano packer/variables.pkr.hcl
   \`\`\`

   Измените:
   ```hcl
   variable "iso_url" {
     default = "https://releases.ubuntu.com/24.10/ubuntu-24.10-live-server-amd64.iso"
   }
   
   variable "iso_checksum" {
     default = "sha256:новая_контрольная_сумма"
   }
   \`\`\`

4. Пересоберите образы:
   \`\`\`bash
   cd packer
   packer build .
   \`\`\`

## Шаг 10: Решение проблем

### Проблема: "Permission denied" при запуске скриптов

**Решение:**
\`\`\`bash
chmod +x scripts/*.sh
chmod +x live-build/*.sh
\`\`\`

### Проблема: "KVM not available"

**Решение:**
1. Проверьте поддержку виртуализации:
   \`\`\`bash
   egrep -c '(vmx|svm)' /proc/cpuinfo
   \`\`\`

2. Включите виртуализацию в BIOS

3. Добавьте пользователя в группы:
   \`\`\`bash
   sudo usermod -a -G libvirt,kvm $USER
   newgrp libvirt
   \`\`\`

### Проблема: "Repository not found" или 404 ошибки

**Решение:**
\`\`\`bash
./scripts/fix-repositories.sh
\`\`\`

### Проблема: "No space left on device"

**Решение:**
1. Очистите временные файлы:
   \`\`\`bash
   sudo apt clean
   rm -rf /tmp/packer*
   \`\`\`

2. Проверьте место:
   \`\`\`bash
   df -h
   \`\`\`

### Проблема: Packer "зависает" на установке

**Решение:**
1. Увеличьте таймауты в `packer/main.pkr.hcl`:
   ```hcl
   boot_wait = "10s"
   ssh_timeout = "30m"
   \`\`\`

2. Проверьте логи:
   \`\`\`bash
   PACKER_LOG=1 packer build .
   \`\`\`

## Шаг 11: Автоматизация

### Настройка автоматической сборки

Создайте скрипт для регулярной пересборки:

\`\`\`bash
cat > auto-build.sh << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/os-builder.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Начало автоматической сборки" >> $LOG_FILE

# Обновляем репозиторий (если используется Git)
git pull >> $LOG_FILE 2>&1

# Собираем все профили
./live-build/build-all-profiles.sh >> $LOG_FILE 2>&1

# Тестируем образы
for iso in dist/*.iso; do
    echo "[$DATE] Тестирование $iso" >> $LOG_FILE
    ./live-build/test-iso.sh "$iso" >> $LOG_FILE 2>&1
done

echo "[$DATE] Автоматическая сборка завершена" >> $LOG_FILE
EOF

chmod +x auto-build.sh
\`\`\`

### Настройка cron для еженедельной сборки

\`\`\`bash
# Добавляем задачу в cron
(crontab -l 2>/dev/null; echo "0 2 * * 1 cd $(pwd) && ./auto-build.sh") | crontab -
\`\`\`

## Полезные команды

\`\`\`bash
# Просмотр логов сборки
tail -f /tmp/packer-build.log

# Проверка размера образов
ls -lh dist/

# Очистка временных файлов
rm -rf /tmp/packer*
sudo apt clean

# Проверка статуса виртуализации
systemctl status libvirtd

# Список всех ISO образов
find . -name "*.iso" -exec ls -lh {} \;

# Проверка контрольных сумм
sha256sum dist/*.iso

# Монтирование ISO для проверки содержимого
sudo mkdir /mnt/iso
sudo mount -o loop dist/ubuntu-24.04-base.iso /mnt/iso
ls -la /mnt/iso/
sudo umount /mnt/iso
\`\`\`

## Заключение

Теперь у вас есть полностью настроенная система для создания установочных образов Ubuntu. Вы можете:

1. **Создавать образы** для разных профилей
2. **Добавлять пакеты** через конфигурационные файлы
3. **Менять версии** Ubuntu
4. **Тестировать образы** автоматически
5. **Автоматизировать сборку** через cron

При возникновении проблем обращайтесь к разделу "Решение проблем" или запускайте диагностический скрипт:
\`\`\`bash
./scripts/diagnose-system.sh
\`\`\`

Удачи в использовании OS Builder! 🚀
