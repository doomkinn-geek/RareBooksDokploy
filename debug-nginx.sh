#!/bin/bash

echo "🔍 Диагностика проблем с nginx контейнером"
echo "========================================"

# Определяем формат Docker Compose
if docker compose version &> /dev/null; then
    DOCKER_CMD="docker compose"
    echo "ℹ️ Используем docker compose (новый формат)"
elif docker-compose --version &> /dev/null; then
    DOCKER_CMD="docker-compose"
    echo "ℹ️ Используем docker-compose (старый формат)"
else
    echo "❌ Docker Compose не найден!"
    exit 1
fi

echo ""
echo "📋 Статус nginx контейнера:"
sudo docker ps | grep nginx

echo ""
echo "🚨 Логи nginx (последние 50 строк):"
sudo $DOCKER_CMD logs --tail=50 nginx

echo ""
echo "⚙️ Проверка конфигурации nginx внутри контейнера:"
sudo $DOCKER_CMD exec nginx nginx -t

echo ""
echo "📂 Список конфигурационных файлов в контейнере:"
sudo $DOCKER_CMD exec nginx ls -la /etc/nginx/

echo ""
echo "🔍 Проверка содержимого nginx.conf:"
sudo $DOCKER_CMD exec nginx cat /etc/nginx/nginx.conf | head -20

echo ""
echo "🌐 Проверка портов и процессов nginx:"
sudo $DOCKER_CMD exec nginx ps aux | grep nginx
sudo $DOCKER_CMD exec nginx netstat -tlnp | grep nginx

echo ""
echo "📊 Проверка доступности backend изнутри nginx:"
sudo $DOCKER_CMD exec nginx curl -I http://backend:80/api/test/setup-status || echo "Backend недоступен"

echo ""
echo "🔧 Проверка docker network:"
sudo docker network ls | grep rare
sudo docker network inspect $(sudo docker network ls | grep rare | awk '{print $1}') | grep -A5 -B5 "nginx\|backend"
