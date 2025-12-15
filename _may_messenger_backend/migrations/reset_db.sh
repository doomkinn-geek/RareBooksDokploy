#!/bin/bash
# Скрипт для полной пересборки базы данных

set -e

echo "⚠️  ВНИМАНИЕ: Это удалит ВСЕ данные из базы!"
echo "Продолжить? (введите 'yes' для подтверждения)"
read -r confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Отменено"
    exit 0
fi

echo "Остановка контейнеров..."
docker compose down

echo "Удаление volume с базой данных..."
docker volume rm rarebooks_postgres_data || echo "Volume не найден или уже удален"

echo "Запуск с новой базой данных..."
docker compose up -d

echo "Ожидание готовности..."
sleep 15

echo "Проверка статуса..."
docker compose logs maymessenger_backend --tail=20

echo ""
echo "✓ База данных пересоздана!"
echo "Все пользователи должны зарегистрироваться заново."
