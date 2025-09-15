#!/usr/bin/env bash
# Firstboot скрипт для настройки системы после установки
# Выполняется один раз при первой загрузке

set -euo pipefail

# Настройка логирования
LOG="/var/log/firstboot.log"
exec > >(tee -a "$LOG") 2>&1

echo "=== Firstboot started at $(date) ==="

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting firstboot configuration..."

# Определение профиля системы
PROFILE="base"
if [ -s /etc/os-profile ]; then
    PROFILE="$(tr -d ' \t\n\r' </etc/os-profile)"
fi
log "Selected profile: $PROFILE"

# Логирование информации о системе
log "=== System Information ==="
log "Hostname: $(hostname)"
log "Kernel: $(uname -r)"
log "Architecture: $(uname -m)"
log "Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"

# Логирование информации о дисках
log "=== Disk Information ==="
lsblk -o NAME,TYPE,SIZE,ROTA,TRAN | tee -a "$LOG"
df -h | tee -a "$LOG"

# Определение типа носителя
ROOT_DEV=$(findmnt -no SOURCE /)
DISK_NAME=$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null || echo "unknown")
if [ "$DISK_NAME" != "unknown" ]; then
    DISK_TYPE=$(lsblk -dno ROTA "/dev/$DISK_NAME" 2>/dev/null || echo "unknown")
    DISK_TRAN=$(lsblk -dno TRAN "/dev/$DISK_NAME" 2>/dev/null || echo "unknown")
    
    case "$DISK_TYPE" in
        "0") STORAGE_TYPE="SSD" ;;
        "1") STORAGE_TYPE="HDD" ;;
        *) STORAGE_TYPE="Unknown" ;;
    esac
    
    if [ "$DISK_TRAN" = "nvme" ]; then
        STORAGE_TYPE="NVMe SSD"
    fi
    
    log "Storage type: $STORAGE_TYPE ($DISK_TRAN)"
else
    log "Storage type: Unknown"
fi

# Создание swap-файла (2x RAM, максимум 32GB)
log "=== Configuring Swap ==="
if ! swapon --show | grep -q .; then
    log "Creating swap file..."
    
    # Получение объема RAM в KB
    mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    mem_mb=$(( (mem_kb + 1023) / 1024 ))
    swap_mb=$(( mem_mb * 2 ))
    
    # Ограничение максимального размера swap (32GB)
    if [ $swap_mb -gt 32768 ]; then
        swap_mb=32768
        log "Limiting swap size to 32GB (was ${mem_mb}MB * 2)"
    fi
    
    log "Creating ${swap_mb}MB swap file..."
    
    # Создание swap-файла
    fallocate -l ${swap_mb}M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    
    # Добавление в fstab
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    
    # Активация swap
    swapon -a
    
    log "Swap file created and activated: ${swap_mb}MB"
else
    log "Swap already configured"
fi

# Расширение корневого раздела
log "=== Expanding Root Filesystem ==="
ROOT_DEV=$(findmnt -no SOURCE /)
PART_NAME=$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null || echo "")
PART_NUM=$(lsblk -no PARTNUM "$ROOT_DEV" 2>/dev/null || echo "")

if [ -n "$PART_NAME" ] && [ -n "$PART_NUM" ]; then
    log "Expanding partition /dev/$PART_NAME part $PART_NUM..."
    growpart "/dev/$PART_NAME" "$PART_NUM" 2>&1 | tee -a "$LOG" || log "Growpart failed or not needed"
    
    log "Resizing filesystem..."
    resize2fs "$ROOT_DEV" 2>&1 | tee -a "$LOG" || log "Resize2fs failed or not needed"
    
    log "Root filesystem expanded"
else
    log "Could not determine partition info for expansion"
fi

# Обновление системы
log "=== System Update ==="
export DEBIAN_FRONTEND=noninteractive

log "Updating package lists..."
apt-get update -y

log "Installing essential packages..."
apt-get install -y \
    atop \
    inxi \
    net-tools \
    gcc \
    make \
    wget \
    curl \
    unzip \
    htop \
    iotop \
    tree \
    vim \
    git \
    rsync \
    screen \
    tmux \
    lsof \
    strace \
    tcpdump \
    dnsutils \
    iputils-ping \
    telnet \
    nc \
    jq \
    python3 \
    python3-pip

# Установка и настройка auditd
log "=== Configuring Auditd ==="
apt-get install -y auditd audispd-plugins

# Базовая конфигурация auditd
cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Удаление всех предыдущих правил
-D

# Установка буфера
-b 8192

# Отказ в случае переполнения
-f 1

# Мониторинг изменений в системных файлах
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /etc/sudoers.d/ -p wa -k identity

# Мониторинг системных вызовов
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change
-a always,exit -F arch=b64 -S clock_settime -k time-change
-a always,exit -F arch=b32 -S clock_settime -k time-change

# Мониторинг сетевых изменений
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale

# Финализация правил
-e 2
EOF

systemctl enable auditd
systemctl start auditd || log "Auditd start failed, will retry later"

log "Auditd configured"

# Выполнение общих пост-инсталляционных скриптов
log "=== Running Common Post-install Scripts ==="
if [ -d /opt/postinstall.d ]; then
    for script in /opt/postinstall.d/*.sh; do
        if [ -e "$script" ]; then
            log "Executing: $script"
            bash "$script" 2>&1 | tee -a "$LOG" || log "Script $script failed"
        fi
    done
else
    log "No common post-install scripts found"
fi

# Выполнение профильных скриптов
log "=== Running Profile-specific Scripts ==="
PROFILE_DIR="/opt/postinstall.d/profiles/$PROFILE"
if [ -d "$PROFILE_DIR" ]; then
    log "Found profile directory: $PROFILE_DIR"
    for script in "$PROFILE_DIR"/*.sh; do
        if [ -e "$script" ]; then
            log "Executing profile script: $script"
            bash "$script" 2>&1 | tee -a "$LOG" || log "Profile script $script failed"
        fi
    done
else
    log "No profile-specific scripts found for profile: $PROFILE"
fi

# Настройка системных сервисов
log "=== Configuring System Services ==="

# Отключение ненужных сервисов
DISABLE_SERVICES="bluetooth cups avahi-daemon"
for service in $DISABLE_SERVICES; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        log "Disabling service: $service"
        systemctl disable "$service" || log "Failed to disable $service"
    fi
done

# Включение нужных сервисов
ENABLE_SERVICES="ssh auditd"
for service in $ENABLE_SERVICES; do
    log "Enabling service: $service"
    systemctl enable "$service" || log "Failed to enable $service"
    systemctl start "$service" || log "Failed to start $service"
done

# Очистка системы
log "=== System Cleanup ==="
apt-get autoremove -y --purge
apt-get autoclean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
rm -rf /var/tmp/*

# Настройка логротации для firstboot
cat > /etc/logrotate.d/firstboot << 'EOF'
/var/log/firstboot.log {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

# Создание информационного файла о сборке
cat > /etc/os-build-info << EOF
Build Date: $(date)
Profile: $PROFILE
Storage Type: ${STORAGE_TYPE:-Unknown}
Kernel: $(uname -r)
Architecture: $(uname -m)
Memory: $(free -h | grep '^Mem:' | awk '{print $2}')
Swap: $(swapon --show --noheadings | awk '{print $3}' | head -1)
EOF

log "Build info saved to /etc/os-build-info"

# Отключение firstboot сервиса (выполняется только один раз)
log "=== Disabling Firstboot Service ==="
systemctl disable firstboot.service
rm -f /etc/systemd/system/firstboot.service
systemctl daemon-reload

log "Firstboot service disabled"

# Финальные проверки
log "=== Final System Checks ==="
log "Disk usage:"
df -h | tee -a "$LOG"

log "Memory usage:"
free -h | tee -a "$LOG"

log "Swap status:"
swapon --show | tee -a "$LOG"

log "Active services:"
systemctl list-units --type=service --state=active --no-pager | tee -a "$LOG"

log "=== Firstboot completed successfully at $(date) ==="

# Создание маркера успешного завершения
touch /var/log/firstboot.success
echo "$(date): Firstboot completed successfully" > /var/log/firstboot.success

exit 0
