# Ubuntu 24.04 LTS переменные
variable "iso_url" {
  description = "URL для загрузки Ubuntu 24.04 LTS ISO"
  type        = string
  default     = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
}

variable "iso_checksum" {
  description = "SHA256 контрольная сумма ISO файла"
  type        = string
  default     = "sha256:e240e4b801f7bb68c20d1356b60968ad0c33a41d00d828e74ceb3364a0317be9"
}

# Настройки виртуальной машины
variable "vm_name" {
  description = "Имя виртуальной машины"
  type        = string
  default     = "ubuntu-2404"
}

variable "disk_size" {
  description = "Размер диска в МБ"
  type        = string
  default     = "10240"
}

variable "memory" {
  description = "Объем RAM в МБ"
  type        = string
  default     = "4096"
}

variable "cpus" {
  description = "Количество CPU"
  type        = string
  default     = "2"
}

# SSH настройки
variable "ssh_user" {
  description = "SSH пользователь для подключения"
  type        = string
  default     = "support"
}

variable "ssh_pass" {
  description = "SSH пароль для подключения"
  type        = string
  default     = "support"
  sensitive   = true
}

# Директории
variable "output_dir" {
  description = "Директория для выходных файлов"
  type        = string
  default     = "output"
}

# Профиль системы
variable "profile" {
  description = "Профиль системы (base, dw, atpm, arm, prizm, akts)"
  type        = string
  default     = "base"
}

# Настройки сети
variable "http_bind_address" {
  description = "IP адрес для HTTP сервера"
  type        = string
  default     = "0.0.0.0"
}

variable "http_port_min" {
  description = "Минимальный порт для HTTP сервера"
  type        = number
  default     = 8000
}

variable "http_port_max" {
  description = "Максимальный порт для HTTP сервера"
  type        = number
  default     = 8100
}

# Версии для обновления
variable "ubuntu_version" {
  description = "Версия Ubuntu (для будущих обновлений)"
  type        = string
  default     = "24.04"
}

variable "kernel_version" {
  description = "Версия ядра (опционально)"
  type        = string
  default     = ""
}

# Дополнительные настройки
variable "headless" {
  description = "Запуск в headless режиме"
  type        = bool
  default     = true
}

variable "use_backing_file" {
  description = "Использовать backing file для ускорения сборки"
  type        = bool
  default     = false
}

variable "qemu_accelerator" {
  description = "QEMU ускоритель (kvm, tcg, hvf)"
  type        = string
  default     = "kvm"
}

variable "boot_wait" {
  description = "Время ожидания загрузки"
  type        = string
  default     = "5s"
}

variable "shutdown_timeout" {
  description = "Таймаут выключения"
  type        = string
  default     = "5m"
}

variable "ssh_timeout" {
  description = "Таймаут SSH подключения"
  type        = string
  default     = "20m"
}
