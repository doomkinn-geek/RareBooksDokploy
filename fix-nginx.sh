#!/bin/bash

echo "🔧 Принудительное исправление nginx конфигурации"
echo "=============================================="

# Определяем формат Docker Compose
if docker compose version &> /dev/null; then
    DOCKER_CMD="docker compose"
elif docker-compose --version &> /dev/null; then
    DOCKER_CMD="docker-compose"
else
    echo "❌ Docker Compose не найден!"
    exit 1
fi

# Остановка nginx
echo "🛑 Остановка nginx контейнера..."
sudo $DOCKER_CMD stop nginx

# Проверка, что конфигурация на месте
echo ""
echo "📂 Проверка конфигурационных файлов:"
if [ -f "nginx/nginx_prod.conf" ]; then
    echo "✅ nginx_prod.conf найден"
    
    # Проверяем наличие критических директив
    if grep -q "proxy_method" nginx/nginx_prod.conf; then
        echo "✅ proxy_method найден в конфигурации"
    else
        echo "❌ proxy_method отсутствует!"
        exit 1
    fi
    
    if grep -q "client_max_body_size" nginx/nginx_prod.conf; then
        echo "✅ client_max_body_size найден"
    else
        echo "⚠️ client_max_body_size не найден"
    fi
else
    echo "❌ nginx_prod.conf не найден!"
    exit 1
fi

# Проверка docker-compose.yml
echo ""
echo "📋 Проверка docker-compose конфигурации:"
if grep -q "nginx_prod.conf" docker-compose.yml; then
    echo "✅ nginx_prod.conf подключен в docker-compose.yml"
else
    echo "⚠️ Проверьте подключение nginx_prod.conf в docker-compose.yml"
fi

# Удаление контейнера для принудительного пересоздания
echo ""
echo "🗑️ Удаление nginx контейнера для пересоздания..."
sudo $DOCKER_CMD rm -f nginx

# Пересоздание и запуск
echo ""
echo "🚀 Пересоздание nginx контейнера..."
sudo $DOCKER_CMD up -d --force-recreate nginx

# Ожидание запуска
echo ""
echo "⏳ Ожидание запуска nginx (15 секунд)..."
sleep 15

# Проверка статуса
echo ""
echo "📊 Статус контейнеров после перезапуска:"
sudo $DOCKER_CMD ps | grep -E "(nginx|backend|frontend)"

# Проверка логов
echo ""
echo "📋 Логи nginx (последние 20 строк):"
sudo $DOCKER_CMD logs --tail=20 nginx

# Тестирование
echo ""
echo "🔍 Тестирование endpoints:"

echo "Тест 1: HTTP Test API"
curl -I http://localhost/api/test/setup-status 2>/dev/null | head -1 || echo "❌ HTTP тест неудачен"

echo "Тест 2: HTTPS Test API"  
curl -I https://rare-books.ru/api/test/setup-status 2>/dev/null | head -1 || echo "❌ HTTPS тест неудачен"

echo "Тест 3: HTTPS Setup API POST"
curl -X POST https://rare-books.ru/api/setup/initialize \
     -H "Content-Type: application/json" \
     -d '{"test":"data"}' \
     -w "HTTP Status: %{http_code}\n" \
     -o /tmp/setup_response.txt 2>/dev/null

echo "Ответ Setup API:"
head -5 /tmp/setup_response.txt

echo ""
echo "🎯 Если проблема не решена:"
echo "1. Запустите: ./debug-nginx.sh"
echo "2. Проверьте логи: sudo $DOCKER_CMD logs nginx"
echo "3. Проверьте backend: sudo $DOCKER_CMD logs backend"

rm -f /tmp/setup_response.txt
