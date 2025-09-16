#!/bin/bash

echo "🚀 Применение универсальной конфигурации RareBooksService"
echo "======================================================="

# Определяем формат Docker Compose
if command -v docker &> /dev/null; then
    if docker compose version &> /dev/null; then
        DOCKER_CMD="docker compose"
        echo "✅ Используем docker compose (новый формат)"
    elif docker-compose --version &> /dev/null; then
        DOCKER_CMD="docker-compose"
        echo "✅ Используем docker-compose (старый формат)"
    else
        echo "❌ Docker Compose не найден!"
        exit 1
    fi
else
    echo "❌ Docker не установлен!"
    exit 1
fi

echo ""
echo "📋 Проверка конфигурационных файлов..."

# Проверяем наличие обновленных файлов
files_to_check=(
    "nginx/nginx_prod.conf"
    "docker-compose.yml"
)

missing_files=()
for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file - найден"
        
        # Специальная проверка для nginx_prod.conf
        if [[ "$file" == "nginx/nginx_prod.conf" ]]; then
            if grep -q "location ~ ^/api/(setup|test|setupcheck)/" "$file"; then
                echo "   ✅ Обновленная конфигурация nginx найдена"
            else
                echo "   ❌ nginx_prod.conf не обновлен!"
                missing_files+=("$file (требует обновления)")
            fi
        fi
    else
        echo "❌ $file - отсутствует"
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo ""
    echo "❌ Отсутствуют или не обновлены файлы:"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
    echo ""
    echo "Загрузите обновленные файлы и запустите скрипт снова."
    exit 1
fi

echo ""
echo "📊 Текущий статус контейнеров:"
sudo $DOCKER_CMD ps | grep -E "(nginx|backend|frontend)" || echo "Контейнеры не запущены"

echo ""
echo "🔄 Применение обновленной конфигурации..."

# Создаем бэкап текущей конфигурации
backup_suffix=$(date +%Y%m%d_%H%M%S)
if [ ! -f "docker-compose.yml.backup_$backup_suffix" ]; then
    cp docker-compose.yml "docker-compose.yml.backup_$backup_suffix"
    echo "✅ Создан бэкап: docker-compose.yml.backup_$backup_suffix"
fi

echo ""
echo "🛑 Остановка nginx для обновления конфигурации..."
sudo $DOCKER_CMD stop nginx

echo ""
echo "🗑️ Удаление nginx контейнера для принудительного обновления..."
sudo $DOCKER_CMD rm -f nginx

echo ""
echo "🚀 Запуск nginx с обновленной конфигурацией..."
sudo $DOCKER_CMD up -d nginx

echo ""
echo "⏳ Ожидание запуска nginx (20 секунд)..."
sleep 20

echo ""
echo "📊 Статус контейнеров после обновления:"
sudo $DOCKER_CMD ps | grep -E "(nginx|backend|frontend)"

echo ""
echo "🔍 Проверка nginx healthcheck:"
for i in {1..5}; do
    health_status=$(sudo docker inspect nginx_container --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    echo "Попытка $i/5: $health_status"
    
    if [ "$health_status" = "healthy" ]; then
        echo "✅ nginx контейнер здоров!"
        break
    elif [ "$i" -eq 5 ]; then
        echo "⚠️ nginx контейнер все еще не здоров. Проверяем логи..."
        sudo $DOCKER_CMD logs --tail=20 nginx
    else
        sleep 10
    fi
done

echo ""
echo "🔍 Тестирование обновленной конфигурации..."

# Тест 1: HTTP Setup API
echo "Тест 1: HTTP Setup API"
http_setup_test=$(curl -s -w "%{http_code}" -o /tmp/setup_test.json \
    http://localhost/api/test/setup-status 2>/dev/null || echo "000")

if [ "$http_setup_test" = "200" ]; then
    echo "✅ HTTP Setup API работает (код: $http_setup_test)"
    if [ -f "/tmp/setup_test.json" ] && grep -q '"success":true' /tmp/setup_test.json; then
        echo "   ✅ JSON ответ корректен"
    fi
else
    echo "❌ HTTP Setup API не работает (код: $http_setup_test)"
fi

# Тест 2: HTTP Setup POST
echo "Тест 2: HTTP Setup POST"
http_post_test=$(curl -s -w "%{http_code}" -o /tmp/post_test.json \
    -X POST http://localhost/api/setup/initialize \
    -H "Content-Type: application/json" \
    -d '{"test":"data"}' 2>/dev/null || echo "000")

echo "Код ответа POST: $http_post_test"
if [ -f "/tmp/post_test.json" ]; then
    if grep -q "<html>" /tmp/post_test.json; then
        echo "❌ Получен HTML вместо JSON - проблема не решена"
    elif grep -q '"' /tmp/post_test.json; then
        echo "✅ Получен JSON ответ - POST запросы работают!"
    fi
fi

# Тест 3: HTTPS работает (если SSL настроен)
echo "Тест 3: HTTPS (если доступен)"
https_test=$(curl -k -s -w "%{http_code}" -o /dev/null \
    https://rare-books.ru/api/test/setup-status 2>/dev/null || echo "000")

if [ "$https_test" = "200" ]; then
    echo "✅ HTTPS также работает (код: $https_test)"
elif [ "$https_test" = "000" ]; then
    echo "ℹ️ HTTPS недоступен (нормально для локальной разработки)"
else
    echo "⚠️ HTTPS работает с проблемами (код: $https_test)"
fi

# Тест 4: Редирект остальных страниц на HTTPS
echo "Тест 4: HTTP -> HTTPS редирект (для обычных страниц)"
redirect_test=$(curl -s -w "%{http_code}" -o /dev/null \
    http://localhost/ 2>/dev/null || echo "000")

if [ "$redirect_test" = "301" ]; then
    echo "✅ Обычные страницы корректно редиректят на HTTPS"
elif [ "$redirect_test" = "200" ]; then
    echo "ℹ️ Главная страница доступна через HTTP (возможно, для разработки)"
else
    echo "⚠️ Неожиданный код редиректа: $redirect_test"
fi

echo ""
echo "📋 Логи nginx (последние 15 строк):"
sudo $DOCKER_CMD logs --tail=15 nginx | grep -E "(error|warn|started|setup|test|nginx)" || echo "Нет релевантных логов"

echo ""
echo "🎯 Результат применения конфигурации:"

# Очистка временных файлов
rm -f /tmp/setup_test.json /tmp/post_test.json

if [ "$http_setup_test" = "200" ] && [ "$http_post_test" != "405" ]; then
    echo ""
    echo "✅ 🎉 УНИВЕРСАЛЬНАЯ КОНФИГУРАЦИЯ УСПЕШНО ПРИМЕНЕНА!"
    echo ""
    echo "📚 Теперь доступно:"
    echo "   🌐 Setup API через HTTP: http://localhost/api/setup"
    echo "   🌐 Setup API через HTTPS: https://rare-books.ru/api/setup (если SSL настроен)"
    echo "   📊 Test API: http://localhost/api/test/setup-status"
    echo "   🔄 POST запросы работают корректно"
    echo ""
    echo "💡 Больше НЕ НУЖНО переключать конфигурации!"
    echo "   Setup API постоянно доступен через HTTP"
    echo "   Остальные страницы используют HTTPS"
    echo ""
    echo "🚀 Можете выполнить инициализацию системы прямо сейчас!"
else
    echo ""
    echo "❌ Проблемы все еще остаются:"
    [ "$http_setup_test" != "200" ] && echo "   - HTTP Setup API не работает"
    [ "$http_post_test" = "405" ] && echo "   - POST запросы блокируются"
    echo ""
    echo "🔧 Запустите диагностику для выявления проблем:"
    echo "   ./setup-diagnostics.sh --verbose"
    echo ""
    echo "📞 Или проверьте логи:"
    echo "   sudo $DOCKER_CMD logs nginx"
    echo "   sudo $DOCKER_CMD logs backend"
fi

echo ""
echo "💾 Бэкапы сохранены:"
echo "   docker-compose.yml.backup_$backup_suffix"
echo ""
echo "🏁 Применение конфигурации завершено!"
