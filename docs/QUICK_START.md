# Быстрый старт - OS Builder

## За 5 минут

### 1.  Установите зависимости
\`\`\`bash
chmod +x scripts/install-deps-manual.sh
./scripts/install-deps-manual.sh
\`\`\`

### 2. Исправьте репозитории (если нужно)
\`\`\`bash
chmod +x scripts/fix-repositories.sh
./scripts/fix-repositories.sh
\`\`\`

### 3. Проверьте систему
\`\`\`bash
chmod +x scripts/diagnose-system.sh
./scripts/diagnose-system.sh
\`\`\`

### 4. Соберите базовый образ
\`\`\`bash
cd packer
packer init .
packer build -var 'profile=base' .
\`\`\`

### 5. Создайте ISO
\`\`\`bash
cd ../live-build
chmod +x mkiso.sh
sudo ./mkiso.sh base
\`\`\`

### 6. Готово!
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
