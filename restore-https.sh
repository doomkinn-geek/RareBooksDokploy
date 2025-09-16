#!/bin/bash

echo "🔒 Восстановление HTTPS конфигурации nginx"
echo "========================================="

# Проверка бэкапа
if [ ! -f "docker-compose.yml.backup" ]; then
    echo "❌ Бэкап docker-compose.yml не найден!"
    echo "Восстанавливаем вручную..."
    
    sed -i.tmp 's|./nginx/nginx_prod_http.conf:/etc/nginx/nginx.conf|./nginx/nginx_prod.conf:/etc/nginx/nginx.conf|g' docker-compose.yml
    
    if grep -q "nginx_prod.conf" docker-compose.yml; then
        echo "✅ docker-compose.yml восстановлен вручную"
    else
        echo "❌ Не удалось восстановить docker-compose.yml"
        exit 1
    fi
else
    echo "📋 Восстановление из бэкапа..."
    cp docker-compose.yml.backup docker-compose.yml
    echo "✅ docker-compose.yml восстановлен из бэкапа"
fi

echo ""
echo "🔍 Проверка SSL сертификатов..."
if sudo ls /etc/letsencrypt/live/rare-books.ru/ 2>/dev/null | grep -q "fullchain.pem"; then
    echo "✅ SSL сертификаты найдены"
else
    echo "⚠️ SSL сертификаты не найдены в /etc/letsencrypt/live/rare-books.ru/"
    echo "Возможно, потребуется их обновление"
fi

echo ""
echo "🛑 Остановка nginx..."
sudo docker-compose stop nginx

echo ""
echo "🚀 Запуск nginx с HTTPS конфигурацией..."
sudo docker-compose up -d nginx

echo ""
echo "⏳ Ожидание запуска (15 секунд)..."
sleep 15

echo ""
echo "📊 Статус контейнеров:"
sudo docker-compose ps | grep nginx

echo ""
echo "🔍 Тестирование HTTPS endpoints..."

echo "Тест 1: HTTPS Test API"
https_test=$(curl -k -s -w "%{http_code}" -o /dev/null https://rare-books.ru/api/test/setup-status 2>/dev/null)
if [ "$https_test" = "200" ]; then
    echo "✅ HTTPS Test API работает (код: $https_test)"
else
    echo "❌ HTTPS Test API не работает (код: $https_test)"
fi

echo "Тест 2: HTTPS Setup API (POST)"
https_setup=$(curl -k -s -w "%{http_code}" -o /tmp/https_test.json \
    -X POST https://rare-books.ru/api/setup/initialize \
    -H "Content-Type: application/json" \
    -d '{"test":"data"}' 2>/dev/null)

echo "Код ответа: $https_setup"
if [ -f "/tmp/https_test.json" ]; then
    if grep -q "<html>" /tmp/https_test.json; then
        echo "❌ Получен HTML вместо JSON"
    elif grep -q '"' /tmp/https_test.json; then
        echo "✅ Получен JSON ответ"
    fi
    rm -f /tmp/https_test.json
fi

echo "Тест 3: HTTP -> HTTPS редирект"
redirect_test=$(curl -s -w "%{http_code}" -o /dev/null http://rare-books.ru/api/test/setup-status 2>/dev/null)
if [ "$redirect_test" = "301" ]; then
    echo "✅ HTTP правильно редиректит на HTTPS (код: $redirect_test)"
else
    echo "⚠️ HTTP редирект работает неожиданно (код: $redirect_test)"
fi

echo ""
echo "📋 Логи nginx (последние 10 строк):"
sudo docker-compose logs --tail=10 nginx

echo ""
if [ "$https_test" = "200" ] && [ "$https_setup" != "405" ]; then
    echo "✅ HTTPS конфигурация восстановлена и работает!"
    echo ""
    echo "🎯 Система готова к работе:"
    echo "   - Доступ через: https://rare-books.ru/"
    echo "   - Setup API: https://rare-books.ru/api/setup"
    echo ""
    echo "Можно удалить временные файлы:"
    echo "   rm docker-compose.yml.backup"
    echo "   rm nginx/nginx_prod_http.conf"
else
    echo "❌ HTTPS конфигурация работает с проблемами"
    echo ""
    echo "🔧 Для отладки запустите:"
    echo "   sudo docker-compose logs nginx"
    echo "   sudo nginx -t  # внутри контейнера"
    echo ""
    echo "Или вернитесь к HTTP версии:"
    echo "   ./quick-fix-http.sh"
fi
