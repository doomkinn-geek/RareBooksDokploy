#!/bin/bash

echo "=================================================================="
echo "=== Установка May Messenger на сервер с RareBooks ==="
echo "=================================================================="
echo ""

# Проверка что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Ошибка: файл docker-compose.yml не найден!"
    echo "Запустите скрипт из папки /root/RareBooksDokploy"
    exit 1
fi

# Проверка наличия необходимых файлов
echo "🔍 Проверка наличия файлов..."
MISSING_FILES=0

if [ ! -f "docker-compose-new.yml" ]; then
    echo "❌ Файл docker-compose-new.yml не найден!"
    MISSING_FILES=1
fi

if [ ! -f "nginx/nginx_prod_new.conf" ]; then
    echo "❌ Файл nginx/nginx_prod_new.conf не найден!"
    MISSING_FILES=1
fi

if [ ! -f "may_messenger_backend.zip" ]; then
    echo "❌ Файл may_messenger_backend.zip не найден!"
    MISSING_FILES=1
fi

if [ $MISSING_FILES -eq 1 ]; then
    echo ""
    echo "Загрузите файлы на сервер:"
    echo "  scp _rarebooks_config/docker-compose-with-maymessenger.yml root@217.198.5.89:/root/RareBooksDokploy/docker-compose-new.yml"
    echo "  scp _rarebooks_config/nginx_prod_with_maymessenger.conf root@217.198.5.89:/root/RareBooksDokploy/nginx/nginx_prod_new.conf"
    echo "  scp may_messenger_backend.zip root@217.198.5.89:/root/RareBooksDokploy/"
    exit 1
fi

echo "✅ Все файлы найдены"
echo ""

# Запрос подтверждения
read -p "Продолжить установку May Messenger? (yes/no): " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Установка отменена"
    exit 0
fi

echo ""
echo "=================================================================="
echo "ШАГ 1: Создание backup текущих конфигураций"
echo "=================================================================="

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)

cp docker-compose.yml docker-compose.yml.backup.$BACKUP_DATE
if [ $? -ne 0 ]; then
    echo "❌ Ошибка создания backup docker-compose.yml"
    exit 1
fi

cp nginx/nginx_prod.conf nginx/nginx_prod.conf.backup.$BACKUP_DATE
if [ $? -ne 0 ]; then
    echo "❌ Ошибка создания backup nginx_prod.conf"
    exit 1
fi

echo "✅ Backup создан:"
echo "   - docker-compose.yml.backup.$BACKUP_DATE"
echo "   - nginx/nginx_prod.conf.backup.$BACKUP_DATE"
echo ""

echo "=================================================================="
echo "ШАГ 2: Распаковка May Messenger backend"
echo "=================================================================="

if [ -d "MayMessenger/backend" ]; then
    echo "⚠️  Папка MayMessenger/backend уже существует. Удаляем..."
    rm -rf MayMessenger/backend
fi

if [ -d "backend" ]; then
    echo "⚠️  Папка backend уже существует. Удаляем..."
    rm -rf backend
fi

echo "📦 Распаковка may_messenger_backend.zip..."
unzip -q may_messenger_backend.zip

if [ $? -ne 0 ]; then
    echo "❌ Ошибка распаковки архива"
    exit 1
fi

echo "📁 Создание структуры директорий..."
mkdir -p MayMessenger

echo "📂 Перемещение backend в MayMessenger/..."
mv backend MayMessenger/

if [ ! -d "MayMessenger/backend" ]; then
    echo "❌ Ошибка: MayMessenger/backend не найдена после перемещения"
    exit 1
fi

echo "✅ Backend распакован в MayMessenger/backend/"
echo ""

echo "=================================================================="
echo "ШАГ 3: Проверка структуры файлов"
echo "=================================================================="

if [ ! -f "MayMessenger/backend/Dockerfile" ]; then
    echo "❌ Dockerfile не найден в MayMessenger/backend/"
    exit 1
fi

if [ ! -f "MayMessenger/backend/MayMessenger.sln" ]; then
    echo "❌ MayMessenger.sln не найден в MayMessenger/backend/"
    exit 1
fi

echo "✅ Структура файлов корректна"
echo ""

echo "=================================================================="
echo "ШАГ 4: Обновление конфигураций"
echo "=================================================================="

echo "📝 Замена docker-compose.yml..."
cp docker-compose-new.yml docker-compose.yml

if [ $? -ne 0 ]; then
    echo "❌ Ошибка замены docker-compose.yml"
    echo "Восстанавливаем backup..."
    cp docker-compose.yml.backup.$BACKUP_DATE docker-compose.yml
    exit 1
fi

echo "📝 Замена nginx/nginx_prod.conf..."
cp nginx/nginx_prod_new.conf nginx/nginx_prod.conf

if [ $? -ne 0 ]; then
    echo "❌ Ошибка замены nginx_prod.conf"
    echo "Восстанавливаем backup..."
    cp docker-compose.yml.backup.$BACKUP_DATE docker-compose.yml
    cp nginx/nginx_prod.conf.backup.$BACKUP_DATE nginx/nginx_prod.conf
    exit 1
fi

echo "✅ Конфигурации обновлены"
echo ""

echo "=================================================================="
echo "ШАГ 5: Проверка docker compose конфигурации"
echo "=================================================================="

docker compose config > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Ошибка в docker compose конфигурации!"
    echo "Восстанавливаем backup..."
    cp docker-compose.yml.backup.$BACKUP_DATE docker-compose.yml
    cp nginx/nginx_prod.conf.backup.$BACKUP_DATE nginx/nginx_prod.conf
    echo ""
    echo "Показываем ошибку конфигурации:"
    docker compose config
    exit 1
fi

echo "✅ Docker Compose конфигурация валидна"
echo ""

echo "=================================================================="
echo "ШАГ 6: Запуск May Messenger сервисов"
echo "=================================================================="

echo "🚀 Запуск контейнеров (это может занять несколько минут)..."
docker compose up -d --build maymessenger_backend db_maymessenger

if [ $? -ne 0 ]; then
    echo "❌ Ошибка запуска контейнеров!"
    exit 1
fi

echo "✅ Контейнеры запущены"
echo ""

echo "=================================================================="
echo "ШАГ 7: Ожидание запуска сервисов"
echo "=================================================================="

echo "⏳ Ожидание 90 секунд для инициализации базы данных и backend..."

for i in {90..1}; do
    printf "\r⏱️  Осталось: %2d секунд..." $i
    sleep 1
done
echo ""
echo "✅ Ожидание завершено"
echo ""

echo "=================================================================="
echo "ШАГ 8: Проверка статуса May Messenger сервисов"
echo "=================================================================="

docker compose ps | grep maymessenger
echo ""

echo "=================================================================="
echo "ШАГ 9: Перезапуск Nginx с новой конфигурацией"
echo "=================================================================="

docker compose restart proxy

if [ $? -ne 0 ]; then
    echo "❌ Ошибка перезапуска nginx"
    exit 1
fi

echo "✅ Nginx перезапущен"
echo ""

echo "=================================================================="
echo "ШАГ 10: Ожидание перезапуска Nginx"
echo "=================================================================="

echo "⏳ Ожидание 30 секунд..."

for i in {30..1}; do
    printf "\r⏱️  Осталось: %2d секунд..." $i
    sleep 1
done
echo ""
echo "✅ Ожидание завершено"
echo ""

echo "=================================================================="
echo "ШАГ 11: Финальная проверка"
echo "=================================================================="

echo ""
echo "=== Статус всех сервисов ==="
docker compose ps
echo ""

echo "=== Проверка May Messenger API ==="
curl -I -k https://messenger.rare-books.ru/api/chats 2>&1 | head -5
echo ""

echo "=== Проверка RareBooks ==="
curl -I -k https://rare-books.ru 2>&1 | head -5
echo ""

echo "=================================================================="
echo "=== ✅ РАЗВЕРТЫВАНИЕ ЗАВЕРШЕНО! ==="
echo "=================================================================="
echo ""
echo "🎉 May Messenger успешно установлен!"
echo ""
echo "📡 May Messenger API: https://messenger.rare-books.ru/api/"
echo "📚 Swagger UI:       https://messenger.rare-books.ru/swagger"
echo "🔌 SignalR Hub:      wss://messenger.rare-books.ru/hubs/chat"
echo ""
echo "✅ RareBooks работает как прежде: https://rare-books.ru"
echo ""
echo "=================================================================="
echo "🔐 Учетные данные May Messenger:"
echo "=================================================================="
echo "   👤 Администратор: +79604243127 / ppAKiH1Y"
echo "   🎫 Invite код:    WELCOME2024"
echo ""
echo "=================================================================="
echo "📊 Полезные команды:"
echo "=================================================================="
echo ""
echo "# Логи May Messenger:"
echo "  docker compose logs -f maymessenger_backend"
echo ""
echo "# Логи базы данных:"
echo "  docker compose logs -f db_maymessenger"
echo ""
echo "# Статус всех сервисов:"
echo "  docker compose ps"
echo ""
echo "# Перезапуск May Messenger:"
echo "  docker compose restart maymessenger_backend"
echo ""
echo "=================================================================="
echo "🆘 Откат к предыдущей версии (если нужно):"
echo "=================================================================="
echo ""
echo "  docker compose stop maymessenger_backend db_maymessenger"
echo "  cp docker-compose.yml.backup.$BACKUP_DATE docker-compose.yml"
echo "  cp nginx/nginx_prod.conf.backup.$BACKUP_DATE nginx/nginx_prod.conf"
echo "  docker compose restart proxy"
echo ""
echo "=================================================================="
echo "✅ Установка завершена успешно! 🚀"
echo "=================================================================="

