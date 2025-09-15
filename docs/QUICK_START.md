# Быстрый старт - OS Builder

## За 5 минут

### 1. Скачайте проект
\`\`\`bash
# Из v0: нажмите три точки → Download ZIP → распакуйте
# Или клонируйте из Git:
git clone https://github.com/your-username/ubuntu-iso-builder.git
cd ubuntu-iso-builder
\`\`\`

### 2. Установите зависимости
\`\`\`bash
chmod +x scripts/install-deps-manual.sh
./scripts/install-deps-manual.sh
\`\`\`

### 3. Исправьте репозитории (если нужно)
\`\`\`bash
chmod +x scripts/fix-repositories.sh
./scripts/fix-repositories.sh
\`\`\`

### 4. Проверьте систему
\`\`\`bash
chmod +x scripts/diagnose-system.sh
./scripts/diagnose-system.sh
\`\`\`

### 5. Соберите базовый образ
\`\`\`bash
cd packer
packer init .
packer build -var 'profile=base' .
\`\`\`

### 6. Создайте ISO
\`\`\`bash
cd ../live-build
chmod +x mkiso.sh
sudo ./mkiso.sh base
\`\`\`

### 7. Готово!
Ваш ISO в папке `dist/ubuntu-24.04-base.iso`

## Тестирование
\`\`\`bash
chmod +x live-build/test-iso.sh
./live-build/test-iso.sh dist/ubuntu-24.04-base.iso
\`\`\`

## Что дальше?

- Читайте [полное руководство](BEGINNER_GUIDE.md) для детального изучения
- Изучите [профили](PROFILES.md) для настройки под ваши нужды
- Настройте [автоматизацию](HOWTO.md#ci-cd) для регулярных сборок

## Помощь

Если что-то не работает:
1. Запустите `./scripts/diagnose-system.sh`
2. Проверьте логи: `tail -f /tmp/packer-build.log`
3. Читайте раздел "Решение проблем" в [полном руководстве](BEGINNER_GUIDE.md)
