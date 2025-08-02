# 🔄 Завершена система экспорта/импорта для миграции на новый сервер

## 📋 Обзор решения

Создана **полная система экспорта и импорта данных** для миграции на новый сервер, включающая:

1. ✅ **Экспорт/импорт данных книг** (уже было)
2. ✅ **Экспорт/импорт планов подписок** (добавлено)
3. ✅ **Экспорт/импорт пользователей с подписками** (улучшено)

## 🎯 Правильная последовательность миграции

### 📌 КРИТИЧЕСКИ ВАЖНО: Порядок выполнения

```
1️⃣ СНАЧАЛА: Экспорт/импорт планов подписок
2️⃣ ЗАТЕМ: Экспорт/импорт пользователей (с подписками)
3️⃣ В КОНЦЕ: Экспорт/импорт данных книг
```

**Почему именно в таком порядке?**
- Пользователи ссылаются на планы подписок через `SubscriptionPlanId`
- Без планов подписок импорт пользователей будет пропускать подписки
- Книги не зависят от пользователей и подписок

## 🔧 Реализованные компоненты

### 1. Сервисы экспорта планов подписок

**`SubscriptionPlanExportService`** - экспорт планов подписок:
```csharp
// Endpoint: POST /api/admin/export-subscription-plans
// Progress: GET /api/admin/subscription-plan-export-progress/{taskId}
// Download: GET /api/admin/download-exported-subscription-plans/{taskId}
```

**`SubscriptionPlanImportService`** - импорт планов подписок:
```csharp
// Start: POST /api/admin/start-subscription-plan-import
// Upload: POST /api/admin/subscription-plan-import/{importId}/chunk
// Progress: GET /api/admin/subscription-plan-import-progress/{importId}
```

### 2. Улучшенные сервисы пользователей

**`UserExportService`** - теперь экспортирует **ВСЕ данные для авторизации**:
```csharp
public class ExportedUserData
{
    // Основные поля пользователя
    public string Id { get; set; }
    public string UserName { get; set; }
    public string Email { get; set; }
    public bool EmailConfirmed { get; set; }
    // ... другие поля ...
    
    // ⭐ КРИТИЧЕСКИ ВАЖНЫЕ поля для авторизации
    public string NormalizedUserName { get; set; }    // NEW
    public string NormalizedEmail { get; set; }       // NEW  
    public string PasswordHash { get; set; }          // NEW
    public string SecurityStamp { get; set; }         // NEW
    public string ConcurrencyStamp { get; set; }      // NEW
    
    // Связанные данные
    public List<ExportedSubscription> Subscriptions { get; set; }
    public List<ExportedUserSearchHistory> SearchHistory { get; set; }
    public List<ExportedUserFavoriteBook> FavoriteBooks { get; set; }
}
```

**`UserImportService`** - корректно восстанавливает пользователей:
```csharp
// ⚠️ КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ: Используется прямое добавление в DbContext
usersContext.Users.Add(newUser);  // вместо userManager.CreateAsync()

// ✅ Это сохраняет уже хешированные пароли без перехеширования
```

### 3. Структура экспорта подписок

**`ExportedSubscriptionPlan`**:
```csharp
public class ExportedSubscriptionPlan
{
    public int Id { get; set; }                  // Сохраняется исходный ID
    public string Name { get; set; }
    public string Description { get; set; }
    public decimal Price { get; set; }
    public int MonthlyRequestLimit { get; set; }
    public bool IsActive { get; set; }
}
```

**`ExportedSubscription`** (в составе пользователя):
```csharp
public class ExportedSubscription
{
    public int SubscriptionPlanId { get; set; }      // Ссылка на план
    public string SubscriptionPlanName { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public bool IsActive { get; set; }
    public bool AutoRenew { get; set; }
    public string PaymentId { get; set; }
    public decimal PriceAtPurchase { get; set; }
    // ... другие поля платежей
}
```

## 📊 API Endpoints

### Планы подписок
```http
# Экспорт планов подписок
POST   /api/admin/export-subscription-plans
GET    /api/admin/subscription-plan-export-progress/{taskId}
GET    /api/admin/download-exported-subscription-plans/{taskId}
POST   /api/admin/cancel-subscription-plan-export/{taskId}

# Импорт планов подписок  
POST   /api/admin/start-subscription-plan-import
POST   /api/admin/subscription-plan-import/{importId}/chunk
POST   /api/admin/subscription-plan-import/{importId}/finish
GET    /api/admin/subscription-plan-import-progress/{importId}
POST   /api/admin/cancel-subscription-plan-import/{importId}
```

### Пользователи (уже существующие, улучшенные)
```http
# Экспорт пользователей (с подписками и авторизацией)
POST   /api/admin/export-users
GET    /api/admin/user-export-progress/{taskId}
GET    /api/admin/download-exported-users/{taskId}

# Импорт пользователей
POST   /api/admin/start-user-import
POST   /api/admin/user-import/{importId}/chunk
GET    /api/admin/user-import-progress/{importId}
```

### Данные книг (уже существующие)
```http
# Экспорт данных книг
POST   /api/admin/export-data
GET    /api/admin/export-progress/{taskId}
GET    /api/admin/download-exported-file/{taskId}
```

## 🔐 Безопасность авторизации

### Что сохраняется при экспорте пользователей:

✅ **PasswordHash** - хешированные пароли  
✅ **SecurityStamp** - для инвалидации токенов  
✅ **ConcurrencyStamp** - для optimistic concurrency  
✅ **NormalizedUserName** - для быстрого поиска  
✅ **NormalizedEmail** - для быстрого поиска  

### Как работает импорт:

1. **Проверка ID конфликтов**: Если `userId` уже существует, генерируется новый GUID
2. **Прямое добавление**: `usersContext.Users.Add()` вместо `userManager.CreateAsync()`
3. **Сохранение хешей**: Пароли НЕ перехешируются, используются исходные хеши
4. **Связанные данные**: Обновляются `UserId` для истории поиска, избранного, подписок

## 🛠️ Инструкция по миграции

### Шаг 1: Экспорт планов подписок
```bash
# На старом сервере
curl -X POST "https://old-server.com/api/admin/export-subscription-plans" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Скачиваем subscription_plans_export_{taskId}.zip
```

### Шаг 2: Импорт планов подписок
```bash
# На новом сервере
# Загружаем subscription_plans_export_{taskId}.zip через веб-интерфейс
# или API импорта планов подписок
```

### Шаг 3: Экспорт пользователей
```bash
# На старом сервере
curl -X POST "https://old-server.com/api/admin/export-users" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Скачиваем user_export_{taskId}.zip
```

### Шаг 4: Импорт пользователей
```bash
# На новом сервере
# Загружаем user_export_{taskId}.zip через веб-интерфейс
# Все подписки восстановятся автоматически
```

### Шаг 5: Экспорт данных книг
```bash
# На старом сервере (обычно самый большой файл)
curl -X POST "https://old-server.com/api/admin/export-data" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Скачиваем export_{taskId}.zip
```

### Шаг 6: Импорт данных книг
```bash
# На новом сервере
# Загружаем export_{taskId}.zip через веб-интерфейс
```

## ⚠️ Важные особенности

### Подписки зависят от планов
```csharp
// В UserImportService.cs - проверка существования плана
var existingPlan = await usersContext.SubscriptionPlans
    .FirstOrDefaultAsync(sp => sp.Id == subscription.SubscriptionPlanId);

if (existingPlan != null)
{
    // ✅ Импортируем подписку
    var newSubscription = new Subscription { ... };
}
else
{
    // ❌ Пропускаем подписку
    stats.Errors.Add($"План подписки {subscription.SubscriptionPlanId} не найден");
}
```

### Авторизация сохраняется полностью
```csharp
// Пользователи смогут входить с теми же паролями
var newUser = new ApplicationUser
{
    // Основные поля...
    PasswordHash = exportedUser.PasswordHash,        // ⭐ Исходный хеш
    SecurityStamp = exportedUser.SecurityStamp,      // ⭐ Исходный stamp  
    ConcurrencyStamp = exportedUser.ConcurrencyStamp // ⭐ Исходный stamp
};
```

### Логирование и мониторинг
- ✅ Детальные логи экспорта/импорта планов
- ✅ Статистика: импортировано/обновлено/пропущено
- ✅ Обработка ошибок с конкретными сообщениями
- ✅ Прогресс-бары для всех операций

## 🎯 Итоговый результат

**После миграции вы получите:**

✅ **Все планы подписок** со всеми настройками  
✅ **Всех пользователей** с сохраненными паролями  
✅ **Все подписки пользователей** с историей платежей  
✅ **Всю историю поиска** пользователей  
✅ **Все избранные книги** пользователей  
✅ **Все данные книг** с категориями  

**Пользователи смогут:**
- Войти с теми же логинами и паролями
- Использовать свои активные подписки
- Видеть историю поиска и избранные книги

## 🔗 Связанные файлы

- `RareBooksService.WebApi/Services/SubscriptionPlanExportService.cs`
- `RareBooksService.WebApi/Services/SubscriptionPlanImportService.cs` 
- `RareBooksService.WebApi/Services/UserExportService.cs` (улучшен)
- `RareBooksService.WebApi/Services/UserImportService.cs` (улучшен)
- `RareBooksService.WebApi/Controllers/AdminController.cs` (добавлены endpoints)
- `RareBooksService.WebApi/Program.cs` (зарегистрированы сервисы)

**🎉 Система миграции данных готова к использованию!** 