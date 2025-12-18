# Docker Troubleshooting Guide

## Проблема: maymessenger_backend не запускается

### Симптомы
```
Container maymessenger_backend is unhealthy
dependency failed to start: container maymessenger_backend is unhealthy
```

### Решения

#### 1. Проверить логи контейнера

```bash
# Посмотреть логи backend
docker-compose logs maymessenger_backend

# Посмотреть логи БД
docker-compose logs db_maymessenger

# Следить за логами в реальном времени
docker-compose logs -f maymessenger_backend
```

#### 2. Пересобрать и перезапустить контейнер

```bash
# Остановить все контейнеры
docker-compose down

# Пересобрать образ backend (с учётом изменений)
docker-compose build --no-cache maymessenger_backend

# Запустить заново
docker-compose up -d

# Проверить статус
docker-compose ps
```

#### 3. Проверить подключение к БД

```bash
# Зайти в контейнер БД
docker exec -it db_maymessenger psql -U postgres -d maymessenger

# Проверить таблицы
\dt

# Проверить миграции
SELECT * FROM "__EFMigrationsHistory" ORDER BY "MigrationId";

# Выйти
\q
```

#### 4. Ручное применение миграций (если автоматические не сработали)

```bash
# Зайти в контейнер backend (если он запущен, но с ошибками)
docker exec -it maymessenger_backend /bin/bash

# Применить миграции вручную
cd /app
dotnet MayMessenger.API.dll --migrate

# Или использовать EF tools (если установлены)
dotnet ef database update
```

#### 5. Проверить healthcheck

```bash
# Проверить простой healthcheck
curl http://localhost:5000/health/ready

# Проверить детальный healthcheck
curl http://localhost:5000/health | jq .

# Если curl не работает изнутри контейнера:
docker exec maymessenger_backend curl -fsS http://localhost:5000/health/ready
```

#### 6. Сбросить БД и начать заново (ОСТОРОЖНО - удалит все данные!)

```bash
# Остановить контейнеры
docker-compose down

# Удалить volume БД messenger
docker volume rm rarebooks_db_maymessenger_data

# Или удалить все volumes
docker-compose down -v

# Запустить заново (БД создастся с нуля)
docker-compose up -d
```

## Основные причины проблем

### 1. Ошибка миграции базы данных

**Проверка:**
```bash
docker-compose logs maymessenger_backend | grep -i "migration\|error\|exception"
```

**Решение:**
- Проверьте логи на наличие ошибок SQL
- Убедитесь что connection string правильный
- Проверьте что БД запущена и доступна

### 2. Неправильный connection string

**В docker-compose.yml:**
```yaml
- ConnectionStrings__DefaultConnection=Host=db_maymessenger;Port=5432;Database=maymessenger;Username=postgres;Password=postgres123
```

**Проверка:**
```bash
# Посмотреть переменные окружения контейнера
docker exec maymessenger_backend printenv | grep ConnectionStrings
```

### 3. БД не успела запуститься

**Решение:**
- Увеличен `start_period` в healthcheck до 60s
- БД проверяется через `depends_on` с `condition: service_healthy`

### 4. Порт занят

**Проверка:**
```bash
# Windows
netstat -ano | findstr :5000

# Linux
netstat -tulpn | grep :5000
```

**Решение:**
- Остановите процесс, занимающий порт
- Или измените порт в docker-compose.yml

### 5. Недостаточно ресурсов Docker

**Проверка:**
```bash
docker stats
```

**Решение:**
- Увеличьте лимиты в Docker Desktop (Settings → Resources)
- Минимум: 4GB RAM, 2 CPU cores

## Полезные команды

### Просмотр состояния

```bash
# Статус всех контейнеров
docker-compose ps

# Подробная информация о контейнере
docker inspect maymessenger_backend

# Процессы внутри контейнера
docker top maymessenger_backend

# Использование ресурсов
docker stats maymessenger_backend
```

### Очистка

```bash
# Удалить неиспользуемые образы
docker image prune -a

# Удалить неиспользуемые volumes
docker volume prune

# Полная очистка (ОСТОРОЖНО!)
docker system prune -a --volumes
```

### Отладка

```bash
# Зайти в контейнер
docker exec -it maymessenger_backend /bin/bash

# Или запустить отдельную команду
docker exec maymessenger_backend ls -la /app

# Копировать файлы из контейнера
docker cp maymessenger_backend:/app/appsettings.json ./temp_appsettings.json

# Посмотреть логи Docker daemon
# Windows: C:\ProgramData\docker\log
# Linux: journalctl -u docker
```

## Переменные окружения для отладки

Добавьте в docker-compose.yml для более детальных логов:

```yaml
environment:
  - ASPNETCORE_ENVIRONMENT=Development  # Больше логов
  - Logging__LogLevel__Default=Debug     # Debug уровень
  - Logging__LogLevel__Microsoft.EntityFrameworkCore=Information  # EF логи
```

## Проверка после запуска

После успешного запуска проверьте:

```bash
# 1. Healthcheck
curl http://localhost:5000/health/ready
# Должно вернуть: {"status":"Ready"}

# 2. Детальный health
curl http://localhost:5000/health | jq .
# Должно показать статус БД и Firebase

# 3. Swagger UI
# Откройте в браузере: http://localhost:5000/swagger

# 4. Проверить миграции в БД
docker exec -it db_maymessenger psql -U postgres -d maymessenger -c "SELECT \"MigrationId\" FROM \"__EFMigrationsHistory\";"
```

## Контакты для поддержки

Если проблема не решается:

1. Сохраните логи:
```bash
docker-compose logs > logs_$(date +%Y%m%d_%H%M%S).txt
```

2. Соберите информацию о системе:
```bash
docker version
docker-compose version
docker info
```

3. Опишите проблему с приложением логов и информации о системе.

## Быстрый чеклист

- [ ] БД запущена: `docker-compose ps db_maymessenger` → "healthy"
- [ ] Backend собран: `docker images | grep maymessenger_backend`
- [ ] Connection string правильный в environment variables
- [ ] Порт 5000 свободен
- [ ] Логи не содержат ошибок: `docker-compose logs maymessenger_backend`
- [ ] Healthcheck проходит: `curl http://localhost:5000/health/ready`
- [ ] Миграции применены: проверить в БД таблицу `__EFMigrationsHistory`

