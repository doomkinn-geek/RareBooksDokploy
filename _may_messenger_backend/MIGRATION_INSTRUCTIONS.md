# Инструкции по применению миграций

## ✅ Автоматическое применение миграций настроено!

Миграции **автоматически применяются** при запуске API (файл `Program.cs`, строки 190-201).

### Что было изменено:

✅ Добавлено поле `PlayedAt` в entity `Message`
✅ Создана миграция `20251221121642_AddPlayedAtToMessages.cs` через EF CLI
✅ Миграция добавляет колонку `PlayedAt` типа `timestamp with time zone`

### Миграция будет применена автоматически при следующем запуске API!

**Просто перезапустите API на production сервере:**

```bash
# 1. Обновите код
cd /path/to/_may_messenger_backend
git pull

# 2. Пересоберите приложение
cd src/MayMessenger.API
dotnet build -c Release

# 3. Перезапустите (миграция применится автоматически!)
sudo systemctl restart maymessenger
# или
pm2 restart maymessenger

# 4. Проверьте логи - вы должны увидеть:
sudo journalctl -u maymessenger -f
# или
pm2 logs maymessenger

# Ожидаемые логи:
# "Applying 1 pending database migrations..."
# "  - 20251221121642_AddPlayedAtToMessages"
# "Database migrations applied successfully"
```

### Альтернатива: Применить миграцию вручную (если нужно)

```bash
cd /path/to/_may_messenger_backend/src/MayMessenger.API
dotnet ef database update --project ../MayMessenger.Infrastructure
```

### Если EF не работает, выполните SQL напрямую:

```sql
psql -U postgres -d maymessenger

ALTER TABLE "Messages" ADD COLUMN IF NOT EXISTS "PlayedAt" timestamp with time zone NULL;

-- Проверка
\d "Messages"
```

## Проверка после применения:

1. ✅ https://messenger.rare-books.ru/health/ready возвращает `{"status":"Ready"}`
2. ✅ Приложение загружает чаты без ошибки 500
3. ✅ В логах есть "Database migrations applied successfully"
4. ✅ Колонка PlayedAt присутствует в таблице Messages

## Созданные файлы:

- ✅ `20251221121642_AddPlayedAtToMessages.cs` - миграция (создана через EF CLI)
- ✅ `20251221121642_AddPlayedAtToMessages.Designer.cs` - метаданные
- ✅ `AppDbContextModelSnapshot.cs` - обновлён автоматически

## Изменения в мобильном приложении:

- ✅ Название изменено на "Депеша"
- ✅ Добавлены разрешения для камеры и галереи
- ✅ Запрос всех необходимых разрешений при работе с изображениями
- ✅ Реализована отправка статуса "Воспроизведено" для аудио



