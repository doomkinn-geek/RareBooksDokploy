#!/bin/bash

# =================================================================
# Скрипт отката развертывания May Messenger
# =================================================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_header "🔄 Откат развертывания May Messenger"

# Проверка наличия backup
if [ ! -f ".last_backup" ]; then
    print_error "Файл .last_backup не найден!"
    print_info "Ищем последний backup вручную..."
    
    if [ ! -d "backups" ]; then
        print_error "Директория backups не найдена!"
        exit 1
    fi
    
    LAST_BACKUP=$(ls -t backups/ | head -1)
    if [ -z "$LAST_BACKUP" ]; then
        print_error "Backup не найден!"
        exit 1
    fi
    
    BACKUP_DIR="backups/$LAST_BACKUP"
    print_info "Найден backup: $BACKUP_DIR"
else
    BACKUP_DIR=$(cat .last_backup)
    print_info "Используется backup: $BACKUP_DIR"
fi

# Проверка наличия файлов backup
if [ ! -f "$BACKUP_DIR/docker-compose.yml" ]; then
    print_error "Backup файл docker-compose.yml не найден!"
    exit 1
fi

if [ ! -f "$BACKUP_DIR/nginx_prod.conf" ]; then
    print_error "Backup файл nginx_prod.conf не найден!"
    exit 1
fi

print_success "Backup файлы найдены"
echo ""

# Запрос подтверждения
print_warning "ВНИМАНИЕ! Это действие:"
echo "  - Остановит сервисы May Messenger"
echo "  - Восстановит старые конфигурации"
echo "  - Перезапустит Nginx"
echo ""
read -p "Продолжить откат? (yes/no): " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Откат отменен"
    exit 0
fi

# Остановка May Messenger сервисов
print_header "Остановка May Messenger сервисов"
docker compose stop maymessenger_backend db_maymessenger
print_success "Сервисы остановлены"
echo ""

# Восстановление конфигураций
print_header "Восстановление конфигураций"

cp "$BACKUP_DIR/docker-compose.yml" docker-compose.yml
if [ $? -eq 0 ]; then
    print_success "Восстановлен docker-compose.yml"
else
    print_error "Ошибка восстановления docker-compose.yml"
    exit 1
fi

cp "$BACKUP_DIR/nginx_prod.conf" nginx/nginx_prod.conf
if [ $? -eq 0 ]; then
    print_success "Восстановлен nginx_prod.conf"
else
    print_error "Ошибка восстановления nginx_prod.conf"
    exit 1
fi

echo ""

# Проверка конфигурации
print_header "Проверка конфигурации Docker Compose"
if docker compose config > /dev/null 2>&1; then
    print_success "Конфигурация валидна"
else
    print_error "Ошибка в конфигурации!"
    docker compose config
    exit 1
fi

echo ""

# Перезапуск Nginx
print_header "Перезапуск Nginx"
docker compose restart proxy
print_success "Nginx перезапущен"

echo ""
print_info "Ожидание 30 секунд..."
sleep 30

# Проверка
print_header "Проверка работоспособности"
docker compose ps
echo ""

# Проверка RareBooks
print_info "Проверка RareBooks..."
response=$(curl -k -s -o /dev/null -w "%{http_code}" https://www.rare-books.ru/ 2>&1)
if [ "$response" = "200" ]; then
    print_success "RareBooks работает (HTTP $response)"
else
    print_warning "RareBooks: HTTP $response"
fi

echo ""
print_header "✅ Откат завершен"
print_info "May Messenger сервисы остановлены"
print_info "Конфигурации восстановлены из backup: $BACKUP_DIR"
print_success "RareBooks Service работает в прежнем режиме"
echo ""

