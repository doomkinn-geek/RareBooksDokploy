# Инструкции по применению миграций

## ✅ Автоматическое применение миграций настроено!

Миграции **автоматически применяются** при запуске API (файл `Program.cs`, строки 190-201).

### Как это работает:

1. При запуске API проверяется подключение к БД
2. Проверяются отложенные (pending) миграции
3. Если есть отложенные миграции - они применяются автоматически
4. Логи показывают какие миграции были применены

### Что было изменено:

✅ Добавлено поле `PlayedAt` в entity `Message` (уже существовало)
✅ Создана миграция `20251221000000_AddPlayedAtToMessages.cs`
✅ Обновлён `AppDbContextModelSnapshot.cs` с полем `PlayedAt`

### Для применения на production сервере:

**Вариант 1: Просто перезапустить API (рекомендуется)**
```bash
# Скачать последний код
cd /path/to/_may_messenger_backend
git pull

# Пересобрать приложение
cd src/MayMessenger.API
dotnet build -c Release

# Перезапустить (миграции применятся автоматически)
sudo systemctl restart maymessenger
# или
pm2 restart maymessenger

# Проверить логи
sudo journalctl -u maymessenger -f
# или
pm2 logs maymessenger
```

**Вариант 2: Применить миграцию вручную перед запуском**
```bash
cd /path/to/_may_messenger_backend/src/MayMessenger.API
dotnet ef database update --project ../MayMessenger.Infrastructure
```

**Вариант 3: Применить SQL напрямую (если EF не работает)**
```sql
psql -U postgres -d maymessenger

ALTER TABLE "Messages" ADD COLUMN IF NOT EXISTS "PlayedAt" timestamp without time zone NULL;

CREATE INDEX IF NOT EXISTS "IX_Messages_PlayedAt" 
ON "Messages" ("PlayedAt") 
WHERE "PlayedAt" IS NOT NULL;

\d "Messages"  -- проверка
```

## Проверка после применения:

1. Проверьте health endpoint: https://messenger.rare-books.ru/health/ready
2. Проверьте логи на наличие сообщения "Database migrations applied successfully"
3. Приложение должно успешно загружать чаты без ошибки 500

## Созданные файлы:

- ✅ `20251221000000_AddPlayedAtToMessages.cs` - миграция
- ✅ `AppDbContextModelSnapshot.cs` - обновлён
- ✅ `Program.cs` - автоматическое применение миграций (уже было)

## Что было исправлено в мобильном приложении:

- ✅ Название изменено на "Депеша"
- ✅ Добавлены разрешения для камеры и галереи
- ✅ Запрос всех необходимых разрешений сразу при работе с изображениями


