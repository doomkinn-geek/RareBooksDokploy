# Исправление путей аудио файлов

## Проблема
После рефакторинга путей аудио файлов с `/uploads/audio/` на `/audio/`, старые сообщения в базе данных содержат устаревшие пути, что приводит к ошибкам 404 при попытке воспроизведения.

**Ошибки в консоли:**
```
GET https://messenger.rare-books.ru/uploads/audio/e6fbc12b-d3fe-4b53-bc79-33911e6fc814.m4a 404 (Not Found)
```

## Решение

### 1. Nginx Redirect (временное решение)
Добавлен редирект для поддержки старых URL:

```nginx
# Redirect old audio paths to new location
location /uploads/audio/ {
    rewrite ^/uploads/audio/(.*)$ /audio/$1 permanent;
}
```

**Файл:** `nginx/nginx_prod.conf`

### 2. База данных Migration (постоянное решение)
Обновление путей в базе данных:

#### Автоматическая миграция
```bash
cd /root/rarebooks/_may_messenger_backend
chmod +x migrate_audio_paths.sh
./migrate_audio_paths.sh
```

#### Ручная миграция
```bash
docker exec -it postgres_maymessenger psql -U maymessenger_user -d maymessenger_db

# В psql:
UPDATE "Messages"
SET "FilePath" = REPLACE("FilePath", '/uploads/audio/', '/audio/')
WHERE "FilePath" LIKE '/uploads/audio/%';

# Проверка
SELECT "Id", "FilePath" FROM "Messages" WHERE "Type" = 1 ORDER BY "CreatedAt" DESC LIMIT 10;
```

## Деплой

```bash
cd /root/rarebooks

# 1. Получить изменения
git pull origin master

# 2. Применить миграцию путей в БД
cd _may_messenger_backend
chmod +x migrate_audio_paths.sh
./migrate_audio_paths.sh

# 3. Перезагрузить nginx
cd ..
docker compose restart proxy

# 4. Проверить
curl -I https://messenger.rare-books.ru/audio/test.m4a
curl -I https://messenger.rare-books.ru/uploads/audio/test.m4a  # должен редиректить на /audio/
```

## Проверка

1. **Старые сообщения**: Откройте чат со старыми аудио сообщениями → должны воспроизводиться
2. **Новые сообщения**: Отправьте новое аудио → должно воспроизводиться
3. **Redirect**: Проверьте, что `/uploads/audio/xxx` редиректит на `/audio/xxx`

## Файлы

- `nginx/nginx_prod.conf` - добавлен redirect
- `_may_messenger_backend/migrate_audio_paths.sql` - SQL скрипт миграции
- `_may_messenger_backend/migrate_audio_paths.sh` - Bash скрипт для автоматизации

## Примечания

- **Nginx redirect** - обеспечивает обратную совместимость, если миграция БД не выполнена
- **Database migration** - постоянное решение, обновляет все записи в БД
- Физические файлы остаются в `wwwroot/audio/` (Docker volume `maymessenger_audio`)

