# Устранение проблем с доступом к коллекции

## Проблема
Не отображается ссылка "Моя коллекция" на главной странице и в меню, перенаправляет на авторизацию при переходе на `/collection`.

## Решение

### Шаг 1: Обновите планы подписки в базе данных

Выполните SQL скрипт для добавления доступа к коллекции:

```bash
# Подключитесь к базе данных PostgreSQL
psql -U postgres -d UsersDb

# Выполните скрипт
\i update_subscription_plans_collection_access.sql
```

Или выполните вручную:

```sql
UPDATE "SubscriptionPlans"
SET "HasCollectionAccess" = true
WHERE "IsActive" = true;
```

### Шаг 2: Перезапустите backend

```bash
cd c:\rarebooks\RareBooksService.WebApi
dotnet run
```

### Шаг 3: Очистите кэш браузера и перезагрузите frontend

1. Откройте DevTools (F12)
2. Перейдите в Application > Storage > Clear site data
3. Перезагрузите страницу (Ctrl+F5)

### Шаг 4: Проверьте логи в консоли браузера

После авторизации откройте консоль браузера (F12) и найдите:

```
refreshUser - Полученные данные пользователя: { ... }
refreshUser - HasCollectionAccess: true/false
refreshUser - CurrentSubscription: { ... }
```

Убедитесь что:
- `HasCollectionAccess` = `true`
- `CurrentSubscription` содержит объект с `subscriptionPlan.hasCollectionAccess = true`

### Шаг 5: Проверьте подписку пользователя

Выполните SQL запрос:

```sql
SELECT 
    u."UserName",
    u."Email",
    s."Id" as "SubscriptionId",
    s."IsActive",
    sp."Name" as "PlanName",
    sp."HasCollectionAccess"
FROM "AspNetUsers" u
LEFT JOIN "Subscriptions" s ON u."Id" = s."UserId"
LEFT JOIN "SubscriptionPlans" sp ON s."SubscriptionPlanId" = sp."Id"
WHERE u."Email" = 'your-email@example.com';  -- Замените на ваш email
```

Убедитесь что:
- У пользователя есть активная подписка (`IsActive` = `true`)
- У плана подписки `HasCollectionAccess` = `true`

### Шаг 6: Проверьте API напрямую

Откройте в браузере (или через curl):

```bash
# Получите токен из cookies (DevTools > Application > Cookies)
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:5000/api/auth/user
```

Ответ должен содержать:

```json
{
  "id": "...",
  "email": "...",
  "hasCollectionAccess": true,
  "currentSubscription": {
    "subscriptionPlan": {
      "hasCollectionAccess": true
    }
  }
}
```

## Что было исправлено

### Backend
1. ✅ `AuthController.GetUser()` теперь загружает подписки с планами
2. ✅ Возвращает `HasCollectionAccess` в ответе
3. ✅ `SubscriptionPlansController.Update()` обновляет поле `HasCollectionAccess`

### Frontend
1. ✅ `App.jsx` проверяет `user.HasCollectionAccess` в меню
2. ✅ `Home.jsx` показывает карточку "Управление коллекцией" с кнопкой
3. ✅ `UserContext` логирует данные о доступе к коллекции

## Часто встречающиеся проблемы

### 1. Пользователь видит меню, но перенаправляется на авторизацию

**Причина:** Токен истек или недействителен

**Решение:** 
- Выйдите из системы
- Войдите заново
- Проверьте срок действия токена

### 2. API возвращает HasCollectionAccess = false

**Причина:** У плана подписки не установлен флаг

**Решение:**
1. Откройте админ-панель (`/admin`)
2. Перейдите в "Управление планами подписки"
3. Отредактируйте нужный план
4. Включите "Доступ к коллекции"
5. Сохраните

### 3. После обновления плана ничего не изменилось

**Причина:** Frontend использует закэшированные данные

**Решение:**
- Обновите страницу (F5)
- Или выйдите и войдите заново

## Проверка работоспособности

После всех шагов должно работать:

1. ✅ В верхнем меню появляется пункт "Моя коллекция" (если авторизованы)
2. ✅ На главной странице в блоке "Как это работает" появляется карточка №5 "Управление коллекцией"
3. ✅ При клике открывается страница `/collection`
4. ✅ Можно добавлять книги, загружать изображения, искать аналоги

## Логи для диагностики

### Backend (в консоли где запущен dotnet run)
```
Информация о пользователе с ID {UserId} успешно получена. HasCollectionAccess: True
```

### Frontend (в консоли браузера)
```
refreshUser - HasCollectionAccess: true
refreshUser - CurrentSubscription: { subscriptionPlan: { hasCollectionAccess: true } }
```

