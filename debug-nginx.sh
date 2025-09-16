#!/bin/bash

echo "🔍 Диагностика проблем с nginx контейнером"
echo "========================================"

echo ""
echo "📋 Статус nginx контейнера:"
sudo docker ps | grep nginx

echo ""
echo "🚨 Логи nginx (последние 50 строк):"
sudo docker-compose logs --tail=50 nginx

echo ""
echo "⚙️ Проверка конфигурации nginx внутри контейнера:"
sudo docker-compose exec nginx nginx -t

echo ""
echo "📂 Список конфигурационных файлов в контейнере:"
sudo docker-compose exec nginx ls -la /etc/nginx/

echo ""
echo "🔍 Проверка содержимого nginx.conf:"
sudo docker-compose exec nginx cat /etc/nginx/nginx.conf | head -20

echo ""
echo "🌐 Проверка портов и процессов nginx:"
sudo docker-compose exec nginx ps aux | grep nginx
sudo docker-compose exec nginx netstat -tlnp | grep nginx

echo ""
echo "📊 Проверка доступности backend изнутри nginx:"
sudo docker-compose exec nginx curl -I http://backend:80/api/test/setup-status || echo "Backend недоступен"

echo ""
echo "🔧 Проверка docker network:"
sudo docker network ls | grep rare
sudo docker network inspect $(sudo docker network ls | grep rare | awk '{print $1}') | grep -A5 -B5 "nginx\|backend"
