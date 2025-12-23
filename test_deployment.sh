#!/bin/bash

# Скрипт для тестирования развертывания после docker compose up -d --build
# Проверяет все endpoints и сервисы

echo "=== Тестирование развертывания ==="
echo "Ожидание 60 секунд перед началом тестирования..."
sleep 60

# Функция для проверки HTTP статуса
check_http() {
    local url=$1
    local expected_code=${2:-200}
    local timeout=${3:-10}

    echo "Проверка $url..."
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $timeout "$url")

    if [ "$response" -eq "$expected_code" ]; then
        echo "✅ $url - OK ($response)"
        return 0
    else
        echo "❌ $url - FAILED ($response, ожидался $expected_code)"
        return 1
    fi
}

# Функция для проверки HTTPS статуса
check_https() {
    local url=$1
    local expected_code=${2:-200}
    local timeout=${3:-10}

    echo "Проверка $url..."
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $timeout -k "$url")

    if [ "$response" -eq "$expected_code" ]; then
        echo "✅ $url - OK ($response)"
        return 0
    else
        echo "❌ $url - FAILED ($response, ожидался $expected_code)"
        return 1
    fi
}

echo ""
echo "=== Проверка Docker контейнеров ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== Проверка healthcheck endpoints ==="

# Backend healthcheck
check_http "http://localhost:8080/health" 200 5

# Frontend healthcheck (nginx)
check_http "http://localhost:3000" 200 5

# May Messenger backend healthcheck
check_http "http://localhost:5000/health/ready" 200 5

# May Messenger web client healthcheck
check_http "http://localhost:3001/healthz" 200 5

echo ""
echo "=== Проверка основных endpoints через nginx ==="

# Nginx healthcheck
check_http "http://localhost/api/test/health" 200 5

# Setup API через nginx
check_http "http://localhost/api/test/setup-status" 200 10

# Rare Books API
check_http "http://localhost/api/BookUpdateService/status" 200 10

echo ""
echo "=== Проверка HTTPS endpoints ==="

# Main site HTTPS
check_https "https://localhost" 200 10

# Messenger HTTPS
check_https "https://localhost:8443" 200 10

echo ""
echo "=== Результаты тестирования ==="
echo "Если все проверки выше прошли успешно, развертывание работает корректно."
echo "Если есть ошибки, проверьте логи контейнеров: docker logs <container_name>"
