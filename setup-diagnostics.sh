#!/bin/bash

# Bash скрипт для диагностики проблем с Initial Setup на Ubuntu сервере
# Использование: ./setup-diagnostics.sh

# Параметры
RESTART_SERVICES=false
FORCE_SETUP_MODE=false
BASE_URL="https://rare-books.ru"
VERBOSE=false

# Парсинг аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --restart-services)
            RESTART_SERVICES=true
            shift
            ;;
        --force-setup-mode)
            FORCE_SETUP_MODE=true
            shift
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            echo "Использование: $0 [опции]"
            echo "Опции:"
            echo "  --restart-services   Перезапустить Docker сервисы"
            echo "  --force-setup-mode   Принудительно включить режим setup"
            echo "  --base-url URL       Базовый URL (по умолчанию: https://rare-books.ru)"
            echo "  --verbose           Подробный вывод"
            echo "  -h, --help          Показать эту справку"
            exit 0
            ;;
        *)
            echo "Неизвестная опция: $1"
            exit 1
            ;;
    esac
done

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${GREEN}🔧 Диагностика системы инициализации RareBooksService${NC}"
    echo "============================================================"
}

print_section() {
    echo -e "\n${YELLOW}$1${NC}"
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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Функция для проверки HTTP endpoint
test_endpoint() {
    local url="$1"
    local method="${2:-GET}"
    local data="$3"
    
    if [[ $VERBOSE == true ]]; then
        echo "Тестирование: $method $url"
    fi
    
    if [[ -n "$data" ]]; then
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            --connect-timeout 30 \
            --max-time 60 \
            "$url" 2>/dev/null)
    else
        response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X "$method" \
            --connect-timeout 30 \
            --max-time 60 \
            "$url" 2>/dev/null)
    fi
    
    http_code=$(echo "$response" | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
    body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')
    
    echo "$http_code|$body"
}

# Начало диагностики
print_header

# 1. Проверка статуса Docker контейнеров
print_section "📦 Проверка статуса Docker контейнеров..."
if command -v docker &> /dev/null; then
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null; then
        print_success "Docker контейнеры найдены"
    else
        print_error "Ошибка при проверке Docker контейнеров"
    fi
else
    print_error "Docker не установлен или недоступен"
fi

# 2. Тест endpoint'а /api/test/setup-status
print_section "🔍 Тестирование Test API..."
test_result=$(test_endpoint "$BASE_URL/api/test/setup-status")
http_code=$(echo "$test_result" | cut -d'|' -f1)
body=$(echo "$test_result" | cut -d'|' -f2-)

if [[ "$http_code" == "200" ]]; then
    print_success "Test API работает"
    
    # Пытаемся парсить JSON
    if echo "$body" | jq . >/dev/null 2>&1; then
        timestamp=$(echo "$body" | jq -r '.timestamp // "N/A"')
        is_setup_needed=$(echo "$body" | jq -r '.isSetupNeeded // "N/A"')
        
        echo "   Время сервера: $timestamp"
        echo "   Требуется setup: $is_setup_needed"
        
        if [[ "$is_setup_needed" == "true" ]]; then
            print_warning "Система требует инициализации"
        else
            print_info "Система уже настроена"
        fi
    else
        echo "   Ответ не является валидным JSON"
    fi
else
    print_error "Test API недоступен (HTTP $http_code)"
    if [[ $VERBOSE == true ]]; then
        echo "   Ответ: ${body:0:200}..."
    fi
fi

# 3. Тест endpoint'а /api/setup (GET)
print_section "🔍 Тестирование Setup API (GET)..."
setup_get_result=$(test_endpoint "$BASE_URL/api/setup")
setup_get_code=$(echo "$setup_get_result" | cut -d'|' -f1)
setup_get_body=$(echo "$setup_get_result" | cut -d'|' -f2-)

if [[ "$setup_get_code" == "200" ]]; then
    print_success "Setup API (GET) работает"
    if [[ "$setup_get_body" == *"<html>"* ]]; then
        print_success "Возвращает HTML страницу инициализации"
    else
        print_info "Возвращает JSON ответ (система уже настроена)"
    fi
elif [[ "$setup_get_code" == "403" ]]; then
    print_info "Setup API возвращает 403 (система уже настроена)"
else
    print_error "Setup API (GET) недоступен (HTTP $setup_get_code)"
    if [[ $VERBOSE == true ]]; then
        echo "   Ответ: ${setup_get_body:0:200}..."
    fi
fi

# 4. Тест endpoint'а /api/setup/initialize (POST)
print_section "🔍 Тестирование Setup API (POST)..."
test_payload='{"adminEmail":"test@example.com","adminPassword":"testpass123","booksConnectionString":"test","usersConnectionString":"test","jwtKey":"test","jwtIssuer":"test","jwtAudience":"test"}'

setup_post_result=$(test_endpoint "$BASE_URL/api/setup/initialize" "POST" "$test_payload")
setup_post_code=$(echo "$setup_post_result" | cut -d'|' -f1)
setup_post_body=$(echo "$setup_post_result" | cut -d'|' -f2-)

if [[ "$setup_post_code" == "200" ]] || [[ "$setup_post_code" == "403" ]] || [[ "$setup_post_code" == "400" ]]; then
    print_success "Setup API (POST) отвечает"
    
    if echo "$setup_post_body" | jq . >/dev/null 2>&1; then
        message=$(echo "$setup_post_body" | jq -r '.message // "N/A"')
        echo "   Сообщение: $message"
    else
        echo "   Ответ: ${setup_post_body:0:100}..."
    fi
elif [[ "$setup_post_code" == "405" ]]; then
    print_error "Setup API (POST) недоступен - 405 Method Not Allowed"
    
    if [[ "$setup_post_body" == *"<html>"* ]]; then
        print_error "🚨 Получен HTML вместо JSON - nginx блокирует POST запросы!"
        print_warning "Возможные причины:"
        print_warning "- nginx конфигурация не обновлена"
        print_warning "- отсутствует proxy_method \$request_method"
        print_warning "- nginx не перезагружен после изменений"
    fi
else
    print_error "Setup API (POST) недоступен (HTTP $setup_post_code)"
    if [[ $VERBOSE == true ]]; then
        echo "   Ответ: ${setup_post_body:0:200}..."
    fi
fi

# 5. Проверка файлов конфигурации
print_section "📂 Проверка файлов конфигурации..."

config_files=("nginx/nginx_prod.conf" "docker-compose.yml" "RareBooksService.WebApi/appsettings.json")

for file in "${config_files[@]}"; do
    if [[ -f "$file" ]]; then
        print_success "$file - существует"
        
        # Специальная проверка для nginx_prod.conf
        if [[ "$file" == "nginx/nginx_prod.conf" ]]; then
            if grep -q "proxy_method \$request_method" "$file"; then
                print_success "   proxy_method найден в конфигурации"
            else
                print_error "   proxy_method отсутствует в конфигурации!"
                print_warning "   Это критическая проблема для POST запросов"
            fi
        fi
    else
        print_error "$file - отсутствует"
    fi
done

# 6. Проверка nginx процессов
print_section "🌐 Проверка nginx..."
if pgrep nginx >/dev/null; then
    print_success "nginx запущен"
    
    # Проверка конфигурации nginx
    if command -v nginx &> /dev/null; then
        if nginx -t 2>/dev/null; then
            print_success "Конфигурация nginx валидна"
        else
            print_error "Ошибка в конфигурации nginx"
            print_warning "Запустите: nginx -t для диагностики"
        fi
    fi
else
    print_error "nginx не запущен"
fi

# 7. Принудительные действия
if [[ "$FORCE_SETUP_MODE" == true ]]; then
    print_section "🔧 Принудительное включение режима setup..."
    appsettings_path="RareBooksService.WebApi/appsettings.json"
    if [[ -f "$appsettings_path" ]]; then
        cp "$appsettings_path" "${appsettings_path}.backup.$(date +%Y%m%d_%H%M%S)"
        rm "$appsettings_path"
        print_success "appsettings.json временно удален (создана резервная копия)"
    else
        print_info "appsettings.json уже отсутствует"
    fi
fi

if [[ "$RESTART_SERVICES" == true ]]; then
    print_section "🔄 Перезапуск сервисов..."
    
    if command -v docker-compose &> /dev/null; then
        print_info "Перезапуск nginx и backend..."
        if docker-compose restart nginx backend; then
            print_success "Сервисы перезапущены"
            
            print_info "Ожидание 10 секунд для стабилизации..."
            sleep 10
            
            # Повторный тест
            print_info "Повторная проверка..."
            retest_result=$(test_endpoint "$BASE_URL/api/test/setup-status")
            retest_code=$(echo "$retest_result" | cut -d'|' -f1)
            
            if [[ "$retest_code" == "200" ]]; then
                print_success "Сервисы восстановлены"
            else
                print_error "Проблема не решена (HTTP $retest_code)"
            fi
        else
            print_error "Ошибка при перезапуске сервисов"
        fi
    else
        print_error "docker-compose не найден"
    fi
fi

# 8. Рекомендации
print_section "🎯 Рекомендации по устранению проблем:"

if [[ "$http_code" == "200" ]] && [[ "$setup_get_code" == "200" ]] && [[ "$setup_post_code" == "405" ]]; then
    print_warning "1. Проблема с POST запросами к /api/setup/initialize"
    echo "   Решение: Обновите nginx конфигурацию и перезагрузите"
    echo "   Команды:"
    echo "     sudo docker-compose restart nginx"
    echo "     или"
    echo "     sudo nginx -s reload"
fi

if [[ "$http_code" != "200" ]]; then
    print_warning "1. Проблема с backend сервером"
    echo "   Решение: Перезапустите backend контейнер"
    echo "   Команда: sudo docker-compose restart backend"
fi

print_section "💡 Дополнительные команды для диагностики:"
echo "   $0 --restart-services           # Перезапустить сервисы"
echo "   $0 --force-setup-mode           # Принудительно включить режим setup"
echo "   $0 --verbose                    # Подробный вывод"
echo "   sudo docker-compose logs nginx  # Логи nginx"
echo "   sudo docker-compose logs backend # Логи backend"
echo "   sudo nginx -t                   # Проверка конфигурации nginx"
echo "   sudo nginx -s reload            # Перезагрузка nginx"

print_section "🏁 Диагностика завершена!"

# Итоговая оценка
if [[ "$setup_post_code" == "405" ]]; then
    echo ""
    print_error "🚨 КРИТИЧЕСКАЯ ПРОБЛЕМА: nginx блокирует POST запросы"
    print_warning "Необходимо обновить nginx конфигурацию и перезагрузить nginx"
    exit 1
elif [[ "$http_code" == "200" ]] && [[ "$setup_get_code" =~ ^(200|403)$ ]]; then
    echo ""
    print_success "✅ Система работает корректно"
    exit 0
else
    echo ""
    print_warning "⚠️  Обнаружены проблемы, требующие внимания"
    exit 2
fi
