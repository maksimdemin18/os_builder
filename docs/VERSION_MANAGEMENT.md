# Управление версиями Ubuntu

Этот документ описывает, как управлять версиями Ubuntu в системе сборки.

## Поддерживаемые версии

- **Ubuntu 24.04 LTS** (Noble Numbat) - рекомендуется
- **Ubuntu 22.04 LTS** (Jammy Jellyfish) - стабильная
- **Ubuntu 20.04 LTS** (Focal Fossa) - устаревшая

## Смена версии Ubuntu

### Автоматическое обновление

\`\`\`bash
# Обновление на Ubuntu 24.04 LTS
./scripts/update-ubuntu-version.sh 24.04

# Обновление на Ubuntu 22.04 LTS
./scripts/update-ubuntu-version.sh 22.04

# Обновление на Ubuntu 20.04 LTS
./scripts/update-ubuntu-version.sh 20.04
\`\`\`

### Ручное обновление

1. **Найдите актуальную информацию**:
\`\`\`bash
# Перейдите на https://releases.ubuntu.com/24.04/
# Найдите файл ubuntu-24.04.1-live-server-amd64.iso
# Скопируйте URL и контрольную сумму SHA256
\`\`\`

2. **Обновите конфигурацию**:
\`\`\`bash
nano packer/variables.pkr.hcl
\`\`\`

Измените следующие переменные:
```hcl
variable "iso_url" {
  default = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
}

variable "iso_checksum" {
  default = "sha256:новая_контрольная_сумма"
}

variable "ubuntu_version" {
  default = "24.04"
}
