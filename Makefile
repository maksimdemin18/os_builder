# Makefile для автоматизации сборки и тестирования

.PHONY: help build test clean install-deps validate lint security-scan info

# Переменные
PROJECT_NAME := ubuntu-24.04-iso-builder
DIST_DIR := dist
TEST_RESULTS_DIR := test-results
PROFILES := base dw atpm arm prizm akts

# Цвета для вывода
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Помощь
help:
	@echo "$(GREEN)Ubuntu 24.04 LTS ISO Builder$(NC)"
	@echo ""
	@echo "Доступные команды:"
	@echo "  $(YELLOW)build$(NC)          - Собрать все ISO образы"
	@echo "  $(YELLOW)build-profile$(NC)  - Собрать конкретный профиль (make build-profile PROFILE=base)"
	@echo "  $(YELLOW)test$(NC)           - Запустить все тесты"
	@echo "  $(YELLOW)test-quick$(NC)     - Быстрые тесты (без ISO)"
	@echo "  $(YELLOW)test-iso$(NC)       - Тестирование ISO образов"
	@echo "  $(YELLOW)validate$(NC)       - Валидация конфигурации"
	@echo "  $(YELLOW)lint$(NC)           - Проверка кода"
	@echo "  $(YELLOW)security-scan$(NC)  - Сканирование безопасности"
	@echo "  $(YELLOW)clean$(NC)          - Очистка временных файлов"
	@echo "  $(YELLOW)install-deps$(NC)   - Установка зависимостей"
	@echo "  $(YELLOW)info$(NC)           - Информация о проекте"
	@echo ""
	@echo "Примеры:"
	@echo "  make build"
	@echo "  make build-profile PROFILE=base"
	@echo "  make test"
	@echo "  make validate"

# Установка зависимостей
install-deps:
	@echo "$(GREEN)Установка зависимостей...$(NC)"
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get update && \
		sudo apt-get install -y \
			packer \
			ansible \
			qemu-system-x86 \
			qemu-utils \
			genisoimage \
			squashfs-tools \
			xorriso \
			isolinux \
			syslinux-utils \
			python3-yaml \
			curl \
			wget; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y \
			packer \
			ansible \
			qemu-kvm \
			qemu-img \
			genisoimage \
			squashfs-tools \
			xorriso \
			syslinux \
			python3-pyyaml \
			curl \
			wget; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y \
			packer \
			ansible \
			qemu-kvm \
			qemu-img \
			genisoimage \
			squashfs-tools \
			xorriso \
			syslinux \
			python3-pyyaml \
			curl \
			wget; \
	else \
		echo "$(RED)Неподдерживаемая система. Установите зависимости вручную.$(NC)"; \
		echo "$(YELLOW)Для Ubuntu/Debian: apt-get install qemu-system-x86$(NC)"; \
		echo "$(YELLOW)Для CentOS/RHEL: yum install qemu-kvm$(NC)"; \
		echo "$(YELLOW)Для Fedora: dnf install qemu-kvm$(NC)"; \
		exit 1; \
	fi

# Валидация конфигурации
validate:
	@echo "$(GREEN)Валидация конфигурации...$(NC)"
	@cd packer && packer validate .
	@cd ansible && ansible-playbook --syntax-check playbooks/*.yml
	@echo "$(GREEN)Валидация завершена успешно$(NC)"

# Проверка кода
lint:
	@echo "$(GREEN)Проверка кода...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		find . -name "*.sh" -exec shellcheck {} \; ; \
	else \
		echo "$(YELLOW)shellcheck не установлен, пропускаем проверку shell скриптов$(NC)"; \
	fi
	@if command -v ansible-lint >/dev/null 2>&1; then \
		cd ansible && ansible-lint playbooks/ roles/; \
	else \
		echo "$(YELLOW)ansible-lint не установлен, пропускаем проверку Ansible$(NC)"; \
	fi

# Сканирование безопасности
security-scan:
	@echo "$(GREEN)Сканирование безопасности...$(NC)"
	@if command -v trivy >/dev/null 2>&1; then \
		trivy fs --security-checks vuln,config .; \
	else \
		echo "$(YELLOW)trivy не установлен, пропускаем сканирование$(NC)"; \
	fi

# Сборка всех профилей
build: validate
	@echo "$(GREEN)Сборка всех ISO образов...$(NC)"
	@mkdir -p $(DIST_DIR)
	@./live-build/build-all-profiles.sh

# Сборка конкретного профиля
build-profile: validate
	@if [ -z "$(PROFILE)" ]; then \
		echo "$(RED)Укажите профиль: make build-profile PROFILE=base$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Сборка профиля: $(PROFILE)$(NC)"
	@mkdir -p $(DIST_DIR)
	@cd live-build && ./mkiso.sh $(PROFILE)

# Быстрые тесты (без ISO)
test-quick:
	@echo "$(GREEN)Запуск быстрых тестов...$(NC)"
	@mkdir -p $(TEST_RESULTS_DIR)
	@./tests/test-packer.sh
	@./tests/test-ansible.sh
	@echo "$(GREEN)Быстрые тесты завершены$(NC)"

# Тестирование ISO образов
test-iso:
	@echo "$(GREEN)Тестирование ISO образов...$(NC)"
	@mkdir -p $(TEST_RESULTS_DIR)
	@./tests/test-iso.sh
	@echo "$(GREEN)Тестирование ISO завершено$(NC)"

# Полное тестирование
test: test-quick test-iso
	@echo "$(GREEN)Запуск полного тестирования...$(NC)"
	@./tests/run-all-tests.sh --iso
	@echo "$(GREEN)Полное тестирование завершено$(NC)"

# Очистка
clean:
	@echo "$(GREEN)Очистка временных файлов...$(NC)"
	@rm -rf $(DIST_DIR)/*
	@rm -rf $(TEST_RESULTS_DIR)/*
	@rm -rf packer/output-*
	@rm -rf live-build/work
	@rm -rf live-build/chroot
	@find . -name "*.log" -delete
	@find . -name "*.tmp" -delete
	@echo "$(GREEN)Очистка завершена$(NC)"

# CI/CD команды
ci-build: install-deps validate lint build

ci-test: test-quick

ci-full: ci-build ci-test

# Информация о проекте
info:
	@echo "$(GREEN)Информация о проекте:$(NC)"
	@echo "Название: $(PROJECT_NAME)"
	@echo "Профили: $(PROFILES)"
	@echo "Директория сборки: $(DIST_DIR)"
	@echo "Директория тестов: $(TEST_RESULTS_DIR)"
	@echo ""
	@echo "$(GREEN)Структура проекта:$(NC)"
	@tree -L 2 -I '__pycache__|*.pyc|.git'
