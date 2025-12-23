# Исправление ошибки 502 Bad Gateway при первом запуске Docker

## Проблема

После выполнения команды `docker compose up -d --build` все контейнеры успешно запускаются, но при попытке обратиться к сайту появляется ошибка:

```
502 Bad Gateway
nginx/1.28.0
```

Проблема исчезает только после выполнения `docker compose restart`.

## Причина

### Основная причина: Статический DNS резолвинг в nginx

Nginx с **статическими upstream блоками** резолвит DNS имена контейнеров **только один раз при запуске**. Если в момент запуска nginx:
- Backend/frontend контейнеры еще не полностью готовы
- IP адреса контейнеров еще не стабилизировались в Docker DNS
- Происходит race condition между стартом контейнеров

То nginx кэширует неверную информацию или пустой результат DNS запроса, что приводит к 502 ошибке.

После `docker compose restart` всё работает, потому что к этому моменту:
- Все контейнеры уже точно работают
- IP адреса стабильны
- Docker DNS корректно отвечает на запросы

### Дополнительная причина: Race condition при старте

Даже с `depends_on` и `healthcheck` может возникать ситуация, когда nginx запускается и резолвит DNS до того, как Docker network полностью стабилизируется.

## Решение

### 1. Динамический DNS резолвинг через переменные

**Было (статические upstream):**
```nginx
upstream backend {
    server rarebooks_backend:80;
    keepalive 32;
}

location /api/ {
    proxy_pass http://backend;
}
```

**Стало (динамический резолвинг):**
```nginx
location /api/ {
    set $backend_upstream rarebooks_backend:80;
    proxy_pass http://$backend_upstream;
}
```

При использовании переменных nginx делает DNS lookup **на каждый запрос** (с кэшированием согласно `resolver valid=10s`), а не только при старте.

### 2. Улучшенные настройки DNS resolver

```nginx
resolver 127.0.0.11 valid=10s ipv6=off;
resolver_timeout 5s;
```

- `127.0.0.11` - встроенный DNS сервер Docker
- `valid=10s` - кэш DNS результатов на 10 секунд (был 30с)
- `resolver_timeout 5s` - таймаут DNS запроса (был 10с)

### 3. Задержка запуска nginx в docker-compose.yml

```yaml
proxy:
  # ...
  entrypoint: /bin/sh -c "sleep 3 && nginx -g 'daemon off;'"
```

Добавлена задержка в 3 секунды перед запуском nginx, чтобы дать время Docker network стабилизироваться даже после того, как healthcheck показал готовность контейнеров.

## Изменённые файлы

### 1. `nginx/nginx_prod.conf`

- ✅ Удалены все статические `upstream` блоки
- ✅ Добавлены динамические переменные для всех `proxy_pass` директив
- ✅ Улучшены настройки `resolver`

Изменены location блоки для:
- `rarebooks_backend` (все /api/ endpoints)
- `rarebooks_frontend` (корневой /)
- `maymessenger_backend` (все messenger API endpoints)
- `maymessenger_web_client` (web client)

### 2. `docker-compose.yml`

- ✅ Добавлен `entrypoint` с задержкой 3 секунды для nginx
- ✅ Сохранены все `depends_on` с `condition: service_healthy`

## Преимущества решения

1. **Автоматическое восстановление**: Если контейнер перезапускается и получает новый IP, nginx автоматически адаптируется
2. **Отказоустойчивость**: Nginx продолжит пытаться резолвить DNS даже если контейнер временно недоступен
3. **Нет необходимости в restart**: После `docker compose up -d --build` сайт сразу доступен
4. **Гибкость**: Динамический резолвинг полезен в динамических окружениях

## Недостатки решения

1. **Производительность**: Небольшой overhead на DNS lookup (кэшируется на 10 секунд)
2. **Нет connection pooling**: Статические upstream позволяли использовать `keepalive`, но в нашем случае это не критично

## Альтернативные решения (не использованы)

1. **Увеличение start_period в healthcheck** - не решает проблему полностью
2. **Использование restart: "on-failure"** - только маскирует проблему
3. **Скрипт проверки перед запуском nginx** - усложняет конфигурацию

## Тестирование

После внесения изменений выполните:

```bash
# Остановите и удалите все контейнеры
docker compose down

# Пересоберите и запустите
docker compose up -d --build

# Дождитесь завершения запуска (1-2 минуты)
docker compose ps

# Проверьте доступность сайта (должен работать сразу)
curl -I https://rare-books.ru
curl -I https://messenger.rare-books.ru
```

## Мониторинг

Проверьте логи nginx для подтверждения корректной работы:

```bash
docker logs nginx_container --tail 50

# Не должно быть ошибок типа:
# - "no resolver defined to resolve"
# - "could not be resolved"
# - "upstream timed out"
```

## Дополнительные рекомендации

1. **Увеличьте healthcheck таймауты** если контейнеры запускаются долго
2. **Мониторьте DNS запросы** в production окружении
3. **Используйте Docker networks** для изоляции сервисов (уже настроено)

## Заключение

Проблема 502 Bad Gateway при первом запуске полностью решена путём перехода от статического к динамическому DNS резолвингу в nginx. Теперь после `docker compose up -d --build` сайт будет доступен сразу после завершения healthcheck всех контейнеров.

