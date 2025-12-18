# Full Stack Restart - May Messenger

## Быстрый перезапуск всего стека

```bash
# 1. Остановить все контейнеры
docker-compose down

# 2. Пересобрать оба мессенджер сервиса
docker-compose build maymessenger_backend maymessenger_web_client

# 3. Запустить весь стек
docker-compose up -d

# 4. Проверить статус
docker-compose ps
```

## Проверка после запуска

### Backend

```bash
# Healthcheck
curl http://localhost:5000/health/ready
# Ожидается: {"status":"Ready"}

# Детальный health (с БД и Firebase)
curl http://localhost:5000/health | jq .

# Swagger UI
# http://localhost:5000/swagger
```

### Web Client

```bash
# Healthcheck
curl http://localhost/healthz
# Ожидается: healthy

# Проверить что SPA загружается
curl -I http://localhost/web/
# Ожидается: 200 OK

# Открыть в браузере
# http://localhost/web/
```

### Database

```bash
# Проверить что БД запущена
docker-compose ps db_maymessenger
# Ожидается: healthy

# Проверить миграции
docker exec -it db_maymessenger psql -U postgres -d maymessenger -c \
  "SELECT \"MigrationId\" FROM \"__EFMigrationsHistory\" ORDER BY \"MigrationId\";"

# Должна быть миграция: 20241218120000_AddPerformanceIndexes
```

## Логи

### Все сервисы

```bash
docker-compose logs -f
```

### Конкретный сервис

```bash
# Backend
docker-compose logs -f maymessenger_backend

# Web Client
docker-compose logs -f maymessenger_web_client

# Database
docker-compose logs -f db_maymessenger
```

## Troubleshooting

### Backend не запускается

См. `DOCKER_TROUBLESHOOTING.md` и `QUICK_RESTART.md` в папке backend.

**Быстрая проверка:**
```bash
# Проверить БД
docker-compose ps db_maymessenger

# Проверить логи backend
docker-compose logs maymessenger_backend | grep -i error

# Пересобрать
docker-compose build --no-cache maymessenger_backend
docker-compose up -d maymessenger_backend
```

### Web Client не запускается

См. `QUICK_START.md` в папке web client.

**Быстрая проверка:**
```bash
# Проверить логи
docker-compose logs maymessenger_web_client

# Проверить nginx
docker exec maymessenger_web_client nginx -t

# Пересобрать
docker-compose build --no-cache maymessenger_web_client
docker-compose up -d maymessenger_web_client
```

### Все unhealthy

```bash
# Полный сброс (УДАЛИТ ДАННЫЕ!)
docker-compose down -v

# Пересобрать всё
docker-compose build --no-cache

# Запустить
docker-compose up -d

# Подождать 2 минуты для миграций и старта
sleep 120

# Проверить
docker-compose ps
```

## Performance Check

### Backend

```bash
# Тест нагрузки (requires ab - Apache Bench)
ab -n 1000 -c 10 http://localhost:5000/health/ready

# Проверить индексы
docker exec -it db_maymessenger psql -U postgres -d maymessenger -c \
  "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND indexname LIKE 'IX_%';"
```

### Web Client

```bash
# Bundle size check
cd _may_messenger_web_client
npm run build
# Проверить размеры в output

# Lighthouse
lighthouse http://localhost/web/ --view

# Cache headers
curl -I http://localhost/web/assets/index-*.js | grep Cache-Control
# Ожидается: Cache-Control: public, immutable, max-age=31536000
```

## Production Deployment

### Pre-deployment Checklist

- [ ] Все тесты пройдены
- [ ] Backend миграции протестированы
- [ ] Web client bundle оптимизирован
- [ ] Environment variables настроены
- [ ] SSL сертификаты актуальны
- [ ] Backup БД создан
- [ ] Monitoring настроен

### Deployment Steps

```bash
# 1. Pull latest code
git pull

# 2. Backup database
docker exec db_maymessenger pg_dump -U postgres maymessenger > backup_$(date +%Y%m%d).sql

# 3. Stop services
docker-compose down

# 4. Rebuild with latest changes
docker-compose build

# 5. Start services
docker-compose up -d

# 6. Check migrations applied
docker-compose logs maymessenger_backend | grep migration

# 7. Verify health
curl http://localhost:5000/health/ready
curl http://localhost/healthz

# 8. Monitor for 5 minutes
docker-compose logs -f
```

### Rollback Plan

Если что-то пошло не так:

```bash
# 1. Stop services
docker-compose down

# 2. Restore database backup
docker-compose up -d db_maymessenger
cat backup_YYYYMMDD.sql | docker exec -i db_maymessenger psql -U postgres -d maymessenger

# 3. Checkout previous version
git checkout <previous-commit>

# 4. Rebuild and start
docker-compose build
docker-compose up -d
```

## Monitoring

### Key Metrics to Watch

```bash
# Container health
watch -n 5 'docker-compose ps'

# Resource usage
docker stats

# Application logs
docker-compose logs -f | grep -i "error\|warn\|exception"

# Database connections
docker exec -it db_maymessenger psql -U postgres -d maymessenger -c \
  "SELECT count(*) FROM pg_stat_activity WHERE datname='maymessenger';"
```

### Alerts

Set up alerts for:
- Container unhealthy
- High memory usage (>80%)
- High CPU usage (>80%)
- Database connection errors
- Failed migrations

## Useful Commands

```bash
# See all running containers
docker ps

# Restart specific service
docker-compose restart maymessenger_backend

# View real-time resource usage
docker stats

# Clean up
docker system prune -a --volumes

# Export logs
docker-compose logs > logs_$(date +%Y%m%d_%H%M%S).txt

# Execute command in container
docker exec -it maymessenger_backend /bin/bash

# Copy files from container
docker cp maymessenger_backend:/app/logs ./local_logs
```

## Documentation Index

- **MESSENGER_OPTIMIZATION_COMPLETE.md** - Полный список всех оптимизаций
- **DOCKER_TROUBLESHOOTING.md** - Backend Docker troubleshooting
- **QUICK_RESTART.md** - Backend quick restart
- **WEB_CLIENT_IMPROVEMENTS.md** - Web client оптимизации
- **QUICK_START.md** - Web client quick start
- **AUTO_MIGRATIONS.md** - Информация об автомиграциях

## Support

При проблемах:
1. Проверьте логи: `docker-compose logs > debug.log`
2. Проверьте статус: `docker-compose ps`
3. Проверьте ресурсы: `docker stats`
4. Смотрите соответствующие troubleshooting guides
5. При необходимости сделайте полный сброс

