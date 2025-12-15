#!/bin/bash
# Быстрое развертывание миграции нормализации номеров

set -e

echo "Копирование SQL в контейнер..."
docker cp /tmp/update_phone_hashes.sql rarebooks-postgres-1:/tmp/

echo "Выполнение миграции..."
docker compose exec -T postgres psql -U postgres -d maymessenger -f /tmp/update_phone_hashes.sql

echo "Сборка backend..."
docker compose build maymessenger_backend

echo "Перезапуск backend..."
docker compose up -d maymessenger_backend

echo "Готово! Проверка через 10 секунд..."
sleep 10
curl -k https://messenger.rare-books.ru/health

echo ""
echo "✓ Миграция применена успешно!"
