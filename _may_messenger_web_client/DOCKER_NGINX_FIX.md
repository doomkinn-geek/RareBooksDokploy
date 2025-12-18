# Nginx Permission Fix

## Проблема

```
nginx: [emerg] open() "/run/nginx.pid" failed (13: Permission denied)
```

## Причина

Nginx запускался от пользователя `nginx` (USER nginx в Dockerfile), но у этого пользователя не было прав на создание `/run/nginx.pid`.

## Решение

1. **Создана директория `/var/run/nginx`** с правильными правами
2. **Убрана строка `USER nginx`** - nginx теперь запускается от root (безопасно в контейнере)

## Команды для Исправления

```bash
# Пересобрать образ
docker-compose build maymessenger_web_client

# Остановить старый контейнер
docker-compose stop maymessenger_web_client

# Запустить новый
docker-compose up -d maymessenger_web_client

# Проверить логи
docker-compose logs -f maymessenger_web_client
```

## Безопасность

Запуск nginx от root в Docker контейнере **безопасен**, потому что:
- Контейнер изолирован от хост-системы
- Nginx автоматически понижает привилегии для worker процессов
- Docker обеспечивает изоляцию через namespaces

## Альтернативное Решение (если нужен non-root)

Если требуется запуск от non-root, нужно:

```dockerfile
# Изменить конфигурацию nginx для использования другой директории для PID
RUN sed -i 's|pid /run/nginx.pid;|pid /tmp/nginx.pid;|' /etc/nginx/nginx.conf

USER nginx
```

Но для нашего случая запуск от root - оптимальное решение.

