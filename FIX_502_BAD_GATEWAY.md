# Исправление ошибки 502 Bad Gateway при первом запуске Docker

## Проблема

После выполнения `docker compose up -d --build` все контейнеры запускались, но при обращении к сайту появлялась ошибка:
```
502 Bad Gateway
nginx/1.28.0
```

Проблема исчезала только после выполнения `docker compose restart`.

## Причина

Проблема возникала из-за нескольких факторов:

1. **Timing проблема**: nginx стартовал раньше, чем backend-сервисы были полностью готовы принимать запросы
2. **DNS кэширование**: nginx кэшировал неудачные попытки резолвинга имен контейнеров
3. **Недостаточные healthcheck'и**: `start_period` был слишком коротким для некоторых сервисов
4. **Отсутствие retry логики**: nginx не пытался повторно подключиться при временных ошибках

## Внесённые изменения

### 1. docker-compose.yml

#### Увеличены и оптимизированы healthcheck параметры:

**backend** (RareBooksService):
- `start_period`: 120s → **180s** (3 минуты для полной инициализации)
- `interval`: 30s → **10s** (более частые проверки)
- `retries`: 10 → **15** (больше попыток)
- `timeout`: 10s → **5s**

**frontend** (RareBooksService):
- `start_period`: 60s → **90s**
- `interval`: 30s → **10s**
- `timeout`: 10s → **5s**

**maymessenger_backend**:
- `start_period`: 60s → **120s** (2 минуты)
- `interval`: 15s → **10s**
- `retries`: 5 → **10**

**maymessenger_web_client**:
- `start_period`: 5s → **30s**
- `interval`: 15s → **10s**
- `retries`: 3 → **5**

**proxy** (nginx):
- `start_period`: 30s → **60s**
- Изменён healthcheck на более простую проверку работоспособности nginx

#### Добавлены параметры устойчивости к ошибкам в upstream блоках:
- `max_fails=3` - количество неудачных попыток перед пометкой сервера как недоступного
- `fail_timeout=30s` - время, на которое сервер помечается как недоступный

### 2. nginx/nginx_prod.conf

#### Улучшен DNS resolver:
```nginx
resolver 127.0.0.11 valid=10s ipv6=off;  # Было: valid=30s
resolver_timeout 5s;                      # Было: 10s
```
- Уменьшено время кэширования DNS для более частого обновления адресов

#### Добавлены глобальные retry настройки:
```nginx
proxy_next_upstream error timeout http_502 http_503 http_504;
proxy_next_upstream_tries 3;
proxy_next_upstream_timeout 10s;
```

#### Оптимизированы upstream блоки:
```nginx
upstream backend {
    server rarebooks_backend:80 max_fails=3 fail_timeout=30s;
    keepalive 32;
}
```

#### Добавлена retry логика для всех location блоков:
- **Setup API**: 5 попыток, 15 секунд таймаут
- **Общий API**: 3 попытки, 10 секунд таймаут
- **Frontend**: 3 попытки, 10 секунд таймаут
- **Messenger API**: 3 попытки, 15 секунд таймаут
- **Messenger Web**: 3 попытки, 10 секунд таймаут

#### Исправлены Connection headers:
- Изменено `Connection keep-alive` → `Connection ""` для использования keepalive из upstream

## Как это работает

### Последовательность запуска:

1. **База данных** (db_books, db_users, db_maymessenger) - стартуют первыми
   - Healthcheck: проверка готовности PostgreSQL
   
2. **Backend сервисы** (backend, maymessenger_backend)
   - Ждут готовности баз данных (`condition: service_healthy`)
   - Имеют увеличенный `start_period` для инициализации (2-3 минуты)
   - Проверяются каждые 10 секунд
   
3. **Frontend сервисы** (frontend, maymessenger_web_client)
   - Ждут готовности backend сервисов
   - Быстрее стартуют (30-90 секунд)
   
4. **Nginx proxy**
   - Стартует последним, когда все сервисы healthy
   - Имеет 60 секунд `start_period` для дополнительной задержки
   - Автоматически retry при ошибках подключения

### Защита от временных сбоев:

- **DNS**: обновляется каждые 10 секунд вместо 30
- **Retry**: автоматические повторные попытки при 502/503/504
- **Max fails**: сервер помечается как недоступный только после 3 неудачных попыток
- **Fail timeout**: через 30 секунд nginx снова попробует подключиться к "упавшему" серверу

## Использование

### Первый запуск или пересборка:

```bash
docker compose up -d --build
```

Теперь сайт должен работать сразу после завершения сборки и запуска всех контейнеров. Nginx будет автоматически ждать готовности сервисов и делать retry при необходимости.

### Проверка статуса:

```bash
# Посмотреть статус всех контейнеров
docker compose ps

# Посмотреть логи nginx
docker compose logs proxy

# Посмотреть логи backend
docker compose logs backend

# Посмотреть логи в реальном времени
docker compose logs -f
```

### Ожидаемое поведение:

1. Контейнеры запускаются последовательно согласно зависимостям
2. Backend сервисы инициализируются 2-3 минуты
3. Nginx стартует последним и сразу готов к работе
4. При временных проблемах nginx автоматически делает retry
5. Сайт доступен сразу без необходимости restart

## Тестирование

После запуска `docker compose up -d --build` проверьте:

1. **RareBooks Service (rare-books.ru)**:
   - HTTP: http://rare-books.ru/api/test/setup-status
   - HTTPS: https://rare-books.ru/

2. **May Messenger (messenger.rare-books.ru)**:
   - API: https://messenger.rare-books.ru/health
   - Swagger: https://messenger.rare-books.ru/swagger
   - Web Client: https://messenger.rare-books.ru/web/

Все должно работать **сразу** без 502 ошибок.

## Откат изменений (если что-то пошло не так)

Если возникли проблемы с новой конфигурацией:

```bash
# Откатить изменения в git
git checkout HEAD -- docker-compose.yml nginx/nginx_prod.conf

# Перезапустить контейнеры
docker compose down
docker compose up -d
```

## Дополнительные улучшения

Внесённые изменения также улучшают:
- **Устойчивость**: автоматическое восстановление при временных сбоях
- **Производительность**: keepalive соединения правильно используются
- **Мониторинг**: более частые healthcheck'и для быстрого обнаружения проблем
- **Надёжность**: retry логика предотвращает единичные сбои

## Примечания

- Увеличенные `start_period` не замедляют нормальную работу, только первый запуск
- Retry логика работает только при временных ошибках (502, 503, 504)
- DNS кэширование 10 секунд оптимально для Docker среды
- Все существующие функции (SSL, WebSocket, SignalR) работают как прежде

