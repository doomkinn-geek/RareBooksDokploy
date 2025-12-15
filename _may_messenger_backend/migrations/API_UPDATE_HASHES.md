# Обновление хешей через API

## Endpoint для администратора

```
POST /api/admin/update-phone-hashes
```

### Требования:
- ✅ Авторизация (Bearer token)
- ✅ Роль: **Admin**

## Использование через Swagger

1. Откройте Swagger UI:
   ```
   https://messenger.rare-books.ru/swagger
   ```

2. Авторизуйтесь как администратор:
   - Нажмите **Authorize** (замок в правом верхнем углу)
   - Введите: `Bearer YOUR_ADMIN_TOKEN`
   - Нажмите **Authorize**

3. Найдите endpoint:
   ```
   Admin → POST /api/admin/update-phone-hashes
   ```

4. Нажмите **Try it out** → **Execute**

5. Результат:
   ```json
   {
     "success": true,
     "updatedCount": 5,
     "message": "Successfully updated 5 user(s)"
   }
   ```

## Использование через curl

```bash
curl -X POST "https://messenger.rare-books.ru/api/admin/update-phone-hashes" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  -H "Content-Type: application/json"
```

## Использование через PowerShell

```powershell
$token = "YOUR_ADMIN_TOKEN"
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

Invoke-RestMethod -Uri "https://messenger.rare-books.ru/api/admin/update-phone-hashes" `
    -Method POST `
    -Headers $headers
```

## Что делает endpoint

1. ✅ Получает всех пользователей из БД
2. ✅ Для каждого пользователя:
   - Нормализует номер телефона (удаляет символы, заменяет 8→+7)
   - Вычисляет новый SHA256 хеш
   - Сравнивает с текущим хешем
3. ✅ Обновляет только изменённые хеши
4. ✅ Возвращает количество обновлённых записей

## Примеры ответов

### Успешное обновление:
```json
{
  "success": true,
  "updatedCount": 3,
  "message": "Successfully updated 3 user(s)"
}
```

### Хеши уже актуальны:
```json
{
  "success": true,
  "updatedCount": 0,
  "message": "All phone hashes are already up to date"
}
```

### Ошибка (401 Unauthorized):
```json
{
  "message": "Unauthorized"
}
```

### Ошибка (403 Forbidden):
```json
{
  "message": "User does not have required role: Admin"
}
```

## Как получить admin token

### Вариант 1: Через регистрацию с ролью Admin
Обратитесь к разработчику для создания admin пользователя.

### Вариант 2: Через SQL (установить роль существующему пользователю)
```sql
UPDATE "Users" 
SET "Role" = 1 -- 1 = Admin, 0 = User
WHERE "PhoneNumber" = '+79094924190';
```

Затем авторизуйтесь через `/api/auth/login` и используйте полученный token.

## Безопасность

⚠️ **Важно:**
- Endpoint доступен только администраторам
- Требует Bearer token авторизации
- Не принимает параметров (безопасно)
- Идемпотентен (можно вызывать многократно)

## Когда использовать

- ✅ После обновления backend с нормализацией номеров
- ✅ Если контакты не находятся из-за разных форматов номеров
- ✅ Вместо SQL миграции (если нет прямого доступа к БД)
- ✅ Для тестирования после изменений в логике хеширования

## Альтернативы

### SQL миграция (требует доступ к БД):
```bash
docker compose exec -T postgres psql -U postgres -d maymessenger -f /tmp/update_phone_hashes.sql
```

### Полная пересборка БД (удаляет все данные):
```bash
docker compose down && docker volume rm rarebooks_postgres_data && docker compose up -d
```
