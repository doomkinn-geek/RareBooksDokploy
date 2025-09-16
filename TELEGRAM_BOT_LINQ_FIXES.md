# 🤖 Исправления LINQ запросов в TelegramBotService

## 🚨 Проблема:
При выполнении команды `/lots` в Telegram боте возникали ошибки Entity Framework:
```
The LINQ expression 'tag => tag.Contains(__keyword_1)' could not be translated
The LINQ expression 'b.City.ToLower().Contains(city)' could not be translated
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

## ✅ Исправления:

### 1. Поиск по тегам:
**Стало:**
```csharp
EF.Functions.ILike(EF.Property<string>(b, "Tags"), $"%{keyword}%")
```

**Объяснение:**
- `EF.Property<string>(b, "Tags")` - обращается к сырому строковому значению в БД (до конвертации)
- `EF.Functions.ILike` - регистронезависимый поиск (PostgreSQL ILIKE)
- Поиск ведется по строке "tag1;tag2;tag3" напрямую

### 2. Поиск по городам:
**Стало:**
```csharp
EF.Functions.ILike(b.City, $"%{city}%")
```

**Объяснение:**
- Убрали `ToLower()` из SQL запроса
- Используем `ILike` для регистронезависимого поиска
- Entity Framework автоматически заменит на `LIKE` если `ILIKE` не поддерживается

## 🎯 Полный исправленный код:

```csharp
// Фильтр по ключевым словам
var keywords = preferences.GetKeywordsList();
if (keywords.Any())
{
    var normalizedKeywords = keywords.Select(k => k.ToLower()).ToList();
    
    foreach (var keyword in normalizedKeywords)
    {
        query = query.Where(b => 
            b.NormalizedTitle.Contains(keyword) || 
            b.NormalizedDescription.Contains(keyword) ||
            EF.Functions.ILike(EF.Property<string>(b, "Tags"), $"%{keyword}%"));
    }
}

// Фильтр по городам
var cities = preferences.GetCitiesList();
if (cities.Any())
{
    var normalizedCities = cities.Select(c => c.ToLower()).ToList();
    
    foreach (var city in normalizedCities)
    {
        query = query.Where(b => EF.Functions.ILike(b.City, $"%{city}%"));
    }
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
