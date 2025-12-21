# Инструкции для исправления ошибки 500

## Проблема
После авторизации приложение получает ошибку 500 при запросе чатов. 
Это происходит потому что на production сервере не применена миграция для поля `PlayedAt`.

## Решение

### На сервере (SSH к messenger.rare-books.ru):

```bash
# 1. Перейти в директорию backend
cd /path/to/_may_messenger_backend/src/MayMessenger.API

# 2. Применить миграцию
dotnet ef database update --project ../MayMessenger.Infrastructure

# 3. Перезапустить приложение
sudo systemctl restart maymessenger
# или
pm2 restart maymessenger
```

### Альтернативно: Применить SQL миграцию напрямую

Если EF миграция не применяется, можно выполнить SQL напрямую:

```sql
-- Подключиться к PostgreSQL
psql -U postgres -d maymessenger

-- Выполнить миграцию
ALTER TABLE "Messages" ADD COLUMN IF NOT EXISTS "PlayedAt" timestamp without time zone NULL;

CREATE INDEX IF NOT EXISTS "IX_Messages_PlayedAt" 
ON "Messages" ("PlayedAt") 
WHERE "PlayedAt" IS NOT NULL;

-- Проверить результат
\d "Messages"
```

## Проверка

После применения миграции проверьте:
- https://messenger.rare-books.ru/health/ready должен отвечать {"status":"Ready"}
- Приложение должно успешно загружать чаты

## Дополнительные исправления (уже внесены в код):

✅ Название приложения изменено на "Депеша"
✅ Добавлены разрешения для камеры и галереи в AndroidManifest.xml
✅ Обновлен ImagePickerButtons для запроса всех необходимых разрешений

