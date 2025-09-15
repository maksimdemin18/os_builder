#!/usr/bin/env bash
# Скрипт настройки локального CI/CD окружения

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $*${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}" >&2
}

# Проверка зависимостей
check_dependencies() {
    local deps=("docker" "docker-compose")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        error "Please install Docker and Docker Compose first"
        exit 1
    fi
    
    log "All dependencies satisfied"
}

# Создание конфигурационных файлов
create_configs() {
    log "Creating configuration files..."
    
    # Prometheus конфигурация
    mkdir -p "$SCRIPT_DIR/monitoring"
    cat > "$SCRIPT_DIR/monitoring/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'jenkins'
    static_configs:
      - targets: ['jenkins:8080']
    metrics_path: '/prometheus'
  
  - job_name: 'minio'
    static_configs:
      - targets: ['minio:9000']
    metrics_path: '/minio/v2/metrics/cluster'
EOF

    # Grafana конфигурация
    mkdir -p "$SCRIPT_DIR/monitoring/grafana/dashboards"
    mkdir -p "$SCRIPT_DIR/monitoring/grafana/datasources"
    
    cat > "$SCRIPT_DIR/monitoring/grafana/datasources/prometheus.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

    # Jenkins job конфигурация
    mkdir -p "$SCRIPT_DIR/jenkins/os-builder-build"
    cat > "$SCRIPT_DIR/jenkins/os-builder-build/config.xml" << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <description>Build Ubuntu 24.04 LTS ISO images</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.plugins.git.GitSCM">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <url>https://github.com/your-org/os-builder.git</url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>*/main</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
  </scm>
  <triggers>
    <hudson.triggers.SCMTrigger>
      <spec>H/15 * * * *</spec>
    </hudson.triggers.SCMTrigger>
  </triggers>
  <builders>
    <hudson.tasks.Shell>
      <command>
#!/bin/bash
set -e

echo "Starting OS Builder CI/CD Pipeline"

# Lint and validate
echo "Running linting..."
yamllint -d relaxed profiles/
shellcheck live-build/*.sh

# Build ISOs
echo "Building ISOs..."
cd live-build
sudo ./build-all-profiles.sh -j 2 -v

# Upload artifacts
echo "Uploading artifacts..."
# Upload to Minio or other storage
      </command>
    </hudson.tasks.Shell>
  </builders>
</project>
EOF

    log "Configuration files created"
}

# Запуск сервисов
start_services() {
    log "Starting CI/CD services..."
    
    cd "$SCRIPT_DIR"
    docker-compose up -d
    
    log "Waiting for services to start..."
    sleep 30
    
    # Проверка статуса сервисов
    local services=("jenkins" "minio" "prometheus" "grafana" "registry")
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            log "✓ $service is running"
        else
            error "✗ $service failed to start"
        fi
    done
}

# Настройка Jenkins
setup_jenkins() {
    log "Setting up Jenkins..."
    
    # Ожидание готовности Jenkins
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:8080 >/dev/null 2>&1; then
            break
        fi
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -eq $max_attempts ]; then
        error "Jenkins failed to start within timeout"
        return 1
    fi
    
    log "Jenkins is ready at http://localhost:8080"
    log "Default admin password:"
    docker-compose exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword || true
}

# Настройка Minio
setup_minio() {
    log "Setting up Minio..."
    
    # Создание bucket для артефактов
    docker-compose exec minio mc alias set local http://localhost:9000 admin admin123
    docker-compose exec minio mc mb local/os-builder-artifacts || true
    docker-compose exec minio mc policy set public local/os-builder-artifacts
    
    log "Minio is ready at http://localhost:9001"
    log "Credentials: admin/admin123"
}

# Показ информации о сервисах
show_info() {
    log "CI/CD Environment Ready!"
    echo
    echo "Services:"
    echo "  Jenkins:    http://localhost:8080"
    echo "  Minio:      http://localhost:9001"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana:    http://localhost:3000 (admin/admin)"
    echo "  Registry:   http://localhost:5000"
    echo
    echo "Commands:"
    echo "  Start:   cd $SCRIPT_DIR && docker-compose up -d"
    echo "  Stop:    cd $SCRIPT_DIR && docker-compose down"
    echo "  Logs:    cd $SCRIPT_DIR && docker-compose logs -f [service]"
    echo "  Status:  cd $SCRIPT_DIR && docker-compose ps"
}

# Остановка сервисов
stop_services() {
    log "Stopping CI/CD services..."
    cd "$SCRIPT_DIR"
    docker-compose down
    log "Services stopped"
}

# Очистка
cleanup() {
    log "Cleaning up CI/CD environment..."
    cd "$SCRIPT_DIR"
    docker-compose down -v
    docker system prune -f
    log "Cleanup completed"
}

# Показ справки
show_help() {
    cat << EOF
Usage: $0 [COMMAND]

Commands:
  start     Start CI/CD environment
  stop      Stop CI/CD environment
  restart   Restart CI/CD environment
  status    Show status of services
  cleanup   Stop and remove all data
  help      Show this help message

Examples:
  $0 start    # Start all services
  $0 status   # Check service status
  $0 cleanup  # Clean everything

EOF
}

# Основная функция
main() {
    case "${1:-start}" in
        start)
            check_dependencies
            create_configs
            start_services
            setup_jenkins
            setup_minio
            show_info
            ;;
        stop)
            stop_services
            ;;
        restart)
            stop_services
            sleep 5
            start_services
            ;;
        status)
            cd "$SCRIPT_DIR"
            docker-compose ps
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
