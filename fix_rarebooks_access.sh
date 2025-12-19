#!/bin/bash

echo "=========================================="
echo "Диагностика и исправление доступа к RareBooks Setup API"
echo "=========================================="
echo ""

# 1. Проверяем, запущены ли контейнеры
echo "1. Проверяем статус контейнеров..."
BACKEND_STATUS=$(docker inspect -f '{{.State.Status}}' rarebooks_backend 2>/dev/null)
NGINX_STATUS=$(docker inspect -f '{{.State.Status}}' nginx_container 2>/dev/null)

if [ "$BACKEND_STATUS" != "running" ]; then
    echo "⚠️  Backend контейнер не запущен!"
    echo "Запускаем backend..."
    docker-compose up -d backend
    echo "Ждем 30 секунд для старта backend..."
    sleep 30
fi

if [ "$NGINX_STATUS" != "running" ]; then
    echo "⚠️  Nginx контейнер не запущен!"
    echo "Запускаем nginx..."
    docker-compose up -d proxy
    echo "Ждем 10 секунд для старта nginx..."
    sleep 10
fi

# 2. Проверяем healthcheck backend
echo ""
echo "2. Проверяем healthcheck backend..."
HEALTH_STATUS=$(docker inspect -f '{{.State.Health.Status}}' rarebooks_backend 2>/dev/null)
echo "Health status: $HEALTH_STATUS"

if [ "$HEALTH_STATUS" != "healthy" ]; then
    echo "⚠️  Backend не прошел healthcheck!"
    echo "Смотрим логи backend:"
    docker logs rarebooks_backend --tail 30
    
    echo ""
    echo "Пробуем перезапустить backend..."
    docker-compose restart backend
    echo "Ждем 30 секунд..."
    sleep 30
fi

# 3. Проверяем доступность API изнутри nginx контейнера
echo ""
echo "3. Проверяем доступность backend изнутри nginx..."
docker exec nginx_container wget -q -O - http://backend/api/test/setup-status 2>&1 | head -5

# 4. Проверяем nginx конфигурацию
echo ""
echo "4. Проверяем конфигурацию nginx..."
docker exec nginx_container nginx -t

# 5. Перезагружаем nginx
echo ""
echo "5. Перезагружаем nginx..."
docker exec nginx_container nginx -s reload

# 6. Проверяем доступность через HTTP
echo ""
echo "6. Проверяем доступность Setup API через HTTP..."
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://rare-books.ru/api/setup/ 2>&1)
echo "HTTP код ответа: $HTTP_RESPONSE"

if [ "$HTTP_RESPONSE" = "200" ] || [ "$HTTP_RESPONSE" = "302" ]; then
    echo "✅ Setup API доступен через HTTP"
    echo "   Откройте: http://rare-books.ru/api/setup/"
else
    echo "⚠️  Setup API НЕ доступен через HTTP"
    echo "   Проверьте логи nginx:"
    docker logs nginx_container --tail 20
fi

# 7. Проверяем доступность через HTTPS
echo ""
echo "7. Проверяем доступность Setup API через HTTPS..."
HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://rare-books.ru/api/setup/ 2>&1)
echo "HTTPS код ответа: $HTTPS_RESPONSE"

if [ "$HTTPS_RESPONSE" = "200" ] || [ "$HTTPS_RESPONSE" = "302" ]; then
    echo "✅ Setup API доступен через HTTPS"
    echo "   Откройте: https://rare-books.ru/api/setup/"
else
    echo "⚠️  Setup API НЕ доступен через HTTPS"
fi

echo ""
echo "=========================================="
echo "Итог диагностики"
echo "=========================================="
echo ""
echo "Статус сервисов:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "(rarebooks_backend|nginx_container|db_books|db_users)"

echo ""
echo "Для просмотра полных логов backend:"
echo "  docker logs rarebooks_backend"
echo ""
echo "Для просмотра полных логов nginx:"
echo "  docker logs nginx_container"
echo ""
echo "Для перезапуска всех сервисов RareBooks:"
echo "  docker-compose restart backend proxy"








