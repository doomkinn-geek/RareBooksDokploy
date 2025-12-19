# Backend - Поддержка изображений

## Обновления бэкенда для Депеша

### 🎉 Добавлена поддержка изображений

**Дата:** 19 декабря 2025  
**Версия:** 1.1.0

## Изменения

### 1. Обновлен MessageType Enum

**Файл:** `src/MayMessenger.Domain/Enums/MessageType.cs`

```csharp
public enum MessageType
{
    Text = 0,
    Audio = 1,
    Image = 2  // ← НОВОЕ
}
```

### 2. Добавлен новый endpoint для отправки изображений

**Файл:** `src/MayMessenger.API/Controllers/MessagesController.cs`

#### Новый метод: `SendImageMessage`

```csharp
[HttpPost("image")]
public async Task<ActionResult<MessageDto>> SendImageMessage(
    [FromForm] Guid chatId, 
    IFormFile imageFile)
{
    // Валидация:
    // - Формат: jpg, jpeg, png, gif, webp
    // - Размер: максимум 10MB
    
    // Сохранение: /wwwroot/images/{guid}.ext
    // Возврат: MessageDto с Type = Image, FilePath = /images/...
}
```

**Особенности:**
- ✅ Валидация формата файла
- ✅ Ограничение размера (10MB)
- ✅ Уникальные имена файлов (GUID)
- ✅ SignalR уведомления
- ✅ Push-уведомления с текстом "📷 Изображение"

### 3. Обновлены push-уведомления

**Файл:** `src/MayMessenger.API/Controllers/MessagesController.cs`

#### Метод: `SendPushNotificationsAsync`

```csharp
var body = message.Type switch
{
    MessageType.Text => message.Content?.Substring(0, 100) + "...",
    MessageType.Audio => "🎤 Аудио сообщение",
    MessageType.Image => "📷 Изображение",  // ← НОВОЕ
    _ => "Новое сообщение"
};
```

## Структура файлов на сервере

```
wwwroot/
├── audio/          # Аудио сообщения
│   └── {guid}.m4a
└── images/         # Изображения (НОВОЕ)
    └── {guid}.jpg/png/gif/webp
```

## API Endpoints

### Отправка изображения

```http
POST /api/messages/image
Content-Type: multipart/form-data
Authorization: Bearer {token}

Form Data:
  chatId: {guid}
  imageFile: {file}
```

**Ответ:**
```json
{
  "id": "...",
  "chatId": "...",
  "senderId": "...",
  "senderName": "...",
  "type": 2,
  "content": null,
  "filePath": "/images/{guid}.jpg",
  "status": 1,
  "createdAt": "2025-12-19T..."
}
```

### Получение изображения

```http
GET https://messenger.rare-books.ru/images/{guid}.jpg
```

## Миграции БД

**НЕ ТРЕБУЮТСЯ** - MessageType хранится как INT, просто добавлено новое значение.

## Требования к серверу

### Создать папку для изображений

```bash
# Linux/Ubuntu
mkdir -p /app/wwwroot/images
chmod 755 /app/wwwroot/images

# Windows
mkdir C:\path\to\app\wwwroot\images
```

### Настройка Nginx (если используется)

```nginx
location /images/ {
    alias /app/wwwroot/images/;
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

## Тестирование

### cURL тест

```bash
curl -X POST https://messenger.rare-books.ru/api/messages/image \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "chatId=YOUR_CHAT_ID" \
  -F "imageFile=@/path/to/image.jpg"
```

### Postman тест

1. Method: POST
2. URL: `https://messenger.rare-books.ru/api/messages/image`
3. Authorization: Bearer Token
4. Body: form-data
   - Key: `chatId`, Value: `{guid}`
   - Key: `imageFile`, Type: File

## Обратная совместимость

✅ **Полная обратная совместимость**

- Старые клиенты продолжат работать (Text + Audio)
- Новые клиенты получат поддержку Image
- Существующие сообщения не затронуты

## Размер и ограничения

| Параметр | Значение |
|----------|----------|
| Максимальный размер | 10 MB |
| Форматы | jpg, jpeg, png, gif, webp |
| Хранение | Локальная файловая система |
| Срок хранения | Бессрочно |

## Мониторинг

### Логи

```csharp
_logger.LogInformation("Image uploaded: {FileName}, Size: {Size}", fileName, imageFile.Length);
```

### Проверка дискового пространства

```bash
# Linux
du -sh /app/wwwroot/images/

# Windows
dir C:\path\to\app\wwwroot\images /s
```

## Безопасность

### Реализованные проверки:

- ✅ Аутентификация (Bearer token)
- ✅ Валидация формата файла
- ✅ Ограничение размера файла
- ✅ Уникальные имена (GUID)
- ✅ Проверка доступа к чату

### Рекомендации:

- 🔒 Проверка содержимого файла (не только расширения)
- 🔒 Антивирусное сканирование (опционально)
- 🔒 Сжатие изображений (опционально)

## Будущие улучшения

- [ ] Автоматическое сжатие больших изображений
- [ ] Генерация thumbnail для превью
- [ ] Поддержка видео (MessageType.Video)
- [ ] Хранение в облаке (S3, Azure Blob)
- [ ] Удаление старых неиспользуемых файлов

## Совместимость с React Native клиентом

✅ **Полностью совместимо с "Депеша"**

React Native клиент уже имеет:
- `ImagePickerButton` компонент
- `react-native-image-picker` пакет
- `FastImage` для отображения
- API метод для отправки

## Deployment

### Обновление production сервера

```bash
# 1. Остановить приложение
sudo systemctl stop maymessenger

# 2. Обновить код (git pull или копирование)
cd /app/MayMessenger
git pull origin main

# 3. Пересобрать
dotnet build -c Release

# 4. Создать папку для изображений
mkdir -p /app/wwwroot/images
chmod 755 /app/wwwroot/images

# 5. Запустить приложение
sudo systemctl start maymessenger

# 6. Проверить логи
sudo journalctl -u maymessenger -f
```

### Docker

Если используется Docker, добавить volume:

```yaml
volumes:
  - ./wwwroot/images:/app/wwwroot/images
```

## Статус

✅ **Готово к использованию**

- Код написан и протестирован
- Документация создана
- Обратная совместимость гарантирована
- Готов к deployment

---

**Автор:** AI Assistant  
**Дата:** 19 декабря 2025  
**Проект:** Депеша (May Messenger)

