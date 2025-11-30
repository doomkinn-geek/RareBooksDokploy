# ✅ ПАРСЕР XLSX → JSON + ИМПОРТ НА СЕРВЕРЕ

Дата: 30 ноября 2025

---

## 🎯 Реализовано

1. **Парсер XLSX → JSON** - Консольная утилита для конвертации
2. **Backend API импорта** - Сервис и контроллер
3. **Frontend интерфейс** - Компонент для загрузки JSON
4. **Полная документация** - Инструкции по использованию

---

## 📦 Архитектура решения

```
┌─────────────────┐
│  XLSX файл      │
│  (коллекция)    │
└────────┬────────┘
         │
         │ RareBooksImporter (локально)
         ▼
┌─────────────────┐
│  JSON файл      │
│  (data export)  │
└────────┬────────┘
         │
         │ Загрузка через веб-интерфейс
         ▼
┌─────────────────┐
│  Web Frontend   │
│  (браузер)      │
└────────┬────────┘
         │
         │ POST /api/usercollection/import
         ▼
┌─────────────────┐
│  Backend API    │
│  (сервер)       │
└────────┬────────┘
         │
         │ Сохранение в БД
         ▼
┌─────────────────┐
│  PostgreSQL     │
│  (база данных)  │
└─────────────────┘
```

---

## 🔧 Компоненты решения

### 1. RareBooksImporter (Парсер)

**Файл:** `RareBooksImporter/Program.cs`

**Функции:**
- Чтение XLSX файлов
- Парсинг данных книг
- Экспорт в JSON формат

**Использование:**

```bash
cd c:\rarebooks\RareBooksImporter

# Сборка
dotnet build

# Конвертация
dotnet run "C:\path\to\books.xlsx" "output.json"

# Или авто-имя выходного файла
dotnet run "C:\path\to\books.xlsx"
# Создаст: books.json
```

**Формат JSON output:**

```json
{
  "exportDate": "2025-11-30T12:00:00Z",
  "totalBooks": 20,
  "books": [
    {
      "title": "Захарьин (Якунин). Тени прошлого",
      "author": "Захарьин (Якунин)",
      "yearPublished": 1885,
      "purchasePrice": 1900,
      "purchaseDate": "2016-01-07T00:00:00Z",
      "isSold": false,
      "notes": "Первая книга из коллекции..."
    },
    // ... остальные книги
  ]
}
```

### 2. Backend API

**Новые файлы:**

1. **`ImportCollectionDto.cs`** - DTO модели
   ```csharp
   public class ImportCollectionRequest
   {
       public DateTime ExportDate { get; set; }
       public int TotalBooks { get; set; }
       public List<ImportBookData> Books { get; set; }
   }
   
   public class ImportCollectionResponse
   {
       public bool Success { get; set; }
       public int ImportedBooks { get; set; }
       public int SkippedBooks { get; set; }
       public List<string> Errors { get; set; }
       public string Message { get; set; }
   }
   ```

2. **`CollectionExportService.cs`** - Добавлен метод
   ```csharp
   Task<ImportCollectionResponse> ImportFromJsonAsync(
       ImportCollectionRequest request, 
       string userId
   );
   ```

3. **`UserCollectionController.cs`** - Новый endpoint
   ```csharp
   [HttpPost("import")]
   public async Task<ActionResult<ImportCollectionResponse>> ImportFromJson(
       [FromBody] ImportCollectionRequest request
   )
   ```

**API Endpoint:**

```
POST /api/usercollection/import
Content-Type: application/json
Authorization: Bearer {token}

Body: {JSON содержимое из парсера}

Response: {
  "success": true,
  "importedBooks": 18,
  "skippedBooks": 2,
  "errors": [],
  "message": "Импортировано книг: 18. Пропущено: 2"
}
```

### 3. Frontend

**Новые файлы:**

1. **`ImportCollection.jsx`** - Компонент импорта
   - Выбор JSON файла
   - Загрузка на сервер
   - Отображение результатов
   - Обработка ошибок

2. **`UserCollection.jsx`** - Обновлен
   - Добавлена кнопка "Импортировать"
   - Диалог с формой импорта
   - Автообновление после импорта

**Интерфейс:**

```
┌─────────────────────────────────────┐
│  Моя коллекция редких книг          │
│                                     │
│  [Добавить] [Импортировать] [PDF]  │
│                                     │
│  ┌───────────────────────────────┐ │
│  │  📚 Книга 1                   │ │
│  │  📚 Книга 2                   │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘

При клике на "Импортировать":

┌─────────────────────────────────────┐
│  Импорт коллекции                   │
│                                     │
│  [Выбрать JSON файл]                │
│                                     │
│  Выбран: collection.json            │
│  Размер: 24.5 KB                    │
│                                     │
│  [Импортировать коллекцию]          │
│                                     │
│  Инструкция:                        │
│  1. Используйте RareBooksImporter   │
│  2. dotnet run books.xlsx out.json  │
│  3. Загрузите JSON файл             │
└─────────────────────────────────────┘
```

---

## 🚀 Полная инструкция использования

### Шаг 1: Подготовка XLSX файла

Убедитесь что XLSX файл имеет правильную структуру:

```
| A           | B                 | C    | D      | E        | F       | ... | J         | K           |
|-------------|-------------------|------|--------|----------|---------|-----|-----------|-------------|
| Дата покупки| Название, Автор   | Год  | Цена   | Доставка | Продано | ... | О продаже | Комментарий |
| СУММА       | ...               | ...  | ...    | ...      | ...     | ... | ...       | ...         |
| 7-1-2016    | Захарьин. Тени... | 1885 | 1900   | 0        |         | ... |           | Первая...   |
```

### Шаг 2: Конвертация в JSON

```bash
cd c:\rarebooks\RareBooksImporter
dotnet run "C:\Users\YourName\Documents\books.xlsx"
```

**Вывод:**

```
=== Конвертер коллекции книг XLSX → JSON ===

Входной файл:  C:\Users\YourName\Documents\books.xlsx
Выходной файл: C:\Users\YourName\Documents\books.json

Найдено строк: 20

Строка 3: ✅ Захарьин (Якунин). Тени прошлого
Строка 4: ✅ История современной Европы. 2тт.
...

Обработано: 18
Пропущено: 2

✅ Конвертация успешно завершена!
📄 Создан файл: C:\Users\YourName\Documents\books.json
📚 Книг в коллекции: 18
```

### Шаг 3: Импорт через веб-интерфейс

1. **Откройте браузер** → Перейдите на сайт
2. **Авторизуйтесь** → Войдите в систему
3. **Моя коллекция** → Перейдите в раздел коллекции
4. **Импортировать** → Нажмите кнопку
5. **Выбрать файл** → Загрузите `books.json`
6. **Импортировать** → Подтвердите импорт

**Результат:**

```
✅ Импортировано книг: 18. Пропущено: 2

Ошибки:
- Пропущена книга без названия
- Ошибка при импорте '...': ...
```

### Шаг 4: Проверка

- Обновится список книг
- Обновится статистика
- Все книги будут в коллекции

---

## 📊 Примеры данных

### Входные данные (XLSX)

```
A           | B                                    | C    | D      | E     | ...
7-1-2016    | Захарьин (Якунин). Тени прошлого     | 1885 | 1900   | 0     | ...
12-2-2016   | Книга IV. Попея Сабина и Октавия     | 1913 | 150    | 100   | ...
```

### JSON после парсера

```json
{
  "exportDate": "2025-11-30T15:30:00Z",
  "totalBooks": 2,
  "books": [
    {
      "title": "Захарьин (Якунин). Тени прошлого",
      "author": "Захарьин (Якунин)",
      "yearPublished": 1885,
      "totalPurchasePrice": 1900.00,
      "purchaseDate": "2016-01-07T00:00:00Z",
      "isSold": false
    },
    {
      "title": "Книга IV. Попея Сабина и Октавия",
      "yearPublished": 1913,
      "totalPurchasePrice": 250.00,
      "purchaseDate": "2016-12-02T00:00:00Z",
      "isSold": true,
      "soldPrice": 1.00,
      "soldDate": "2017-09-09T00:00:00Z"
    }
  ]
}
```

### Данные в БД

```sql
SELECT "Title", "Author", "PurchasePrice", "IsSold", "SoldPrice"
FROM "UserCollectionBooks";

-- Результат:
Title                              | Author            | PurchasePrice | IsSold | SoldPrice
-----------------------------------|-------------------|---------------|--------|----------
Тени прошлого                      | Захарьин (Якунин) | 1900.00       | false  | NULL
Книга IV. Попея Сабина и Октавия  | NULL              | 250.00        | true   | 1.00
```

---

## ⚙️ Технические детали

### Безопасность

1. **Аутентификация** - Требуется JWT токен
2. **Авторизация** - Проверка `[RequiresCollectionAccess]`
3. **Валидация** - Проверка обязательных полей
4. **Транзакции** - Каждая книга сохраняется отдельно

### Обработка ошибок

```csharp
try
{
    // Импорт книги
    var book = new UserCollectionBook { ... };
    await _usersContext.SaveChangesAsync();
    response.ImportedBooks++;
}
catch (Exception ex)
{
    _logger.LogWarning(ex, "Ошибка при импорте книги: {Title}", bookData.Title);
    response.Errors.Add($"Ошибка при импорте '{bookData.Title}': {ex.Message}");
    response.SkippedBooks++;
}
```

### DateTime обработка

Все даты конвертируются в UTC:

```csharp
PurchaseDate = request.PurchaseDate.HasValue 
    ? DateTime.SpecifyKind(request.PurchaseDate.Value, DateTimeKind.Utc) 
    : null
```

### Логирование

```
INFO: Начало импорта коллекции для пользователя {UserId}. Книг в файле: 20
DEBUG: Импортирована книга: Тени прошлого
DEBUG: Импортирована книга: История современной Европы
WARN: Ошибка при импорте книги: ...
INFO: Импорт завершен. Импортировано: 18, Пропущено: 2
```

---

## 🎯 Преимущества решения

✅ **Безопасность** - Не требуется прямой доступ к БД  
✅ **Удобство** - Импорт через веб-интерфейс  
✅ **Контроль** - Видно результат импорта  
✅ **Гибкость** - JSON можно редактировать вручную  
✅ **Портативность** - JSON файл можно перенести на любой сервер  
✅ **Отказоустойчивость** - Ошибка одной книги не прерывает импорт  

---

## 📝 Важные замечания

1. **Парсер локальный** - Запускается на компьютере пользователя
2. **JSON промежуточный** - Можно проверить/отредактировать
3. **Импорт через API** - Безопасно и контролируемо
4. **Авторизация обязательна** - Требуется активная подписка с доступом к коллекции
5. **Пакетный импорт** - Все книги импортируются за один запрос

---

## ✨ Готово!

**Теперь вы можете:**
1. ✅ Конвертировать XLSX в JSON локально
2. ✅ Импортировать JSON через веб-интерфейс
3. ✅ Видеть результаты импорта
4. ✅ Работать с коллекцией на сайте

**Решение готово к использованию! 🎉**

