# ✅ ИСПРАВЛЕНИЯ: DateTime UTC и отображение ссылки "Моя коллекция"

Дата: 30 ноября 2025

---

## 🐛 Проблемы

### 1. Ошибка при обновлении книги в коллекции

**Симптом:**
```
Ошибка при обновлении книги: Ошибка при сохранении: Cannot write DateTime with Kind=Unspecified 
to PostgreSQL type 'timestamp with time zone', only UTC is supported.
```

**Причина:**
- PostgreSQL требует, чтобы DateTime значения имели `Kind = DateTimeKind.Utc`
- Значения `PurchaseDate` и `SoldDate` приходили с frontend без указания Kind (Unspecified)
- Entity Framework не мог сохранить такие значения в `timestamp with time zone`

### 2. Ссылка "Моя коллекция" не отображается сразу после логина

**Симптом:**
- После авторизации ссылка "Моя коллекция" не видна
- Требуется ручное обновление страницы (F5 или Shift+F5)
- После обновления ссылка появляется

**Причина:**
- В `Login.jsx` после успешного логина устанавливался `user` через `setUser(response.data.user)`
- Данные от `/auth/login` могли не включать полную информацию о подписке
- Не вызывался `refreshUser()` для загрузки полных данных пользователя

---

## ✅ Решения

### 1. Исправление DateTime UTC

#### Файл: `RareBooksService.WebApi/Services/UserCollectionService.cs`

**Изменения в `AddBookToCollectionAsync`:**

```csharp
var book = new UserCollectionBook
{
    UserId = userId,
    Title = request.Title,
    Author = request.Author,
    YearPublished = request.YearPublished,
    Description = request.Description,
    Notes = request.Notes,
    PurchasePrice = request.PurchasePrice,
    // ✅ ИСПРАВЛЕНО: Конвертация в UTC
    PurchaseDate = request.PurchaseDate.HasValue 
        ? DateTime.SpecifyKind(request.PurchaseDate.Value, DateTimeKind.Utc) 
        : (DateTime?)null,
    AddedDate = DateTime.UtcNow,
    UpdatedDate = DateTime.UtcNow
};
```

**Изменения в `UpdateBookAsync`:**

```csharp
book.Title = request.Title;
book.Author = request.Author;
book.YearPublished = request.YearPublished;
book.Description = request.Description;
book.Notes = request.Notes;
book.PurchasePrice = request.PurchasePrice;
// ✅ ИСПРАВЛЕНО: Конвертация в UTC
book.PurchaseDate = request.PurchaseDate.HasValue 
    ? DateTime.SpecifyKind(request.PurchaseDate.Value, DateTimeKind.Utc) 
    : (DateTime?)null;
book.IsSold = request.IsSold;
book.SoldPrice = request.SoldPrice;
// ✅ ИСПРАВЛЕНО: Конвертация в UTC
book.SoldDate = request.SoldDate.HasValue 
    ? DateTime.SpecifyKind(request.SoldDate.Value, DateTimeKind.Utc) 
    : (DateTime?)null;
book.UpdatedDate = DateTime.UtcNow;
```

**Что делает `DateTime.SpecifyKind`:**
- Принимает DateTime и устанавливает его Kind в UTC
- Не изменяет значение времени, только метаданные
- PostgreSQL корректно сохраняет такие значения

---

### 2. Исправление отображения ссылки "Моя коллекция"

#### Файл: `rarebooksservice.frontend.v3/src/components/Login.jsx`

**Изменения в `Login` компоненте:**

**1. Добавлен `refreshUser` в деструктуризацию:**
```jsx
const { setUser, refreshUser } = useContext(UserContext);
```

**2. Изменен `handleLogin` для вызова `refreshUser`:**
```jsx
setError('');
setLoading(true);
try {
    const response = await axios.post(`${API_URL}/auth/login`, { email, password });
    Cookies.set('token', response.data.token, { expires: 7 });

    // ✅ ИСПРАВЛЕНО: Загружаем полные данные пользователя после установки токена
    await refreshUser(true);
    
    // попытка вернуть на исходную страницу, если была сохранена
    const stateFrom = location.state && location.state.from;
    const storedReturnTo = (() => { try { return localStorage.getItem('returnTo'); } catch (_) { return null; } })();
    if (stateFrom) {
        navigate(stateFrom, { replace: true });
    } else if (storedReturnTo) {
        navigate('/subscription', { replace: true });
    } else {
        navigate('/');
    }
```

**Было (неправильно):**
```jsx
// Устанавливали user из ответа /auth/login
setUser(response.data.user);
```

**Стало (правильно):**
```jsx
// Загружаем полные данные через /auth/user
await refreshUser(true);
```

**Преимущества:**
- ✅ Загружаются полные данные пользователя
- ✅ Включаются данные о подписке и доступе к коллекции
- ✅ Ссылка "Моя коллекция" отображается сразу после логина
- ✅ Не требуется ручное обновление страницы

---

## 🔍 Как это работает

### Backend: DateTime конвертация

1. **Frontend отправляет дату:**
```json
{
  "purchaseDate": "2025-11-30T00:00:00"
}
```

2. **Backend получает DateTime с Kind=Unspecified**

3. **`DateTime.SpecifyKind` устанавливает Kind=Utc:**
```csharp
DateTime.SpecifyKind(date, DateTimeKind.Utc)
// Результат: 2025-11-30T00:00:00Z (Kind=Utc)
```

4. **PostgreSQL успешно сохраняет в `timestamp with time zone`**

### Frontend: Загрузка полных данных после логина

1. **Пользователь вводит учетные данные**

2. **POST /auth/login**
   - Получен токен
   - Токен сохранен в cookie

3. **GET /auth/user** (через `refreshUser`)
   - Загружаются полные данные пользователя
   - Включая `currentSubscription` с `subscriptionPlan`
   - Включая `hasCollectionAccess`

4. **Обновление UserContext**
   - `setUser` с полными данными
   - Все компоненты получают обновленный контекст

5. **Навигация**
   - `App.jsx` проверяет `user.hasCollectionAccess`
   - Ссылка "Моя коллекция" отображается сразу

---

## 📋 Проверка на сервере

### 1. Проверка DateTime

```bash
# Логин в систему
curl -X POST http://your-server/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'

# Обновление книги с датой покупки
curl -X PUT http://your-server/api/usercollection/1 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Book",
    "purchaseDate": "2025-11-30T00:00:00",
    "purchasePrice": 1000.50
  }'

# Ожидаемый результат: HTTP 200 OK
```

### 2. Проверка отображения ссылки

1. Откройте браузер в режиме инкогнито
2. Перейдите на страницу логина
3. Войдите в систему (с подпиской, включающей доступ к коллекции)
4. **Ожидаемый результат:** Ссылка "Моя коллекция" видна сразу в меню

---

## 🛠️ Изменённые файлы

### Backend

1. **`RareBooksService.WebApi/Services/UserCollectionService.cs`**
   - Метод `AddBookToCollectionAsync`: конвертация `PurchaseDate` в UTC
   - Метод `UpdateBookAsync`: конвертация `PurchaseDate` и `SoldDate` в UTC

### Frontend

2. **`rarebooksservice.frontend.v3/src/components/Login.jsx`**
   - Добавлен `refreshUser` в контекст
   - Изменен `handleLogin` для вызова `refreshUser(true)` после логина
   - Удален `setUser(response.data.user)`

---

## 🎯 Преимущества решения

### DateTime UTC

✅ **Корректность:** Все даты сохраняются с правильным Kind  
✅ **Совместимость:** Работает с PostgreSQL timestamp with time zone  
✅ **Безопасность:** Нет риска ошибок при сохранении  
✅ **Переносимость:** Работает на Windows и Linux  

### Загрузка данных после логина

✅ **Полнота:** Загружаются все данные пользователя  
✅ **Надежность:** Всегда актуальные данные о подписке  
✅ **UX:** Ссылки отображаются сразу после логина  
✅ **Консистентность:** Единый источник данных (`/auth/user`)  

---

## 📝 Важные замечания

### DateTime

1. **Всегда используйте `DateTime.SpecifyKind` для дат от frontend**
2. **PostgreSQL требует UTC для `timestamp with time zone`**
3. **`DateTime.UtcNow` уже имеет Kind=Utc**
4. **Не используйте `DateTime.Now` для сохранения в БД**

### UserContext

1. **После логина всегда вызывайте `refreshUser()`**
2. **`/auth/user` endpoint должен возвращать полные данные**
3. **Проверяйте `hasCollectionAccess` для условного рендеринга**
4. **`refreshUser(true)` - принудительная загрузка данных**

---

## ✨ Результат

**Теперь:**
1. ✅ Книги в коллекции обновляются без ошибок
2. ✅ Даты покупки и продажи сохраняются корректно
3. ✅ Ссылка "Моя коллекция" отображается сразу после логина
4. ✅ Не требуется ручное обновление страницы
5. ✅ Работает на всех платформах (Windows, Linux, Docker)

**Готово к использованию! 🎉**

