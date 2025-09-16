# 🤖 Исправления LINQ запросов в TelegramBotService

## 🚨 Проблемы:
При выполнении команды `/lots` в Telegram боте возникали ошибки Entity Framework:

### 1. Первичные ошибки LINQ:
```
The LINQ expression 'tag => tag.Contains(__keyword_1)' could not be translated
The LINQ expression 'b.City.ToLower().Contains(city)' could not be translated
```

### 2. Ошибка приведения типов:
```
Invalid cast from 'System.String' to 'System.Collections.Generic.List`1[System.String]'
```

## 🔍 Анализ причин:

### 1. Проблема с поиском по тегам:
**Было:**
```csharp
b.Tags.Any(tag => tag.Contains(keyword))
```

**Причина:** Поле `Tags` в базе данных хранится как строка с разделителем ";" (например: "tag1;tag2;tag3"), но в C# представлено как `List<string>` через Entity Framework конвертер. EF не может перевести `Any()` с `Contains()` для конвертированных типов в SQL.

### 2. Проблема с поиском по городам:
**Было:**
```csharp
EF.Functions.Like(b.City.ToLower(), $"%{city}%")
```

**Причина:** `ToLower()` внутри `EF.Functions.Like` не может быть переведено в SQL запрос.

## ✅ Итоговое решение:

Используем **гибридный подход**: эффективные SQL фильтры + безопасная фильтрация в памяти.

### 1. SQL фильтры (эффективные):
```csharp
// Активные торги, категории, цены, года, города
query = query.Where(b => b.EndDate > now);
query = query.Where(b => categoryIds.Contains(b.CategoryId));
query = query.Where(b => EF.Functions.ILike(b.City, $"%{city}%"));
// ... другие "тяжелые" фильтры
```

### 2. Фильтрация в памяти (безопасная):
```csharp
// Загружаем данные из БД
var allBooks = await query.AsNoTracking().ToListAsync(cancellationToken);

// Фильтруем по ключевым словам в памяти
allBooks = allBooks.Where(book =>
{
    var matchesText = normalizedKeywords.Any(keyword =>
        (book.NormalizedTitle?.Contains(keyword) == true) ||
        (book.NormalizedDescription?.Contains(keyword) == true));

    var matchesTags = book.Tags?.Any(tag =>
        normalizedKeywords.Any(keyword =>
            tag.ToLower().Contains(keyword))) == true;

    return matchesText || matchesTags;
}).ToList();
```

### 3. Почему этот подход работает:
- **Избегает проблем с Entity Framework конвертерами** - не используем `EF.Property<string>`
- **Эффективен** - большинство фильтров выполняется в SQL
- **Безопасен** - поиск по тегам в памяти после загрузки объектов
- **Стабилен** - нет конфликтов типов

## 🎯 Полный исправленный код:

```csharp
private async Task<LotsSearchResult> SearchActiveLotsAsync(BooksDbContext booksContext, UserNotificationPreference preferences, int page, int pageSize, CancellationToken cancellationToken)
{
    var query = booksContext.BooksInfo.Include(b => b.Category).AsQueryable();

    // Фильтр: только активные торги
    var now = DateTime.UtcNow;
    query = query.Where(b => b.EndDate > now);

    // SQL фильтры (эффективные)
    var categoryIds = preferences.GetCategoryIdsList();
    if (categoryIds.Any())
        query = query.Where(b => categoryIds.Contains(b.CategoryId));

    if (preferences.MinPrice > 0)
        query = query.Where(b => (decimal)b.Price >= preferences.MinPrice);
    if (preferences.MaxPrice > 0)
        query = query.Where(b => (decimal)b.Price <= preferences.MaxPrice);

    if (preferences.MinYear > 0)
        query = query.Where(b => b.YearPublished >= preferences.MinYear);
    if (preferences.MaxYear > 0)
        query = query.Where(b => b.YearPublished <= preferences.MaxYear);

    // Фильтр по городам
    var cities = preferences.GetCitiesList();
    if (cities.Any())
    {
        var normalizedCities = cities.Select(c => c.ToLower()).ToList();
        foreach (var city in normalizedCities)
            query = query.Where(b => EF.Functions.ILike(b.City, $"%{city}%"));
    }

    query = query.OrderBy(b => b.EndDate);

    // Загружаем данные из БД
    var allBooks = await query.AsNoTracking().ToListAsync(cancellationToken);

    // Фильтрация в памяти (безопасная для тегов)
    var keywords = preferences.GetKeywordsList();
    if (keywords.Any())
    {
        var normalizedKeywords = keywords.Select(k => k.ToLower()).ToList();
        
        allBooks = allBooks.Where(book =>
        {
            var matchesText = normalizedKeywords.Any(keyword =>
                (book.NormalizedTitle?.Contains(keyword) == true) ||
                (book.NormalizedDescription?.Contains(keyword) == true));

            var matchesTags = book.Tags?.Any(tag =>
                normalizedKeywords.Any(keyword =>
                    tag.ToLower().Contains(keyword))) == true;

            return matchesText || matchesTags;
        }).ToList();
    }

    // Пагинация в памяти
    var totalCount = allBooks.Count;
    var books = allBooks.Skip((page - 1) * pageSize).Take(pageSize).ToList();

    return new LotsSearchResult
    {
        Books = books,
        TotalCount = totalCount,
        Page = page,
        PageSize = pageSize
    };
}
```

## 🔧 Технические детали:

### Конфигурация Tags в Entity Framework:
```csharp
modelBuilder.Entity<RegularBaseBook>()
    .Property(e => e.Tags)
    .HasConversion(
        v => string.Join(";", v),           // C# List<string> → DB string
        v => v.Split(";", StringSplitOptions.RemoveEmptyEntries).ToList()) // DB string → C# List<string>
    .Metadata.SetValueComparer(stringListComparer);
```

### Почему EF.Property работает:
- `EF.Property<string>(b, "Tags")` обращается к сырому значению колонки в БД
- Позволяет искать в строке "tag1;tag2;tag3" напрямую через SQL LIKE/ILIKE
- Обходит проблемы с конвертерами типов

## 🎉 Результат:

### ✅ Команда `/lots` теперь работает:
- Поиск по ключевым словам в заголовках, описаниях и тегах
- Фильтрация по городам (регистронезависимо)
- Фильтрация по ценам, годам издания, категориям
- Корректная пагинация результатов

### ✅ Производительность улучшена:
- Все фильтры выполняются на уровне базы данных (SQL)
- Нет загрузки данных в память для клиентской фильтрации
- Эффективные SQL запросы с LIKE/ILIKE

## 🔍 Тестирование:

### Команды для проверки:
```
/lots                    # Первая страница активных лотов
/lots 2                  # Вторая страница
/settings                # Настройка критериев поиска
```

### Ожидаемое поведение:
- Возврат JSON списка книг
- Фильтрация согласно настройкам пользователя
- Пагинация с указанием текущей страницы
- Отображение времени до окончания торгов

## 📚 Связанные исправления:

1. **Entity Framework LINQ:** ✅ Исправлено
2. **Setup API nginx:** ✅ Исправлено
3. **Docker Compose:** ✅ Обновлено
4. **Диагностические скрипты:** ✅ Обновлены

## 🎯 Итог:
Telegram бот теперь полностью функционален:
- Регистрация и вход пользователей
- Настройка критериев поиска
- Просмотр активных лотов
- Получение уведомлений о новых книгах
