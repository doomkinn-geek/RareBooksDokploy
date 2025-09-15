#!/bin/bash

# ========================================
# Скрипт диагностики Telegram бота
# https://rare-books.ru
# ========================================

BASE_URL="${1:-https://rare-books.ru}"
CHAT_ID="${2:-}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 Диагностика Telegram бота для $BASE_URL${NC}"
echo -e "${GRAY}⏰ Время: $(date)${NC}"
echo ""

# Функция для красивого вывода JSON
show_json_result() {
    local result="$1"
    local title="$2"
    echo -e "${YELLOW}📊 $title${NC}"
    echo -e "${GRAY}─────────────────────────────────────────${NC}"
    if [ -n "$result" ]; then
        echo "$result" | jq . 2>/dev/null || echo "$result"
    else
        echo -e "${RED}❌ Нет данных${NC}"
    fi
    echo ""
}

# Функция для проверки HTTP статуса
test_http_endpoint() {
    local url="$1"
    local description="$2"
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200"; then
        echo -e "${GREEN}✅ $description - OK${NC}"
        return 0
    else
        echo -e "${RED}❌ $description - FAIL${NC}"
        return 1
    fi
}

echo -e "${MAGENTA}🌐 1. ПРОВЕРКА ДОСТУПНОСТИ СЕРВЕРА${NC}"
echo -e "${GRAY}════════════════════════════════════════${NC}"

# Основные эндпоинты
declare -A endpoints=(
    ["Главная страница"]="$BASE_URL"
    ["API статус"]="$BASE_URL/api/telegram/status"
    ["Диагностика бота"]="$BASE_URL/api/telegramdiagnostics/full-check"
)

for desc in "${!endpoints[@]}"; do
    test_http_endpoint "${endpoints[$desc]}" "$desc"
done

echo ""
echo -e "${MAGENTA}🔍 2. ПОЛНАЯ ДИАГНОСТИКА БОТА${NC}"
echo -e "${GRAY}════════════════════════════════════════${NC}"

diagnostics=$(curl -s "$BASE_URL/api/telegramdiagnostics/full-check")
if [ $? -eq 0 ] && [ -n "$diagnostics" ]; then
    show_json_result "$diagnostics" "Результат диагностики"
    
    # Анализ результатов
    echo -e "${CYAN}📋 АНАЛИЗ РЕЗУЛЬТАТОВ:${NC}"
    
    has_token=$(echo "$diagnostics" | jq -r '.checks.config.hasToken' 2>/dev/null)
    if [ "$has_token" = "true" ]; then
        echo -e "${GREEN}✅ Токен настроен${NC}"
    else
        echo -e "${RED}❌ Токен НЕ настроен!${NC}"
    fi
    
    api_status=$(echo "$diagnostics" | jq -r '.checks.telegram_api.status' 2>/dev/null)
    if [ "$api_status" = "success" ]; then
        echo -e "${GREEN}✅ Бот доступен в Telegram API${NC}"
        bot_name=$(echo "$diagnostics" | jq -r '.checks.telegram_api.botInfo.first_name' 2>/dev/null)
        bot_username=$(echo "$diagnostics" | jq -r '.checks.telegram_api.botInfo.username' 2>/dev/null)
        echo -e "${GRAY}   Имя бота: $bot_name${NC}"
        echo -e "${GRAY}   Username: @$bot_username${NC}"
    else
        echo -e "${RED}❌ Ошибка при обращении к Telegram API!${NC}"
        api_error=$(echo "$diagnostics" | jq -r '.checks.telegram_api.error' 2>/dev/null)
        if [ "$api_error" != "null" ] && [ -n "$api_error" ]; then
            echo -e "${RED}   Ошибка: $api_error${NC}"
        fi
    fi
    
    webhook_status=$(echo "$diagnostics" | jq -r '.checks.webhook.status' 2>/dev/null)
    if [ "$webhook_status" = "success" ]; then
        webhook_url=$(echo "$diagnostics" | jq -r '.checks.webhook.webhookInfo.url' 2>/dev/null)
        if [ "$webhook_url" != "null" ] && [ -n "$webhook_url" ]; then
            echo -e "${GREEN}✅ Webhook настроен: $webhook_url${NC}"
            pending_updates=$(echo "$diagnostics" | jq -r '.checks.webhook.webhookInfo.pending_update_count' 2>/dev/null)
            if [ "$pending_updates" != "null" ] && [ "$pending_updates" -gt 0 ]; then
                echo -e "${YELLOW}⚠️  Ожидает обновлений: $pending_updates${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Webhook НЕ настроен${NC}"
        fi
    else
        echo -e "${RED}❌ Ошибка при проверке webhook!${NC}"
    fi
    
else
    echo -e "${RED}❌ Ошибка при выполнении диагностики${NC}"
fi

echo ""
echo -e "${MAGENTA}🔧 3. ПРОВЕРКА СТАТУСА БОТА${NC}"
echo -e "${GRAY}════════════════════════════════════════${NC}"

status=$(curl -s "$BASE_URL/api/telegram/status")
if [ $? -eq 0 ] && [ -n "$status" ]; then
    show_json_result "$status" "Статус бота"
    
    is_valid=$(echo "$status" | jq -r '.isValid' 2>/dev/null)
    if [ "$is_valid" = "true" ]; then
        echo -e "${GREEN}✅ Бот корректно настроен${NC}"
    else
        echo -e "${RED}❌ Бот НЕ настроен или токен неверный!${NC}"
    fi
else
    echo -e "${RED}❌ Ошибка при проверке статуса${NC}"
fi

echo ""
echo -e "${MAGENTA}⚙️  4. УПРАВЛЕНИЕ WEBHOOK${NC}"
echo -e "${GRAY}════════════════════════════════════════${NC}"

echo -e "${GRAY}Команды для настройки webhook:${NC}"
echo -e "${GRAY}• Установить webhook:${NC}"
echo -e "  ${GRAY}curl -X POST '$BASE_URL/api/telegramdiagnostics/setup-webhook' \\${NC}"
echo -e "       ${GRAY}-H 'Content-Type: application/json' \\${NC}"
echo -e "       ${GRAY}-d '{\"baseUrl\":\"$BASE_URL\"}'${NC}"
echo ""
echo -e "${GRAY}• Удалить webhook:${NC}"
echo -e "  ${GRAY}curl -X POST '$BASE_URL/api/telegramdiagnostics/delete-webhook' \\${NC}"
echo -e "       ${GRAY}-H 'Content-Type: application/json' \\${NC}"
echo -e "       ${GRAY}-d '{}'${NC}"

if [ -n "$CHAT_ID" ]; then
    echo ""
    echo -e "${MAGENTA}💬 5. ТЕСТИРОВАНИЕ ОТПРАВКИ СООБЩЕНИЯ${NC}"
    echo -e "${GRAY}════════════════════════════════════════${NC}"
    
    test_message=$(cat <<EOF
{
    "chatId": "$CHAT_ID",
    "message": "🔧 Тестовое сообщение диагностики - $(date)"
}
EOF
)
    
    result=$(curl -s -X POST "$BASE_URL/api/telegramdiagnostics/test-send" \
        -H 'Content-Type: application/json' \
        -d "$test_message")
    
    if [ $? -eq 0 ] && [ -n "$result" ]; then
        success=$(echo "$result" | jq -r '.success' 2>/dev/null)
        if [ "$success" = "true" ]; then
            echo -e "${GREEN}✅ Сообщение отправлено успешно!${NC}"
        else
            echo -e "${RED}❌ Ошибка отправки сообщения!${NC}"
            show_json_result "$result" "Результат отправки"
        fi
    else
        echo -e "${RED}❌ Ошибка при тестировании отправки${NC}"
    fi
fi

echo ""
echo -e "${CYAN}📝 РЕКОМЕНДАЦИИ:${NC}"
echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"

echo -e "${YELLOW}1. Если токен не настроен:${NC}"
echo -e "${GRAY}   • Зайдите в админ-панель: $BASE_URL/admin${NC}"
echo -e "${GRAY}   • Установите токен в разделе 'Настройки'${NC}"
echo -e "${GRAY}   • Перезапустите сервер${NC}"

echo ""
echo -e "${YELLOW}2. Если бот не отвечает:${NC}"
echo -e "${GRAY}   • Проверьте настройку webhook${NC}"
echo -e "${GRAY}   • Убедитесь, что сервер доступен из интернета${NC}"
echo -e "${GRAY}   • Проверьте логи сервера на ошибки${NC}"

echo ""
echo -e "${YELLOW}3. Для получения Chat ID:${NC}"
echo -e "${GRAY}   • Отправьте сообщение боту @RareBooksReminderBot${NC}"
echo -e "${GRAY}   • Откройте: https://api.telegram.org/bot<TOKEN>/getUpdates${NC}"
echo -e "${GRAY}   • Найдите your_chat_id в ответе${NC}"

echo ""
echo -e "${GREEN}🎯 Диагностика завершена!${NC}"
echo -e "${GRAY}═══════════════════════════════════════════════════════════${NC}"
