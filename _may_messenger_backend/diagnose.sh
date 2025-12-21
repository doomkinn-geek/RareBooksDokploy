#!/bin/bash

# Скрипт для диагностики проблемы с backend

echo "=== Диагностика May Messenger Backend ==="
echo ""

# 1. Проверка здоровья API
echo "1. Проверка health endpoint:"
curl -s https://messenger.rare-books.ru/health/ready
echo ""
echo ""

# 2. Проверка структуры таблицы Messages
echo "2. Проверка структуры таблицы Messages в БД:"
echo "Выполните на сервере:"
echo "psql -U postgres -d maymessenger -c \"\\d Messages\""
echo ""

# 3. Проверка логов приложения
echo "3. Проверка последних логов:"
echo "Выполните на сервере:"
echo "sudo journalctl -u maymessenger -n 50 --no-pager"
echo "или"
echo "pm2 logs maymessenger --lines 50"
echo ""

# 4. Проверка применённых миграций
echo "4. Проверка применённых миграций:"
echo "Выполните на сервере:"
echo "psql -U postgres -d maymessenger -c \"SELECT * FROM \\\"__EFMigrationsHistory\\\" ORDER BY \\\"MigrationId\\\" DESC LIMIT 5;\""
echo ""

# 5. Тестовый запрос к API
echo "5. Тестовый запрос к API чатов (требуется токен):"
echo "curl -H \"Authorization: Bearer YOUR_TOKEN\" https://messenger.rare-books.ru/api/chats"
echo ""

echo "=== Наиболее вероятная причина ==="
echo "Миграция 20251221000000_AddPlayedAtToMessages не применена на production."
echo ""
echo "Решение:"
echo "1. SSH на сервер"
echo "2. cd /path/to/backend/src/MayMessenger.API"
echo "3. dotnet ef database update --project ../MayMessenger.Infrastructure"
echo "4. Перезапустить приложение"

