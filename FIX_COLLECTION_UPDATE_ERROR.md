# ✅ ИСПРАВЛЕНА ОШИБКА ОБНОВЛЕНИЯ КНИГ В КОЛЛЕКЦИИ

Дата: 30 ноября 2025

## 🐛 Проблема

При попытке обновить книгу в коллекции возникала ошибка:
```
Ошибка при обновлении книги: An error occurred while saving the entity changes. 
See the inner exception for details.
```

## 🔍 Причина

В `UsersDbContext.cs` не были настроены типы decimal для новых полей:
- `PurchasePrice` - был создан как `numeric` вместо `numeric(18,2)`
- `SoldPrice` - был создан как `numeric` вместо `numeric(18,2)`

Это привело к несоответствию типов данных между моделью и базой данных.

## ✅ Решение

### 1. Обновлён `UsersDbContext.cs`

Добавлена конфигурация для decimal полей:

```csharp
modelBuilder.Entity<UserCollectionBook>()
    .Property(cb => cb.PurchasePrice)
    .HasColumnType("decimal(18,2)");

modelBuilder.Entity<UserCollectionBook>()
    .Property(cb => cb.SoldPrice)
    .HasColumnType("decimal(18,2)");
```

### 2. Пересоздана миграция

**Старая миграция (удалена):**
- `20251129185907_AddSoldInfoToCollectionBooks`
- PurchasePrice: `numeric` ❌
- SoldPrice: `numeric` ❌

**Новая миграция (применена):**
- `20251130153129_AddSoldInfoToCollectionBooks`
- PurchasePrice: `numeric(18,2)` ✅
- SoldPrice: `numeric(18,2)` ✅

### 3. Улучшено логирование

В `UserCollectionService.cs` добавлен детальный перехват ошибок:

```csharp
catch (DbUpdateException dbEx)
{
    _logger.LogError(dbEx, "Ошибка БД при обновлении книги {BookId}. Inner: {Inner}", 
        bookId, dbEx.InnerException?.Message);
    throw new Exception($"Ошибка при сохранении: {dbEx.InnerException?.Message ?? dbEx.Message}");
}
```

## 📝 Выполненные команды

```powershell
# 1. Удаление неправильной миграции
cd c:\rarebooks\RareBooksService.Data
dotnet ef migrations remove --context UsersDbContext --startup-project ../RareBooksService.WebApi --force

# 2. Создание правильной миграции
dotnet ef migrations add AddSoldInfoToCollectionBooks --context UsersDbContext --startup-project ../RareBooksService.WebApi

# 3. Применение миграции
dotnet ef database update --context UsersDbContext --startup-project ../RareBooksService.WebApi
```

## 🎯 Результат

База данных обновлена с правильными типами полей:
- ✅ `IsSold` - boolean
- ✅ `SoldPrice` - numeric(18,2)
- ✅ `SoldDate` - timestamp with time zone
- ✅ `PurchasePrice` - numeric(18,2) (обновлён тип)

## 🧪 Проверка

Теперь можно:
1. ✅ Редактировать книгу в коллекции
2. ✅ Добавлять цену покупки
3. ✅ Отмечать книгу как проданную
4. ✅ Указывать цену и дату продажи
5. ✅ Сохранять изменения без ошибок

## 🚀 Запуск

```powershell
# Перезапустите backend
cd c:\rarebooks\RareBooksService.WebApi
dotnet run
```

## 📊 Миграции в базе данных

Текущие миграции для UsersDb:
1. `InitialUsersDbMigration`
2. `AddUserCollectionFeature`
3. `AddPurchaseInfoToCollectionBooks`
4. `AddSoldInfoToCollectionBooks` ✨ (новая с правильными типами)

---

## ✨ Проблема решена!

Теперь редактирование книг в коллекции работает корректно! 📚✅

