#!/bin/bash

# =================================================================
# Скрипт развертывания May Messenger на сервер с RareBooks Service
# =================================================================

set -e  # Прерывать выполнение при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для цветного вывода
print_header() {
    echo -e "\n${BLUE}=================================================================="
    echo -e "$1"
    echo -e "==================================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Проверка, что скрипт запущен на сервере
check_server_environment() {
    print_header "Проверка окружения сервера"
    
    # Проверка наличия Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен!"
        exit 1
    fi
    print_success "Docker установлен: $(docker --version)"
    
    # Проверка наличия Docker Compose
    if ! command -v docker compose &> /dev/null; then
        print_error "Docker Compose не установлен!"
        exit 1
    fi
    print_success "Docker Compose установлен"
    
    # Проверка текущей директории
    if [ ! -f "docker-compose.yml" ]; then
        print_error "Файл docker-compose.yml не найден!"
        print_info "Убедитесь, что вы находитесь в директории /root/RareBooksDokploy"
        exit 1
    fi
    print_success "Найден docker-compose.yml"
}

# Проверка структуры MayMessenger
check_maymessenger_structure() {
    print_header "Проверка структуры May Messenger"
    
    if [ ! -d "MayMessenger/backend" ]; then
        print_error "Директория MayMessenger/backend не найдена!"
        print_info "Убедитесь, что архив may_messenger_backend.zip распакован правильно"
        exit 1
    fi
    print_success "Найдена директория MayMessenger/backend"
    
    if [ ! -f "MayMessenger/backend/Dockerfile" ]; then
        print_error "Dockerfile не найден в MayMessenger/backend/"
        exit 1
    fi
    print_success "Найден Dockerfile"
    
    if [ ! -f "MayMessenger/backend/MayMessenger.sln" ]; then
        print_error "MayMessenger.sln не найден в MayMessenger/backend/"
        exit 1
    fi
    print_success "Найден MayMessenger.sln"
    
    if [ ! -d "MayMessenger/backend/src" ]; then
        print_error "Директория src не найдена в MayMessenger/backend/"
        exit 1
    fi
    print_success "Найдена директория src"
}

# Создание backup
create_backup() {
    print_header "Создание резервных копий"
    
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    BACKUP_DIR="backups/$BACKUP_DATE"
    
    mkdir -p "$BACKUP_DIR"
    
    cp docker-compose.yml "$BACKUP_DIR/docker-compose.yml"
    print_success "Создан backup: $BACKUP_DIR/docker-compose.yml"
    
    cp nginx/nginx_prod.conf "$BACKUP_DIR/nginx_prod.conf"
    print_success "Создан backup: $BACKUP_DIR/nginx_prod.conf"
    
    echo "$BACKUP_DATE" > "$BACKUP_DIR/timestamp.txt"
    echo "$BACKUP_DIR" > .last_backup
}

# Проверка конфигурации Docker Compose
validate_docker_compose() {
    print_header "Проверка конфигурации Docker Compose"
    
    if docker compose config > /dev/null 2>&1; then
        print_success "Конфигурация Docker Compose валидна"
    else
        print_error "Ошибка в конфигурации Docker Compose!"
        docker compose config
        exit 1
    fi
}

# Запуск May Messenger сервисов
deploy_maymessenger() {
    print_header "Запуск May Messenger сервисов"
    
    print_info "Сборка и запуск контейнеров (это может занять несколько минут)..."
    
    # Сначала запускаем БД
    docker compose up -d db_maymessenger
    print_success "База данных May Messenger запущена"
    
    # Ждем готовности БД
    print_info "Ожидание инициализации базы данных (30 секунд)..."
    sleep 30
    
    # Проверяем статус БД
    if docker compose ps db_maymessenger | grep -q "Up"; then
        print_success "База данных готова"
    else
        print_error "База данных не запустилась!"
        docker compose logs db_maymessenger
        exit 1
    fi
    
    # Собираем и запускаем backend
    print_info "Сборка May Messenger backend..."
    docker compose build maymessenger_backend
    
    print_info "Запуск May Messenger backend..."
    docker compose up -d maymessenger_backend
    
    # Ждем готовности backend
    print_info "Ожидание запуска backend (90 секунд)..."
    for i in {90..1}; do
        printf "\r⏱️  Осталось: %2d секунд..." $i
        sleep 1
    done
    echo ""
    
    # Проверяем статус
    if docker compose ps maymessenger_backend | grep -q "Up"; then
        print_success "May Messenger backend запущен"
    else
        print_warning "May Messenger backend может быть не готов, проверяем логи..."
        docker compose logs maymessenger_backend --tail 30
    fi
}

# Перезапуск Nginx
restart_nginx() {
    print_header "Перезапуск Nginx"
    
    docker compose restart proxy
    
    print_info "Ожидание перезапуска Nginx (30 секунд)..."
    sleep 30
    
    if docker compose ps proxy | grep -q "Up"; then
        print_success "Nginx перезапущен успешно"
    else
        print_error "Nginx не запустился!"
        docker compose logs proxy --tail 30
        exit 1
    fi
}

# Проверка работоспособности
verify_deployment() {
    print_header "Проверка работоспособности"
    
    echo "=== Статус всех сервисов ==="
    docker compose ps
    echo ""
    
    print_info "Проверка May Messenger API..."
    if curl -k -s -o /dev/null -w "%{http_code}" https://messenger.rare-books.ru/health | grep -q "200"; then
        print_success "May Messenger API отвечает (health endpoint)"
    else
        print_warning "May Messenger API не отвечает на health endpoint"
        print_info "Проверяем логи..."
        docker compose logs maymessenger_backend --tail 20
    fi
    
    print_info "Проверка RareBooks..."
    if curl -k -s -o /dev/null -w "%{http_code}" https://www.rare-books.ru/ | grep -q "200"; then
        print_success "RareBooks работает нормально"
    else
        print_warning "RareBooks может быть недоступен"
    fi
}

# Вывод итоговой информации
print_summary() {
    print_header "✅ РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО!"
    
    echo -e "${GREEN}🎉 May Messenger успешно установлен!${NC}\n"
    
    echo "📡 Endpoints May Messenger:"
    echo "   - API Base:     https://messenger.rare-books.ru/api/"
    echo "   - Swagger UI:   https://messenger.rare-books.ru/swagger"
    echo "   - SignalR Hub:  wss://messenger.rare-books.ru/hubs/chat"
    echo "   - Health:       https://messenger.rare-books.ru/health"
    echo ""
    
    echo "✅ RareBooks работает как прежде:"
    echo "   - Web:          https://www.rare-books.ru/"
    echo "   - API:          https://www.rare-books.ru/api/"
    echo ""
    
    echo -e "${BLUE}🔐 Учетные данные May Messenger:${NC}"
    echo "   👤 Администратор: +79604243127 / ppAKiH1Y"
    echo "   🎫 Invite код:    WELCOME2024"
    echo ""
    
    echo -e "${BLUE}📊 Полезные команды:${NC}"
    echo ""
    echo "# Логи May Messenger:"
    echo "  docker compose logs -f maymessenger_backend"
    echo ""
    echo "# Логи базы данных:"
    echo "  docker compose logs -f db_maymessenger"
    echo ""
    echo "# Статус всех сервисов:"
    echo "  docker compose ps"
    echo ""
    echo "# Перезапуск May Messenger:"
    echo "  docker compose restart maymessenger_backend"
    echo ""
    
    if [ -f ".last_backup" ]; then
        LAST_BACKUP=$(cat .last_backup)
        echo -e "${YELLOW}🆘 Откат к предыдущей версии (если нужно):${NC}"
        echo ""
        echo "  docker compose stop maymessenger_backend db_maymessenger"
        echo "  cp $LAST_BACKUP/docker-compose.yml docker-compose.yml"
        echo "  cp $LAST_BACKUP/nginx_prod.conf nginx/nginx_prod.conf"
        echo "  docker compose restart proxy"
        echo ""
    fi
}

# Основной процесс
main() {
    print_header "🚀 Развертывание May Messenger на сервер с RareBooks"
    
    # Проверки
    check_server_environment
    check_maymessenger_structure
    
    # Создание backup
    create_backup
    
    # Валидация конфигурации
    validate_docker_compose
    
    # Развертывание
    deploy_maymessenger
    
    # Перезапуск Nginx
    restart_nginx
    
    # Проверка
    verify_deployment
    
    # Итоги
    print_summary
}

# Запуск скрипта
main

