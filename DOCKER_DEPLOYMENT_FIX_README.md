# Исправление проблемы 502 Bad Gateway после развертывания

## Проблема

После выполнения `docker compose up -d --build` сайт возвращал **502 Bad Gateway**, но после `docker compose restart` все начинало работать нормально.

## Причина проблемы

1. **Healthcheck nginx использовал сложный endpoint**: Nginx проверял `/api/test/setup-status`, который зависит от инициализации сервисов в backend
2. **Недостаточное время на инициализацию**: `start_period` для некоторых сервисов был слишком коротким, особенно для May Messenger backend с Firebase инициализацией
3. **Healthchecks проходили до полной готовности приложений**: Сервисы считались здоровыми, но еще не были готовы к обработке реальных запросов

## Внесенные изменения

### 1. Добавлен простой healthcheck endpoint в backend

**Файл**: `RareBooksService.WebApi/Controllers/TestController.cs`

```csharp
/// <summary>
/// Простой healthcheck endpoint для Docker healthcheck - не зависит от сложных сервисов
/// </summary>
[HttpGet("health")]
public IActionResult Health()
{
    return Ok(new
    {
        status = "healthy",
        timestamp = DateTime.UtcNow,
        service = "RareBooksService.WebApi"
    });
}
```

### 2. Изменен healthcheck nginx

**Файл**: `docker-compose.yml`

```yaml
healthcheck:
  # Проверяем простой healthcheck endpoint через HTTP (всегда доступен, не зависит от сложных сервисов)
  test: ["CMD-SHELL", "wget -q -O - http://localhost:80/api/test/health > /dev/null 2>&1 || exit 1"]
  interval: 30s
  timeout: 15s
  retries: 5
  start_period: 60s  # Увеличено с 30s
```

### 3. Увеличены start_period для всех сервисов

**RareBooksService Backend**:
- `start_period: 120s` → `180s`

**Frontend**:
- `start_period: 60s` → `90s`

**May Messenger Backend**:
- `start_period: 60s` → `120s`

**May Messenger Web Client**:
- `start_period: 5s` → `30s`

**Nginx**:
- `start_period: 30s` → `60s`

## Архитектура healthchecks

### Backend (RareBooksService)
- **Healthcheck**: `curl -fsS http://localhost:80/health`
- **Endpoint**: `/health` - возвращает JSON с базовой информацией
- **Зависимости**: Нет (простой endpoint)

### Frontend
- **Healthcheck**: `curl -fsS http://localhost:80`
- **Endpoint**: Nginx root - возвращает index.html
- **Зависимости**: Nginx готов к работе

### May Messenger Backend
- **Healthcheck**: `curl -fsS http://localhost:5000/health/ready`
- **Endpoint**: `/health/ready` - возвращает `{"status": "Ready"}`
- **Зависимости**: ASP.NET Core запущен
- **Примечание**: Firebase инициализируется ПОСЛЕ healthcheck

### May Messenger Web Client
- **Healthcheck**: `curl -fsS http://localhost/healthz`
- **Endpoint**: `/healthz` - возвращает "healthy"
- **Зависимости**: Nginx готов к работе

### Nginx (Reverse Proxy)
- **Healthcheck**: `wget -q -O - http://localhost:80/api/test/health`
- **Endpoint**: `/api/test/health` через backend
- **Зависимости**: Все upstream сервисы здоровы

## Порядок запуска

1. **Базы данных** запускаются первыми (depends_on не указан)
2. **Backend сервисы** ждут готовности БД (condition: service_healthy)
3. **Frontend сервисы** ждут готовности backend'ов (condition: service_healthy)
4. **Nginx** ждет готовности всех сервисов (condition: service_healthy)

## Тестирование

Используйте скрипт `test_deployment.sh` для проверки развертывания:

```bash
chmod +x test_deployment.sh
./test_deployment.sh
```

Скрипт проверит:
- Статус всех контейнеров
- Healthcheck endpoints всех сервисов
- Основные API endpoints через nginx
- HTTPS endpoints

## Мониторинг

### Проверка статуса сервисов

```bash
# Статус всех контейнеров
docker ps

# Healthcheck конкретного сервиса
docker exec rarebooks_backend curl -f http://localhost:80/health

# Логи сервиса
docker logs rarebooks_backend --tail 50
```

### Healthcheck endpoints

- **Backend**: `http://localhost:8080/health`
- **Frontend**: `http://localhost:3000/` (nginx)
- **May Messenger Backend**: `http://localhost:5000/health/ready`
- **May Messenger Web Client**: `http://localhost:3001/healthz`
- **Nginx**: `http://localhost/api/test/health`

## Важные замечания

1. **start_period** - время, в течение которого Docker игнорирует неудачные healthchecks
2. **interval** - частота проверок healthcheck
3. **timeout** - максимальное время ожидания ответа
4. **retries** - количество неудачных попыток перед пометкой как unhealthy

## Развертывание

```bash
# Полная пересборка и запуск
docker compose down
docker compose up -d --build

# Ожидание полной инициализации (2-3 минуты)
sleep 180

# Проверка работоспособности
./test_deployment.sh
```

## Диагностика проблем

Если проблема сохраняется:

1. **Проверьте логи**: `docker logs <container_name>`
2. **Проверьте healthcheck**: `docker ps` - колонка STATUS
3. **Проверьте endpoints вручную**: `curl http://localhost/api/test/health`
4. **Проверьте depends_on**: Убедитесь, что сервисы запускаются в правильном порядке

## Результат

После внесенных изменений `docker compose up -d --build` должен работать без необходимости в `docker compose restart`. Все сервисы будут корректно инициализированы и готовы к работе.
