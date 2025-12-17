#!/bin/bash

echo "=========================================="
echo "Проверка статуса Docker контейнеров"
echo "=========================================="
echo ""

# Проверяем статус всех контейнеров
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=========================================="
echo "Проверка healthcheck backend"
echo "=========================================="
docker inspect rarebooks_backend --format='{{.State.Health.Status}}'

echo ""
echo "=========================================="
echo "Логи rarebooks_backend (последние 50 строк)"
echo "=========================================="
docker logs rarebooks_backend --tail 50

echo ""
echo "=========================================="
echo "Проверка доступности Setup API изнутри nginx"
echo "=========================================="
docker exec nginx_container wget -q -O - http://backend/api/setup/ 2>&1 | head -20

echo ""
echo "=========================================="
echo "Проверка доступности Setup API с хоста"
echo "=========================================="
curl -I http://rare-books.ru/api/setup/ 2>&1

echo ""
echo "=========================================="
echo "Проверка доступности Setup API по HTTPS"
echo "=========================================="
curl -I https://rare-books.ru/api/setup/ 2>&1


