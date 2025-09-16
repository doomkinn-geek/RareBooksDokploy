#!/bin/bash

echo "🚀 Быстрое исправление nginx для поддержки HTTP setup API"
echo "======================================================"

# Проверка файлов
if [ ! -f "nginx/nginx_prod_http.conf" ]; then
    echo "❌ nginx_prod_http.conf не найден!"
    exit 1
fi

if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml не найден!"
    exit 1
fi

echo "📋 Текущий статус контейнеров:"
sudo docker-compose ps | grep -E "(nginx|backend|frontend)" || echo "Контейнеры не запущены"

echo ""
echo "🔄 Переключение на HTTP-версию nginx конфигурации..."

# Бэкап текущей конфигурации
if [ -f "docker-compose.yml.backup" ]; then
    echo "ℹ️ Бэкап docker-compose.yml уже существует"
else
    cp docker-compose.yml docker-compose.yml.backup
    echo "✅ Создан бэкап docker-compose.yml"
fi

# Обновление docker-compose.yml для использования HTTP версии
sed -i.tmp 's|./nginx/nginx_prod.conf:/etc/nginx/nginx.conf|./nginx/nginx_prod_http.conf:/etc/nginx/nginx.conf|g' docker-compose.yml

if grep -q "nginx_prod_http.conf" docker-compose.yml; then
    echo "✅ docker-compose.yml обновлен для использования HTTP версии"
else
    echo "❌ Не удалось обновить docker-compose.yml"
    exit 1
fi

echo ""
echo "🛑 Остановка и пересоздание nginx..."
sudo docker-compose stop nginx
sudo docker-compose rm -f nginx

echo ""
echo "🚀 Запуск nginx с новой конфигурацией..."
sudo docker-compose up -d nginx

echo ""
echo "⏳ Ожидание запуска (10 секунд)..."
sleep 10

echo ""
echo "📊 Статус контейнеров:"
sudo docker-compose ps | grep -E "(nginx|backend|frontend)"

echo ""
echo "🔍 Тестирование HTTP endpoints..."

echo "Тест 1: HTTP Test API"
http_test=$(curl -s -w "%{http_code}" -o /dev/null http://localhost/api/test/setup-status 2>/dev/null)
if [ "$http_test" = "200" ]; then
    echo "✅ HTTP Test API работает (код: $http_test)"
else
    echo "❌ HTTP Test API не работает (код: $http_test)"
fi

echo "Тест 2: HTTP Setup API (GET)"
setup_get=$(curl -s -w "%{http_code}" -o /dev/null http://localhost/api/setup 2>/dev/null)
if [ "$setup_get" = "200" ]; then
    echo "✅ HTTP Setup API GET работает (код: $setup_get)"
else
    echo "⚠️ HTTP Setup API GET (код: $setup_get)"
fi

echo "Тест 3: HTTP Setup API (POST)"
setup_post=$(curl -s -w "%{http_code}" -o /tmp/setup_test.json \
    -X POST http://localhost/api/setup/initialize \
    -H "Content-Type: application/json" \
    -d '{"test":"data"}' 2>/dev/null)

echo "Код ответа: $setup_post"
if [ -f "/tmp/setup_test.json" ]; then
    echo "Содержимое ответа:"
    head -3 /tmp/setup_test.json
    
    if grep -q "<html>" /tmp/setup_test.json; then
        echo "❌ Получен HTML вместо JSON - проблема не решена"
    elif grep -q '"' /tmp/setup_test.json; then
        echo "✅ Получен JSON ответ - проблема решена!"
    fi
    rm -f /tmp/setup_test.json
fi

echo ""
echo "📋 Проверка логов nginx:"
sudo docker-compose logs --tail=10 nginx | grep -E "(error|warn|started|setup|test)" || echo "Нет релевантных логов"

echo ""
echo "🎯 Следующие шаги:"
echo ""

if [ "$http_test" = "200" ] && [ "$setup_post" != "405" ]; then
    echo "✅ HTTP версия работает! Теперь можно:"
    echo "1. Открыть http://localhost/api/setup для инициализации"
    echo "2. После настройки вернуться к HTTPS версии:"
    echo "   ./restore-https.sh"
else
    echo "❌ Проблема не решена. Запустите дополнительную диагностику:"
    echo "   ./debug-nginx.sh"
    echo ""
    echo "Или откатитесь к исходной конфигурации:"
    echo "   cp docker-compose.yml.backup docker-compose.yml"
    echo "   sudo docker-compose restart nginx"
fi

echo ""
echo "💡 Полезные команды:"
echo "   sudo docker-compose logs nginx     # Логи nginx"
echo "   sudo docker-compose logs backend   # Логи backend"
echo "   ./setup-diagnostics.sh            # Полная диагностика"
