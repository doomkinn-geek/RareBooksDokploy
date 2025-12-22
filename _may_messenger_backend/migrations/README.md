# May Messenger Refactoring Migrations

Этот каталог содержит скрипты миграции для комплексного рефакторинга May Messenger.

## Файлы

- `apply_refactoring_migrations.sh` - Основной скрипт применения миграций
- `rollback_refactoring.sh` - Скрипт отката миграций
- `add_fulltext_search_index.sql` - SQL скрипт для создания индексов и триггеров

## Применение миграций

### Подготовка

1. Убедитесь, что все Docker контейнеры запущены:
   ```bash
   docker ps | grep maymessenger
   ```

2. Проверьте подключение к базе данных:
   ```bash
   docker exec db_maymessenger psql -U postgres -d MayMessengerDb -c "SELECT COUNT(*) FROM \"Messages\";"
   ```

### Применение

```bash
cd /path/to/RareBooksServicePublic/_may_messenger_backend/migrations
chmod +x apply_refactoring_migrations.sh
./apply_refactoring_migrations.sh
```

Скрипт автоматически:
- Создаст резервную копию БД
- Применит EF Core миграции
- Применит кастомные SQL миграции
- Проверит корректность применения

### Откат (если что-то пошло не так)

```bash
chmod +x rollback_refactoring.sh
./rollback_refactoring.sh maymessenger_backup_YYYYMMDD_HHMMSS.sql
```

## Изменения в базе данных

### Новые таблицы

1. **MessageStatusEvents** - Event sourcing для статусов сообщений
   - `Id` (PK)
   - `MessageId` (FK)
   - `UserId` (FK)
   - `OldStatus`
   - `NewStatus`
   - `Timestamp`
   - `Reason`

### Новые индексы

1. **IX_Messages_ClientMessageId** - Уникальный индекс для идемпотентности
2. **IX_Messages_Content_FullText** - GIN индекс для полнотекстового поиска (русский язык)
3. **IX_Messages_UpdatedAt** - Индекс для incremental sync
4. **IX_Messages_ChatId_CreatedAt_Desc** - Композитный индекс для пагинации
5. **IX_MessageStatusEvents_MessageId_Timestamp** - Индекс для событий статусов
6. **IX_Users_IsOnline_LastHeartbeatAt** - Индекс для presence monitoring

### Новые поля

1. **Users.LastHeartbeatAt** - Timestamp последнего heartbeat для presence monitoring

### Триггеры

1. **update_messages_updated_at** - Автоматическое обновление `UpdatedAt` при изменении сообщения

## Проверка после миграции

### 1. Проверка структуры БД

```sql
-- Проверить таблицу MessageStatusEvents
SELECT * FROM "MessageStatusEvents" LIMIT 1;

-- Проверить уникальный индекс
\d "IX_Messages_ClientMessageId"

-- Проверить full-text search индекс
\d "IX_Messages_Content_FullText"

-- Проверить триггер
SELECT tgname FROM pg_trigger WHERE tgname = 'update_messages_updated_at';
```

### 2. Проверка функциональности

```bash
# Проверить логи backend
docker logs -f maymessenger_backend

# Проверить метрики
curl -H "Authorization: Bearer YOUR_TOKEN" http://messenger.rare-books.ru/api/diagnostics/metrics

# Проверить health
curl http://messenger.rare-books.ru/api/diagnostics/health
```

### 3. Тестирование

- Отправка сообщения (проверка идемпотентности)
- Обновление статусов (delivered, read)
- Поиск сообщений (full-text search)
- User presence (online/offline)
- Переподключение SignalR (incremental sync)

## Мониторинг после миграции

### Метрики для отслеживания

1. **Дубликаты сообщений**: должно быть 0%
   ```sql
   SELECT COUNT(*) FROM "Messages" 
   WHERE "ClientMessageId" IS NOT NULL 
   GROUP BY "ClientMessageId" 
   HAVING COUNT(*) > 1;
   ```

2. **Производительность поиска**:
   ```sql
   EXPLAIN ANALYZE 
   SELECT * FROM "Messages" 
   WHERE to_tsvector('russian', "Content") @@ plainto_tsquery('russian', 'тестовый запрос');
   ```

3. **Presence monitoring**:
   ```sql
   SELECT COUNT(*) FROM "Users" WHERE "IsOnline" = true;
   SELECT "LastHeartbeatAt" FROM "Users" WHERE "IsOnline" = true ORDER BY "LastHeartbeatAt" DESC LIMIT 10;
   ```

4. **Event sourcing**:
   ```sql
   SELECT COUNT(*) FROM "MessageStatusEvents";
   SELECT "NewStatus", COUNT(*) FROM "MessageStatusEvents" GROUP BY "NewStatus";
   ```

## Troubleshooting

### Проблема: Миграция EF Core не применяется

**Решение**:
```bash
docker exec maymessenger_backend dotnet ef migrations list
docker exec maymessenger_backend dotnet ef database update --force
```

### Проблема: Ошибка "duplicate key value violates unique constraint"

**Причина**: Есть дубликаты ClientMessageId в существующих данных

**Решение**:
```sql
-- Найти дубликаты
SELECT "ClientMessageId", COUNT(*) 
FROM "Messages" 
WHERE "ClientMessageId" IS NOT NULL 
GROUP BY "ClientMessageId" 
HAVING COUNT(*) > 1;

-- Удалить дубликаты (оставить только самое раннее сообщение)
DELETE FROM "Messages" a USING "Messages" b
WHERE a."Id" > b."Id" 
  AND a."ClientMessageId" = b."ClientMessageId" 
  AND a."ClientMessageId" IS NOT NULL;
```

### Проблема: Full-text search не работает

**Решение**:
```sql
-- Проверить наличие индекса
\d "IX_Messages_Content_FullText"

-- Пересоздать индекс
DROP INDEX IF EXISTS "IX_Messages_Content_FullText";
CREATE INDEX "IX_Messages_Content_FullText" 
ON "Messages" 
USING GIN (to_tsvector('russian', COALESCE("Content", '')));
```

## Откат отдельных изменений

### Откат full-text search индекса

```sql
DROP INDEX IF EXISTS "IX_Messages_Content_FullText";
```

### Откат триггера UpdatedAt

```sql
DROP TRIGGER IF EXISTS update_messages_updated_at ON "Messages";
DROP FUNCTION IF EXISTS update_updated_at_column();
```

### Откат таблицы MessageStatusEvents

```sql
-- ВНИМАНИЕ: Потеряются все данные о событиях статусов!
DROP TABLE IF EXISTS "MessageStatusEvents";
```

## Контакты

При возникновении проблем:
1. Проверьте логи: `docker logs maymessenger_backend`
2. Проверьте метрики: `/api/diagnostics/metrics`
3. Создайте issue в репозитории с описанием проблемы

