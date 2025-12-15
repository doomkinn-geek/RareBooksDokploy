#!/bin/bash
# Быстрое развертывание улучшений May Messenger

set -e

echo "=== Развертывание улучшений May Messenger ==="

# 1. Остановка контейнеров
echo "Остановка контейнеров..."
docker compose down

# 2. Получение обновлений
echo "Получение обновлений из git..."
git pull origin master

# 3. Сборка и запуск
echo "Сборка и запуск контейнеров..."
docker compose up -d --build

# 4. Ожидание запуска
echo "Ожидание запуска backend..."
sleep 10

# 5. Проверка миграции
echo "Проверка применения миграции..."
docker compose logs messenger_backend | grep -i "migration\|deliveryreceipt" | tail -20

echo ""
echo "=== Развертывание завершено ==="
echo ""
echo "Проверка:"
echo "  Backend: https://messenger.rare-books.ru/api/health"
echo "  Логи:    docker compose logs -f messenger_backend"
echo ""
echo "APK для установки:"
echo "  _may_messenger_mobile_app/build/app/outputs/flutter-apk/app-release.apk"
