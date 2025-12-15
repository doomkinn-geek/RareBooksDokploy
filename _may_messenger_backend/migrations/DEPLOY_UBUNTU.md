# Развертывание миграции на Ubuntu сервере

## 1. Скопировать SQL на сервер
```bash
scp _may_messenger_backend/migrations/update_phone_hashes.sql user@messenger.rare-books.ru:/tmp/
```

## 2. Подключиться к серверу
```bash
ssh user@messenger.rare-books.ru
```

## 3. Выполнить миграцию
```bash
cd /path/to/rarebooks

# Скопировать в контейнер
docker cp /tmp/update_phone_hashes.sql rarebooks-postgres-1:/tmp/

# Выполнить SQL
docker compose exec -T postgres psql -U postgres -d maymessenger -f /tmp/update_phone_hashes.sql

# Пересобрать и перезапустить backend
docker compose build maymessenger_backend
docker compose up -d maymessenger_backend
```

## 4. Проверить
```bash
# Проверить логи
docker compose logs maymessenger_backend --tail=50

# Проверить health
curl -k https://messenger.rare-books.ru/health
```

Готово! Теперь установите новый APK на телефоны.
