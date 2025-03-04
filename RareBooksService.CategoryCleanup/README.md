# Утилита очистки категорий RareBooksService

Эта консольная утилита предназначена для удаления нежелательных категорий (`unknown` и `interested`) и связанных с ними книг из базы данных RareBooksService.

## Назначение

Утилита автоматически находит и удаляет все категории с названиями "unknown" и "interested", а также все книги, которые относятся к этим категориям. Это помогает поддерживать базу данных в чистом состоянии.

## Использование

1. Убедитесь, что настроены корректные строки подключения в файле `appsettings.json`.
2. Запустите утилиту из командной строки:

```
dotnet RareBooksService.CategoryCleanup.dll
```

## Настройка

Настройка выполняется через файл `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "BooksConnection": "Server=YourServer;Database=RareBooksDB;Trusted_Connection=True;MultipleActiveResultSets=true",
    "UsersConnection": "Server=YourServer;Database=RareBooksUsers;Trusted_Connection=True;MultipleActiveResultSets=true"
  }
}
```

## Логирование

Утилита использует NLog для логирования. Все логи сохраняются в папке `logs` относительно директории приложения:

- `all-{дата}.log` - все логи
- `error-{дата}.log` - только ошибки
- `category-cleanup-{дата}.log` - логи, специфичные для процесса очистки категорий

## Планирование запуска

Утилиту можно запускать по расписанию с помощью планировщика задач Windows или cron в Linux:

### Windows Task Scheduler

1. Откройте планировщик задач Windows
2. Создайте новую задачу
3. Укажите путь к утилите как действие
4. Настройте расписание (например, раз в неделю)

### Linux Cron

Пример cron выражения для запуска каждую неделю в воскресенье в 2 часа ночи:

```
0 2 * * 0 /path/to/dotnet /path/to/RareBooksService.CategoryCleanup.dll
```

## Безопасность

Утилита должна быть запущена с правами доступа к базе данных и файловой системе для записи логов.

## Разработка и поддержка

При необходимости изменения списка категорий для удаления, требуется обновить константу `unwantedCategories` в методе `DeleteUnwantedCategoriesAsync()` класса `CategoryCleanupService`.

```csharp
string[] unwantedCategories = { "unknown", "interested" }; // Добавьте дополнительные категории при необходимости
``` 