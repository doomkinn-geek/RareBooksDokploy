# Быстрый перезапуск May Messenger Backend

## После изменений в коде

```bash
# 1. Остановить контейнеры
docker-compose down

# 2. Пересобрать backend (только если были изменения в коде)
docker-compose build maymessenger_backend

# 3. Запустить
docker-compose up -d

# 4. Проверить логи
docker-compose logs -f maymessenger_backend
```

## Проверка статуса

```bash
# Статус контейнеров
docker-compose ps

# Healthcheck
curl http://localhost:5000/health/ready

# Детальный health (с проверкой БД и Firebase)
curl http://localhost:5000/health | jq .
```

## Если контейнер не запускается

```bash
# Посмотреть логи с ошибками
docker-compose logs maymessenger_backend | grep -i error

# Пересобрать без кэша
docker-compose build --no-cache maymessenger_backend

# Перезапустить
docker-compose up -d
```

## Полный сброс (УДАЛИТ ВСЕ ДАННЫЕ!)

```bash
# Остановить и удалить volumes
docker-compose down -v

# Пересобрать
docker-compose build

# Запустить
docker-compose up -d
```

## Применение миграций

**Автоматически**: Миграции применяются автоматически при старте контейнера.

**Вручную** (если нужно):
```bash
# Зайти в контейнер
docker exec -it maymessenger_backend /bin/bash

# Проверить миграции в БД
cd /app
# (EF tools не установлены в runtime образе, используйте SQL)
```

**Через SQL**:
```bash
docker exec -it db_maymessenger psql -U postgres -d maymessenger -c "SELECT \"MigrationId\" FROM \"__EFMigrationsHistory\";"
```

## Мониторинг

```bash
# Следить за логами в реальном времени
docker-compose logs -f maymessenger_backend

# Проверить использование ресурсов
docker stats maymessenger_backend

# Проверить healthcheck
docker inspect maymessenger_backend | grep -A 10 "Health"
```

## Ожидаемый успешный запуск

Логи должны содержать:
```
info: Checking database connection...
info: Database connection successful
info: Database is up to date. No pending migrations.
info: Database initialization completed
info: Now listening on: http://[::]:5000
```

Healthcheck:
```bash
$ curl http://localhost:5000/health/ready
{"status":"Ready"}
```

## Если нужна помощь

Смотрите детальный гайд: `DOCKER_TROUBLESHOOTING.md`

