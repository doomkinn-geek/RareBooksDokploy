#!/bin/bash

# =================================================================
# Скрипт проверки работоспособности RareBooks и May Messenger
# =================================================================

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

# Проверка статуса контейнеров
check_containers() {
    print_header "Проверка статуса контейнеров Docker"
    
    echo "Все контейнеры:"
    docker compose ps
    echo ""
    
    # Проверка каждого контейнера
    containers=(
        "rarebooks_books_db"
        "rarebooks_users_db"
        "rarebooks_backend"
        "rarebooks_frontend"
        "db_maymessenger"
        "maymessenger_backend"
        "nginx_container"
    )
    
    all_running=true
    for container in "${containers[@]}"; do
        if docker compose ps | grep "$container" | grep -q "Up"; then
            print_success "$container работает"
        else
            print_error "$container не запущен!"
            all_running=false
        fi
    done
    
    if [ "$all_running" = true ]; then
        print_success "Все контейнеры запущены"
    else
        print_warning "Некоторые контейнеры не запущены"
    fi
    echo ""
}

# Проверка здоровья контейнеров
check_health() {
    print_header "Проверка здоровья контейнеров (healthcheck)"
    
    containers=(
        "rarebooks_books_db"
        "rarebooks_users_db"
        "rarebooks_backend"
        "rarebooks_frontend"
        "db_maymessenger"
        "maymessenger_backend"
        "nginx_container"
    )
    
    for container in "${containers[@]}"; do
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null)
        if [ -z "$health" ]; then
            print_info "$container: healthcheck не настроен"
        elif [ "$health" = "healthy" ]; then
            print_success "$container: healthy"
        else
            print_warning "$container: $health"
        fi
    done
    echo ""
}

# Проверка May Messenger API
check_maymessenger() {
    print_header "Проверка May Messenger API"
    
    # Health endpoint
    print_info "Проверка Health endpoint..."
    response=$(curl -k -s -o /dev/null -w "%{http_code}" https://messenger.rare-books.ru/health 2>&1)
    if [ "$response" = "200" ]; then
        print_success "Health endpoint: OK (HTTP $response)"
    else
        print_error "Health endpoint: FAILED (HTTP $response)"
    fi
    
    # Swagger UI
    print_info "Проверка Swagger UI..."
    response=$(curl -k -s -o /dev/null -w "%{http_code}" https://messenger.rare-books.ru/swagger 2>&1)
    if [ "$response" = "200" ]; then
        print_success "Swagger UI: OK (HTTP $response)"
    else
        print_error "Swagger UI: FAILED (HTTP $response)"
    fi
    
    # API endpoint (должен вернуть 401 без аутентификации - это нормально)
    print_info "Проверка API endpoint /api/chats..."
    response=$(curl -k -s -o /dev/null -w "%{http_code}" https://messenger.rare-books.ru/api/chats 2>&1)
    if [ "$response" = "401" ] || [ "$response" = "200" ]; then
        print_success "API endpoint: OK (HTTP $response - аутентификация работает)"
    else
        print_warning "API endpoint: HTTP $response"
    fi
    
    # Проверка внутри Docker сети
    print_info "Проверка доступности из Docker сети..."
    docker_response=$(docker exec nginx_container wget -qO- http://maymessenger_backend:5000/health 2>&1)
    if [ $? -eq 0 ]; then
        print_success "May Messenger доступен из Docker сети"
    else
        print_error "May Messenger недоступен из Docker сети"
        echo "$docker_response"
    fi
    echo ""
}

# Проверка RareBooks
check_rarebooks() {
    print_header "Проверка RareBooks Service"
    
    # Главная страница
    print_info "Проверка главной страницы..."
    response=$(curl -k -s -o /dev/null -w "%{http_code}" https://www.rare-books.ru/ 2>&1)
    if [ "$response" = "200" ]; then
        print_success "Главная страница: OK (HTTP $response)"
    else
        print_error "Главная страница: FAILED (HTTP $response)"
    fi
    
    # Setup API
    print_info "Проверка Setup API..."
    response=$(curl -k -s -o /dev/null -w "%{http_code}" https://www.rare-books.ru/api/test/setup-status 2>&1)
    if [ "$response" = "200" ]; then
        print_success "Setup API: OK (HTTP $response)"
    else
        print_warning "Setup API: HTTP $response"
    fi
    
    # Health endpoint (если есть)
    print_info "Проверка Health endpoint..."
    response=$(curl -k -s -o /dev/null -w "%{http_code}" https://www.rare-books.ru/health 2>&1)
    if [ "$response" = "200" ]; then
        print_success "Health endpoint: OK (HTTP $response)"
    else
        print_info "Health endpoint: HTTP $response (может быть не настроен)"
    fi
    
    # Проверка внутри Docker сети
    print_info "Проверка доступности из Docker сети..."
    docker_response=$(docker exec nginx_container wget -qO- http://backend:80/health 2>&1)
    if [ $? -eq 0 ]; then
        print_success "RareBooks backend доступен из Docker сети"
    else
        print_warning "RareBooks backend: проверьте логи"
    fi
    echo ""
}

# Проверка баз данных
check_databases() {
    print_header "Проверка баз данных"
    
    # RareBooks Books DB
    print_info "Проверка RareBooks_Books..."
    result=$(docker exec rarebooks_books_db psql -U postgres -d RareBooks_Books -c "SELECT COUNT(*) FROM \"Books\";" 2>&1 | grep -E "^\s*[0-9]+" | xargs)
    if [ ! -z "$result" ]; then
        print_success "RareBooks_Books: $result книг(и)"
    else
        print_warning "RareBooks_Books: проверьте подключение"
    fi
    
    # RareBooks Users DB
    print_info "Проверка RareBooks_Users..."
    result=$(docker exec rarebooks_users_db psql -U postgres -d RareBooks_Users -c "SELECT COUNT(*) FROM \"Users\";" 2>&1 | grep -E "^\s*[0-9]+" | xargs)
    if [ ! -z "$result" ]; then
        print_success "RareBooks_Users: $result пользователь(ей)"
    else
        print_warning "RareBooks_Users: проверьте подключение"
    fi
    
    # May Messenger DB
    print_info "Проверка May Messenger DB..."
    result=$(docker exec db_maymessenger psql -U postgres -d maymessenger -c "SELECT COUNT(*) FROM \"Users\";" 2>&1 | grep -E "^\s*[0-9]+" | xargs)
    if [ ! -z "$result" ]; then
        print_success "May Messenger DB: $result пользователь(ей)"
    else
        print_warning "May Messenger DB: проверьте подключение"
    fi
    echo ""
}

# Проверка сети
check_network() {
    print_header "Проверка сети Docker"
    
    print_info "Проверка сети rarebooks_network..."
    docker network inspect rarebooks_network > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "Сеть rarebooks_network существует"
        
        containers_count=$(docker network inspect rarebooks_network | grep -c "maymessenger")
        print_info "Контейнеров May Messenger в сети: $containers_count"
    else
        print_error "Сеть rarebooks_network не найдена!"
    fi
    echo ""
}

# Проверка портов
check_ports() {
    print_header "Проверка открытых портов"
    
    print_info "Проверка порта 80 (HTTP)..."
    if ss -tulpn | grep -q ":80"; then
        print_success "Порт 80 открыт"
    else
        print_error "Порт 80 не открыт!"
    fi
    
    print_info "Проверка порта 443 (HTTPS)..."
    if ss -tulpn | grep -q ":443"; then
        print_success "Порт 443 открыт"
    else
        print_error "Порт 443 не открыт!"
    fi
    echo ""
}

# Проверка логов на ошибки
check_logs() {
    print_header "Проверка последних логов на ошибки"
    
    print_info "May Messenger backend (последние 10 строк):"
    docker compose logs maymessenger_backend --tail 10
    echo ""
    
    errors=$(docker compose logs maymessenger_backend --tail 100 | grep -i "error" | wc -l)
    if [ "$errors" -gt 0 ]; then
        print_warning "Найдено ошибок в логах May Messenger: $errors"
    else
        print_success "Ошибок в логах May Messenger не найдено"
    fi
    echo ""
}

# Итоговая информация
print_summary() {
    print_header "📊 Полезные команды для мониторинга"
    
    echo "# Просмотр логов May Messenger в реальном времени:"
    echo "  docker compose logs -f maymessenger_backend"
    echo ""
    echo "# Просмотр логов RareBooks:"
    echo "  docker compose logs -f backend"
    echo "  docker compose logs -f frontend"
    echo ""
    echo "# Просмотр логов Nginx:"
    echo "  docker compose logs -f proxy"
    echo ""
    echo "# Перезапуск сервисов:"
    echo "  docker compose restart maymessenger_backend"
    echo "  docker compose restart proxy"
    echo ""
    echo "# Проверка использования ресурсов:"
    echo "  docker stats"
    echo ""
}

# Основной процесс
main() {
    print_header "🔍 Проверка работоспособности RareBooks и May Messenger"
    
    check_containers
    check_health
    check_network
    check_ports
    check_maymessenger
    check_rarebooks
    check_databases
    check_logs
    print_summary
    
    print_header "✅ Проверка завершена"
}

# Запуск скрипта
main

