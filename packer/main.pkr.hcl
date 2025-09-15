packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }
  }
}

variable "iso_url" { 
  type = string 
}
variable "iso_checksum" { 
  type = string 
}
variable "ssh_user" { 
  type = string  
  default = "support" 
}
variable "ssh_pass" { 
  type = string  
  default = "support" 
}
variable "output_dir" { 
  type = string  
  default = "output" 
}
variable "vm_name" { 
  type = string  
  default = "ubuntu-2404" 
}
variable "disk_size" { 
  type = string  
  default = "8192" 
}
variable "memory" { 
  type = string  
  default = "2048" 
}
variable "cpus" { 
  type = string  
  default = "2" 
}

source "qemu" "ubuntu2404" {
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum
  headless         = true
  output_directory = "${var.output_dir}/${var.vm_name}"
  disk_size        = var.disk_size
  format           = "qcow2"
  accelerator      = "tcg"
  cpus             = var.cpus
  memory           = var.memory
  http_directory   = "http"
  ssh_username     = var.ssh_user
  ssh_password     = var.ssh_pass
  ssh_timeout      = "45m"
  boot_wait        = "5s"
  
  # Boot command для autoinstall
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "/<wait>",
    "linux<enter><wait>",
    " <end>",
    " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---",
    "<f10>"
  ]
  
  shutdown_command = "echo '${var.ssh_pass}' | sudo -S shutdown -P now"
  
  # Дополнительные настройки QEMU
  qemuargs = [
    ["-m", "${var.memory}M"],
    ["-smp", "cpus=${var.cpus}"],
    ["-netdev", "user,id=net0,hostfwd=tcp::{{ .SSHHostPort }}-:22"],
    ["-device", "virtio-net,netdev=net0"],
    ["-drive", "if=virtio,cache=writeback,discard=ignore,format=qcow2,file=output/${var.vm_name}/${var.vm_name}"]
  ]
}

build {
  sources = ["source.qemu.ubuntu2404"]

  # Ожидание завершения установки
  provisioner "shell" {
    inline = [
      "echo 'Waiting for system to be ready...'",
      "sudo cloud-init status --wait",
      "echo 'System is ready'"
    ]
  }

  # Проверка базовой установки
  provisioner "shell" {
    inline = [
      "echo 'Checking system status...'",
      "sudo systemctl is-active auditd || echo 'auditd not active yet'",
      "df -h /",
      "swapon --show || echo 'swap not configured yet'",
      "cat /etc/os-profile || echo 'base' > /tmp/profile",
      "echo 'Basic checks complete'"
    ]
  }

  provisioner "file" {
    source      = "../local-packages/"
    destination = "/tmp/local-packages/"
  }

  provisioner "shell" {
    inline = [
      "echo 'Installing local packages...'",
      "if [ -d /tmp/local-packages ]; then",
      "  sudo mkdir -p /opt/local-packages",
      "  sudo cp -r /tmp/local-packages/* /opt/local-packages/ || true",
      "  # Установка .deb пакетов",
      "  if ls /opt/local-packages/*.deb 1> /dev/null 2>&1; then",
      "    sudo dpkg -i /opt/local-packages/*.deb || true",
      "    sudo apt-get install -f -y",
      "  fi",
      "  # Создание локального репозитория",
      "  if ls /opt/local-packages/*.deb 1> /dev/null 2>&1; then",
      "    sudo apt-get install -y dpkg-dev",
      "    cd /opt/local-packages",
      "    sudo dpkg-scanpackages . /dev/null | sudo tee Packages > /dev/null",
      "    sudo gzip -k Packages",
      "    echo 'deb [trusted=yes] file:///opt/local-packages ./' | sudo tee /etc/apt/sources.list.d/local-packages.list",
      "    sudo apt-get update",
      "  fi",
      "fi",
      "echo 'Local packages installation complete'"
    ]
  }

  # Запуск Ansible для базовой конфигурации
  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/base.yml"
    inventory_file = "../ansible/inventories/local"
    user = var.ssh_user
    extra_arguments = [
      "--extra-vars", "ansible_sudo_pass=${var.ssh_pass}",
      "--extra-vars", "target_user=${var.ssh_user}"
    ]
  }

  # Запуск профильной конфигурации
  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/profile.yml"
    inventory_file = "../ansible/inventories/local"
    user = var.ssh_user
    extra_arguments = [
      "--extra-vars", "ansible_sudo_pass=${var.ssh_pass}"
    ]
  }

  # Верификация установки
  provisioner "ansible" {
    playbook_file = "../ansible/playbooks/verify.yml"
    inventory_file = "../ansible/inventories/local"
    user = var.ssh_user
    extra_arguments = [
      "--extra-vars", "ansible_sudo_pass=${var.ssh_pass}"
    ]
  }

  # Финальная очистка
  provisioner "shell" {
    inline = [
      "echo 'Final cleanup...'",
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo rm -rf /var/lib/apt/lists/*",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c",
      "echo 'Build complete'"
    ]
  }

  # Конвертация в различные форматы
  post-processor "shell-local" {
    inline = [
      "mkdir -p artifacts/qcow2 artifacts/raw artifacts/vmdk",
      "echo 'Converting to qcow2 (compressed)...'",
      "qemu-img convert -O qcow2 -c ${var.output_dir}/${var.vm_name}/${var.vm_name} artifacts/qcow2/${var.vm_name}-$(date +%Y%m%d).qcow2",
      "echo 'Converting to raw...'",
      "qemu-img convert -O raw ${var.output_dir}/${var.vm_name}/${var.vm_name} artifacts/raw/${var.vm_name}-$(date +%Y%m%d).raw",
      "echo 'Converting to vmdk...'",
      "qemu-img convert -O vmdk ${var.output_dir}/${var.vm_name}/${var.vm_name} artifacts/vmdk/${var.vm_name}-$(date +%Y%m%d).vmdk",
      "echo 'Generating checksums...'",
      "cd artifacts && find . -name '*.qcow2' -o -name '*.raw' -o -name '*.vmdk' | xargs sha256sum > checksums.txt",
      "echo 'Artifacts ready in artifacts/ directory'"
    ]
  }
}
