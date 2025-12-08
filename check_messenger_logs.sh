#!/bin/bash

# =================================================================
# Скрипт для просмотра и анализа логов May Messenger
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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Проверка аргументов
if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
    print_header "📜 Просмотр логов May Messenger в реальном времени"
    print_info "Нажмите Ctrl+C для выхода"
    echo ""
    docker compose logs -f maymessenger_backend
    exit 0
fi

# Анализ логов
print_header "📜 Анализ логов May Messenger"

# Последние 50 строк
print_info "Последние 50 строк логов:"
echo "----------------------------------------"
docker compose logs maymessenger_backend --tail 50
echo "----------------------------------------"
echo ""

# Поиск ошибок
print_info "Поиск ошибок..."
errors=$(docker compose logs maymessenger_backend | grep -i "error" | wc -l)
if [ "$errors" -gt 0 ]; then
    print_error "Найдено ошибок: $errors"
    echo ""
    echo "Последние 10 ошибок:"
    docker compose logs maymessenger_backend | grep -i "error" | tail -10
else
    print_success "Ошибок не найдено"
fi
echo ""

# Поиск предупреждений
print_info "Поиск предупреждений..."
warnings=$(docker compose logs maymessenger_backend | grep -i "warning" | wc -l)
if [ "$warnings" -gt 0 ]; then
    echo "Найдено предупреждений: $warnings"
else
    print_success "Предупреждений не найдено"
fi
echo ""

# Проверка успешных запросов
print_info "Последние успешные HTTP запросы:"
docker compose logs maymessenger_backend | grep -E "HTTP.*200|StatusCode.*200" | tail -5
echo ""

# Проверка подключений к БД
print_info "Проверка подключений к базе данных..."
db_connections=$(docker compose logs maymessenger_backend | grep -i "database\|connection" | tail -5)
if [ ! -z "$db_connections" ]; then
    echo "$db_connections"
else
    print_info "Информация о подключениях не найдена в последних логах"
fi
echo ""

print_header "💡 Полезные команды"
echo "Просмотр логов в реальном времени:"
echo "  $0 -f"
echo ""
echo "Просмотр последних 100 строк:"
echo "  docker compose logs maymessenger_backend --tail 100"
echo ""
echo "Поиск конкретной ошибки:"
echo "  docker compose logs maymessenger_backend | grep 'текст ошибки'"
echo ""

