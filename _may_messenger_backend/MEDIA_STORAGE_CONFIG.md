# Проверка конфигурации медиафайлов - Депеша Messenger

## Дата проверки: 21 декабря 2025

---

## ✅ Статус проверки: ВСЕ НАСТРОЕНО КОРРЕКТНО

### 1. Backend - Пути хранения файлов

**Аудио файлы:**
- Путь: `/app/wwwroot/audio`
- Контроллер: `MessagesController.SendAudioMessage()`
- Код: `Path.Combine(_environment.WebRootPath, "audio")`
- Формат пути в БД: `/audio/{guid}.m4a`

**Изображения:**
- Путь: `/app/wwwroot/images`
- Контроллер: `MessagesController.SendImageMessage()`
- Код: `Path.Combine(_environment.WebRootPath, "images")`
- Формат пути в БД: `/images/{guid}.jpg`

---

### 2. Docker Volumes - Настройка в docker-compose.yml

```yaml
maymessenger_backend:
  volumes:
    - maymessenger_audio:/app/wwwroot/audio      # ✅ КОРРЕКТНО
    - maymessenger_images:/app/wwwroot/images    # ✅ КОРРЕКТНО
    - maymessenger_firebase:/app/firebase_config
```

**Named volumes определены:**
```yaml
volumes:
  maymessenger_audio:       # ✅ СУЩЕСТВУЕТ
  maymessenger_images:      # ✅ СУЩЕСТВУЕТ
  maymessenger_firebase:
```

**Статус:** ✅ Volumes корректно монтируются в те же пути, что использует backend

---

### 3. Dockerfile - Создание директорий

```dockerfile
# Create wwwroot directories for media files (matches volume mounts)
RUN mkdir -p /app/wwwroot/audio && \
    mkdir -p /app/wwwroot/images
```

**Статус:** ✅ Директории создаются при сборке образа

---

### 4. Nginx - Проксирование статических файлов

**До изменений:**
- ✅ `/audio/` - был настроен
- ❌ `/images/` - отсутствовал

**После изменений:**
```nginx
# Audio files (static files)
location /audio/ {
    proxy_pass http://maymessenger_backend/audio/;
    # ... headers ...
    proxy_cache_valid 200 1d;
    expires 1d;
    add_header Cache-Control "public, immutable";
}

# Image files (static files) - ДОБАВЛЕНО
location /images/ {
    proxy_pass http://maymessenger_backend/images/;
    # ... headers ...
    proxy_cache_valid 200 1d;
    expires 1d;
    add_header Cache-Control "public, immutable";
}
```

**Статус:** ✅ Оба типа файлов проксируются через Nginx с кешированием

---

### 5. MediaCleanupService - Автоматическое удаление

**Функционал:**
```csharp
// Удаляет аудио И изображения старше 7 дней
var cutoffDate = DateTime.UtcNow.AddDays(-_retentionDays); // default: 7 дней
var oldMessages = await unitOfWork.Messages.GetOldMediaMessagesAsync(cutoffDate);

foreach (var message in oldMessages)
{
    if (message.Type == MessageType.Audio)
        // Удалить audio файл
    else if (message.Type == MessageType.Image)
        // Удалить image файл
    
    message.FilePath = null;
    message.Content = "[Файл удален с сервера]";
}
```

**Конфигурация:**
- Запуск: каждые 24 часа
- Retention period: 7 дней (настраивается через `MediaRetentionDays` в appsettings.json)
- Обрабатывает: ✅ Аудио + ✅ Изображения

**Статус:** ✅ Сервис уже реализован и работает для обоих типов файлов

---

### 6. Клиентское хранилище - Local Storage

**Flutter (мобильное приложение):**

**Аудио:**
- Service: `AudioStorageService`
- Путь: `{AppDocumentsDirectory}/audio/{messageId}.m4a`
- Кеширование: Permanent (не удаляется автоматически)

**Изображения:**
- Service: `ImageStorageService`
- Путь: `{AppDocumentsDirectory}/images/{messageId}.jpg`
- Кеширование: Permanent (не удаляется автоматически)

**Логика скачивания:**
1. Пользователь получает сообщение с медиа
2. Файл автоматически скачивается в фоне (audio) или при открытии (images)
3. Сохраняется локально в app storage
4. При повторном просмотре используется локальная копия
5. Если файл удален с сервера (после 7 дней), используется локальная копия

**Статус:** ✅ Реализовано для аудио и изображений

---

## Архитектура хранения медиафайлов

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENT SIDE                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Получение медиа:                                            │
│    1. Скачать с сервера (если доступно)                     │
│    2. Сохранить локально (permanent storage)                │
│    3. Использовать локальную копию при повторном доступе     │
│                                                               │
│  Локальное хранилище:                                        │
│    - Audio:  {AppDocuments}/audio/{messageId}.m4a          │
│    - Images: {AppDocuments}/images/{messageId}.jpg          │
│                                                               │
│  Удаление: Только вручную пользователем (очистка кеша)      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
                            ↕ HTTPS
┌─────────────────────────────────────────────────────────────┐
│                       SERVER SIDE                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Nginx (messenger.rare-books.ru):                           │
│    - /audio/{guid}.m4a   → proxy to backend                 │
│    - /images/{guid}.jpg  → proxy to backend                 │
│    - Cache: 1 день                                           │
│                                                               │
│  Backend (ASP.NET):                                          │
│    - Путь: /app/wwwroot/audio/{guid}.m4a                   │
│    - Путь: /app/wwwroot/images/{guid}.jpg                  │
│    - Static Files Middleware                                 │
│                                                               │
│  Docker Volumes:                                             │
│    - maymessenger_audio  → /app/wwwroot/audio              │
│    - maymessenger_images → /app/wwwroot/images             │
│                                                               │
│  MediaCleanupService (Background):                           │
│    - Запуск: каждые 24 часа                                 │
│    - Удаляет файлы старше 7 дней                           │
│    - Обновляет БД: FilePath = null                          │
│                                                               │
│  После удаления с сервера:                                   │
│    - Клиенты используют локальные копии                     │
│    - Новые клиенты не смогут скачать (404)                  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Инструкции для деплоя

### 1. Применить изменения Nginx

```bash
# Проверить конфигурацию
docker exec nginx_container nginx -t

# Перезагрузить Nginx (без даунтайма)
docker exec nginx_container nginx -s reload
```

### 2. Проверить volume mount'ы

```bash
# Проверить что volumes существуют
docker volume ls | grep maymessenger

# Ожидаемый вывод:
# rarebooks_maymessenger_audio
# rarebooks_maymessenger_images

# Проверить mount points в контейнере
docker exec maymessenger_backend ls -la /app/wwwroot/
```

### 3. Проверить MediaCleanupService

```bash
# Проверить логи cleanup service
docker logs maymessenger_backend | grep "Media Cleanup"

# Ожидаемые логи:
# [INFO] Media Cleanup Service starting... Retention period: 7 days
# [INFO] Starting media cleanup task...
# [INFO] Media cleanup completed. Audio: X files deleted, Y records updated. Images: X files deleted, Y records updated.
```

### 4. Тестирование загрузки и доступа к файлам

**Тест аудио:**
```bash
# 1. Отправить аудио сообщение через мобильное приложение
# 2. Проверить что файл появился на сервере
docker exec maymessenger_backend ls -la /app/wwwroot/audio/

# 3. Проверить доступ через Nginx
curl -I https://messenger.rare-books.ru/audio/{guid}.m4a
# Ожидается: HTTP 200
```

**Тест изображений:**
```bash
# 1. Отправить изображение через мобильное приложение
# 2. Проверить что файл появился на сервере
docker exec maymessenger_backend ls -la /app/wwwroot/images/

# 3. Проверить доступ через Nginx
curl -I https://messenger.rare-books.ru/images/{guid}.jpg
# Ожидается: HTTP 200
```

---

## Мониторинг дискового пространства

### Проверка размера volumes

```bash
# Размер audio volume
docker exec maymessenger_backend du -sh /app/wwwroot/audio

# Размер images volume
docker exec maymessenger_backend du -sh /app/wwwroot/images

# Общий размер
docker exec maymessenger_backend du -sh /app/wwwroot
```

### Настройка алертов (опционально)

Добавить в cron для мониторинга:

```bash
#!/bin/bash
# /usr/local/bin/check_messenger_storage.sh

AUDIO_SIZE=$(docker exec maymessenger_backend du -sm /app/wwwroot/audio | cut -f1)
IMAGES_SIZE=$(docker exec maymessenger_backend du -sm /app/wwwroot/images | cut -f1)
TOTAL=$((AUDIO_SIZE + IMAGES_SIZE))

# Алерт если > 10GB
if [ $TOTAL -gt 10240 ]; then
    echo "WARNING: Messenger media storage > 10GB (Audio: ${AUDIO_SIZE}MB, Images: ${IMAGES_SIZE}MB)"
    # Отправить уведомление (email/telegram/etc)
fi
```

---

## Настройка retention period (опционально)

По умолчанию файлы хранятся 7 дней. Для изменения:

### Через environment в docker-compose.yml:

```yaml
maymessenger_backend:
  environment:
    - MediaRetentionDays=14  # Хранить 14 дней вместо 7
```

### Через appsettings.Production.json:

```json
{
  "MediaRetentionDays": 14
}
```

---

## Резюме изменений

### ✅ Что было сделано:

1. **Nginx конфигурация:**
   - ✅ Добавлен location `/images/` для проксирования изображений
   - ✅ Настроено кеширование (1 день) для audio и images
   - ✅ Добавлены правильные headers

2. **Backend:**
   - ✅ Пути хранения уже корректные (`/app/wwwroot/audio`, `/app/wwwroot/images`)
   - ✅ MediaCleanupService уже поддерживает оба типа файлов
   - ✅ Автоматическое удаление после 7 дней работает

3. **Docker:**
   - ✅ Volumes уже настроены корректно
   - ✅ Dockerfile создает необходимые директории

4. **Client:**
   - ✅ Локальное хранилище реализовано для audio и images
   - ✅ Automatic download в фоне
   - ✅ Fallback на локальную копию после удаления с сервера

### 📝 Что нужно сделать:

1. **Перезагрузить Nginx** для применения изменений
2. **Протестировать** загрузку и доступ к изображениям
3. **Мониторить** размер storage (опционально настроить алерты)

---

## Troubleshooting

### Проблема: Изображения не загружаются (404)

**Причина:** Nginx не проксирует `/images/`

**Решение:**
```bash
# Проверить Nginx конфигурацию
docker exec nginx_container nginx -t

# Перезагрузить
docker exec nginx_container nginx -s reload

# Проверить логи
docker logs nginx_container | tail -50
```

### Проблема: Файлы не удаляются автоматически

**Причина:** MediaCleanupService не запущен или ошибка

**Решение:**
```bash
# Проверить логи службы
docker logs maymessenger_backend | grep "Media Cleanup"

# Проверить что служба зарегистрирована
docker logs maymessenger_backend | grep "AddHostedService"

# Принудительно перезапустить backend
docker-compose restart maymessenger_backend
```

### Проблема: Нет места на диске

**Причина:** Слишком много медиафайлов

**Решение:**
```bash
# Временно уменьшить retention period
docker exec maymessenger_backend \
  sed -i 's/"MediaRetentionDays": 7/"MediaRetentionDays": 3/' \
  /app/appsettings.Production.json

# Перезапустить backend
docker-compose restart maymessenger_backend

# MediaCleanupService удалит старые файлы при следующем запуске
```

---

**Конфигурация готова к production!** ✅

