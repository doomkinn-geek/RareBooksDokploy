# Развертывание нового API endpoint

## Что изменено

✅ Добавлен endpoint: `POST /api/admin/update-phone-hashes`
✅ Доступен только администраторам
✅ Обновляет хеши всех пользователей с нормализацией

## Развертывание на сервере

### На Ubuntu сервере:

```bash
cd /path/to/rarebooks

# Собрать и перезапустить backend
docker compose build maymessenger_backend
docker compose up -d maymessenger_backend

# Проверить
docker compose logs maymessenger_backend --tail=50
curl -k https://messenger.rare-books.ru/health
```

### Одна команда:

```bash
cd /path/to/rarebooks && docker compose build maymessenger_backend && docker compose up -d maymessenger_backend
```

## Использование

### Через Swagger (самый простой способ):

1. Откройте: https://messenger.rare-books.ru/swagger
2. Авторизуйтесь как Admin (Authorize → Bearer YOUR_TOKEN)
3. Найдите: `Admin → POST /api/admin/update-phone-hashes`
4. Нажмите **Try it out** → **Execute**

### Через curl:

```bash
curl -X POST "https://messenger.rare-books.ru/api/admin/update-phone-hashes" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

### Ожидаемый результат:

```json
{
  "success": true,
  "updatedCount": 5,
  "message": "Successfully updated 5 user(s)"
}
```

## Получить Admin токен

### Способ 1: Через SQL (назначить роль)

```sql
UPDATE "Users" 
SET "Role" = 1
WHERE "PhoneNumber" = '+79094924190';
```

Затем авторизуйтесь через `/api/auth/login`.

### Способ 2: Через API создание пользователя

Обратитесь к разработчику для создания admin аккаунта.

## Проверка работы

1. **Развернуть backend**
2. **Получить admin token**
3. **Вызвать endpoint через Swagger**
4. **Проверить результат**: контакты должны находиться корректно

## Документация

Полная документация: `_may_messenger_backend/migrations/API_UPDATE_HASHES.md`
