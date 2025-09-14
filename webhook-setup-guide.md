# Настройка Webhook для Telegram бота

## Проблема
Telegram бот получает сообщения от пользователей, но backend не отвечает. Это происходит потому, что **webhook не настроен** - Telegram не знает, куда отправлять обновления.

## Ваши данные
- **Telegram ID**: 494443219
- **Username**: @doomkinn
- **Имя**: Vasiliy Kochergin
- **Язык**: ru

## План решения

### Шаг 1: Запустить основной сервер
```bash
cd RareBooksService.WebApi
dotnet run
```
Сервер должен запуститься на порту 5000 (или другом).

### Шаг 2: Сделать сервер доступным извне

#### Вариант A: Использовать ngrok (рекомендуется для разработки)
1. Установить ngrok: https://ngrok.com/
2. В новом терминале:
```bash
ngrok http 5000
```
3. Скопировать HTTPS URL (например: `https://abc123.ngrok.io`)

#### Вариант B: Публичный сервер
Если у вас есть публичный домен с HTTPS, используйте его.

### Шаг 3: Настроить webhook

#### Через тестовое приложение:
```bash
cd TelegramBotTest
dotnet run
# Выбрать "5. 🔧 Настроить webhook"
# Выбрать "2. Настроить webhook с ngrok"
# Ввести URL от ngrok
```

#### Через API напрямую:
```bash
curl -X POST "https://api.telegram.org/bot7745135732:AAFp2cJs8boBZZDyb1myO1kcmjwk6K3Mi7U/setWebhook" \
-H "Content-Type: application/json" \
-d '{
  "url": "https://your-ngrok-url.ngrok.io/api/telegram/webhook",
  "allowed_updates": ["message", "callback_query"]
}'
```

### Шаг 4: Проверить работу
1. Написать боту команду `/start`
2. Проверить логи сервера RareBooksService.WebApi
3. Должны появиться записи о входящих webhook запросах

## Диагностика проблем

### Проверить текущий webhook:
```bash
curl "https://api.telegram.org/bot7745135732:AAFp2cJs8boBZZDyb1myO1kcmjwk6K3Mi7U/getWebhookInfo"
```

### Типичные ошибки:

#### ❌ "Wrong response from the webhook"
- URL недоступен извне
- Сервер не запущен
- Неправильный endpoint

#### ❌ "SSL error"
- Используйте HTTPS (ngrok автоматически предоставляет HTTPS)
- Проверьте SSL сертификат

#### ❌ "Connection timeout"
- Сервер не отвечает
- Firewall блокирует соединение

### Логи для проверки:

В RareBooksService.WebApi должны появляться логи:
```
[INFO] Получено обновление от Telegram: 123456789
[INFO] Обрабатывается сообщение: /start от пользователя 494443219
```

## Быстрый тест

1. Запустите тестовое приложение:
```bash
cd TelegramBotTest
dotnet run
```

2. Выберите "5. 🔧 Настроить webhook" → "1. Удалить webhook"

3. Выберите "6. 🧪 Протестировать webhook соединение"
   - Введите URL: `http://localhost:5000/api/telegram/webhook`
   - Если сервер запущен, должен ответить

## Альтернативный подход (без webhook)

Если webhook настроить сложно, можно использовать **polling** (getUpdates), но это требует изменения кода backend'а для активного запроса обновлений у Telegram.

## Следующие шаги после настройки

1. ✅ Webhook настроен и работает
2. 🔧 Проверить базу данных (создание пользователей, состояния)
3. 🧪 Протестировать команды: `/start`, `/help`, `/settings`
4. 🐛 Исправить ошибки в TelegramBotService
5. ✨ Протестировать полный цикл создания уведомлений
