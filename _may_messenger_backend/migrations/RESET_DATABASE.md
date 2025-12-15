# Полная пересборка базы данных

## ⚠️ ВАЖНО
Это **удалит все данные**: пользователей, чаты, сообщения, контакты!

## На Ubuntu сервере

```bash
cd /path/to/rarebooks

# 1. Остановить все контейнеры
docker compose down

# 2. Удалить volume с базой данных
docker volume rm rarebooks_postgres_data

# 3. Запустить заново (БД создастся с нуля)
docker compose up -d

# 4. Проверить
docker compose logs maymessenger_backend --tail=50
curl -k https://messenger.rare-books.ru/health
```

## Одна команда

```bash
cd /path/to/rarebooks && docker compose down && docker volume rm rarebooks_postgres_data && docker compose up -d
```

## Проверка имени volume

Если volume называется иначе:
```bash
docker volume ls | grep postgres
```

Затем используйте правильное имя:
```bash
docker volume rm ACTUAL_VOLUME_NAME
```

## После пересборки

1. Все пользователи должны зарегистрироваться заново
2. Новые регистрации будут с правильными хешами
3. Контакты будут находиться корректно
