# 🐳 Docker - Обновления конфигурации для Депеша

## Дата обновления: 19 декабря 2025

---

## ✅ Что изменено

### 1. Docker Compose (`docker-compose.yml`)

#### Добавлен volume для изображений

**Было:**
```yaml
volumes:
  - maymessenger_audio:/app/wwwroot/audio
  - maymessenger_firebase:/app/firebase_config
```

**Стало:**
```yaml
volumes:
  - maymessenger_audio:/app/wwwroot/audio
  - maymessenger_images:/app/wwwroot/images      # ← НОВОЕ
  - maymessenger_firebase:/app/firebase_config
```

#### Добавлен volume в секцию volumes

**Было:**
```yaml
volumes:
  db_maymessenger_data:
  maymessenger_audio:
  maymessenger_firebase:
```

**Стало:**
```yaml
volumes:
  db_maymessenger_data:
  maymessenger_audio:
  maymessenger_images:    # ← НОВОЕ
  maymessenger_firebase:
```

---

### 2. Dockerfile (`_may_messenger_backend/Dockerfile`)

#### Создание директории для изображений

**Было:**
```dockerfile
# Create wwwroot/audio directory for audio files
RUN mkdir -p /app/wwwroot/audio
```

**Стало:**
```dockerfile
# Create wwwroot directories for media files
RUN mkdir -p /app/wwwroot/audio && \
    mkdir -p /app/wwwroot/images
```

---

## 🎯 Зачем эти изменения?

### Поддержка изображений в мессенджере

1. **Volume `maymessenger_images`:**
   - Постоянное хранилище для изображений
   - Файлы сохраняются при перезапуске контейнера
   - Файлы сохраняются при обновлении образа

2. **Директория `/app/wwwroot/images`:**
   - Endpoint `/api/messages/image` сохраняет файлы сюда
   - Nginx раздает файлы через `/images/...`

---

## 🚀 Применение изменений на сервере

### Вариант 1: Без остановки сервисов (рекомендуется)

```bash
# Подключиться к серверу
ssh root@ваш-сервер.ru

# Перейти в папку проекта
cd /root/RareBooksServicePublic

# Обновить код из Git (если используете)
git pull origin main

# Пересобрать только мессенджер
docker-compose build maymessenger_backend

# Пересоздать контейнер с новыми volumes
docker-compose up -d maymessenger_backend

# Проверить что volume создан
docker volume ls | grep maymessenger_images

# Проверить что папка существует
docker exec maymessenger_backend ls -la /app/wwwroot/images
```

**Время простоя:** ~30 секунд

---

### Вариант 2: Полная пересборка

```bash
ssh root@ваш-сервер.ru
cd /root/RareBooksServicePublic

# Остановить все сервисы
docker-compose down

# Обновить код
git pull origin main

# Пересобрать все образы
docker-compose build

# Запустить все сервисы
docker-compose up -d

# Проверить статус
docker-compose ps
```

**Время простоя:** ~5-10 минут

---

## 🔍 Проверка после обновления

### Шаг 1: Проверить volumes

```bash
docker volume ls | grep maymessenger
```

**Должно быть:**
```
local     maymessenger_audio
local     maymessenger_firebase
local     maymessenger_images     ← НОВОЕ
```

### Шаг 2: Проверить директории в контейнере

```bash
docker exec maymessenger_backend ls -la /app/wwwroot/
```

**Должно быть:**
```
drwxr-xr-x 2 root root 4096 Dec 19 12:00 audio
drwxr-xr-x 2 root root 4096 Dec 19 12:00 images    ← НОВОЕ
```

### Шаг 3: Проверить API endpoint

```bash
# Тестовая отправка изображения (требует авторизацию)
curl -X POST https://messenger.rare-books.ru/api/messages/image \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "chatId=YOUR_CHAT_ID" \
  -F "imageFile=@test.jpg"
```

**Должен вернуть:**
```json
{
  "id": "...",
  "type": 2,
  "filePath": "/images/guid.jpg",
  ...
}
```

### Шаг 4: Проверить доступность файла

```bash
# Получить filePath из ответа выше и проверить
curl -I https://messenger.rare-books.ru/images/guid.jpg
```

**Должен вернуть:**
```
HTTP/2 200
content-type: image/jpeg
```

---

## 📊 Мониторинг использования дисков

### Проверка размера volumes

```bash
# Размер audio volume
docker exec maymessenger_backend du -sh /app/wwwroot/audio

# Размер images volume
docker exec maymessenger_backend du -sh /app/wwwroot/images

# Общий размер
docker exec maymessenger_backend du -sh /app/wwwroot
```

### Количество файлов

```bash
# Количество аудио файлов
docker exec maymessenger_backend find /app/wwwroot/audio -type f | wc -l

# Количество изображений
docker exec maymessenger_backend find /app/wwwroot/images -type f | wc -l
```

---

## 🗑️ Автоочистка медиа

### MediaCleanupService

Сервис **автоматически** запускается каждые 24 часа и:
- Удаляет аудио старше 7 дней
- Удаляет изображения старше 7 дней
- Обновляет записи в БД

### Проверка работы сервиса

```bash
# Логи очистки
docker logs maymessenger_backend 2>&1 | grep "Media cleanup"

# Пример вывода:
# Media cleanup completed. Audio: 15 files deleted. Images: 23 files deleted.
```

### Изменить срок хранения

Файл: `docker-compose.yml`

```yaml
maymessenger_backend:
  environment:
    - MediaRetentionDays=14  # Изменить на 14 дней
```

Или через `appsettings.json`:

```json
{
  "MediaRetentionDays": 14
}
```

---

## 🔄 Миграция существующих данных

Если у вас уже есть сервер с аудио файлами:

```bash
# 1. Создать backup аудио
docker exec maymessenger_backend tar -czf /tmp/audio_backup.tar.gz /app/wwwroot/audio

# 2. Скопировать backup на хост
docker cp maymessenger_backend:/tmp/audio_backup.tar.gz /root/backups/

# 3. Применить обновления (см. выше)

# 4. Восстановить аудио (если нужно)
docker cp /root/backups/audio_backup.tar.gz maymessenger_backend:/tmp/
docker exec maymessenger_backend tar -xzf /tmp/audio_backup.tar.gz -C /
```

---

## 🔐 Права доступа

### Рекомендуемые права

```bash
# Установить правильные права
docker exec maymessenger_backend chmod 755 /app/wwwroot/audio
docker exec maymessenger_backend chmod 755 /app/wwwroot/images
docker exec maymessenger_backend chmod 644 /app/wwwroot/audio/*
docker exec maymessenger_backend chmod 644 /app/wwwroot/images/*
```

---

## 🌐 Nginx конфигурация

Проверьте что Nginx настроен для раздачи изображений:

**Файл:** `nginx/nginx_prod.conf`

Должна быть секция:

```nginx
# Статические файлы мессенджера
location ~ ^/(audio|images)/ {
    proxy_pass http://maymessenger_backend:5000;
    proxy_cache_valid 200 30d;
    add_header Cache-Control "public, immutable";
}
```

Если нет - добавьте и перезапустите Nginx:

```bash
docker restart nginx_container
```

---

## 📦 Backup стратегия

### Автоматический backup volumes

Создайте cron job:

```bash
# Открыть crontab
crontab -e

# Добавить строку (backup каждую ночь в 3:00)
0 3 * * * docker run --rm -v maymessenger_images:/data -v /root/backups:/backup alpine tar -czf /backup/maymessenger_images_$(date +\%Y\%m\%d).tar.gz -C /data .
0 3 * * * docker run --rm -v maymessenger_audio:/data -v /root/backups:/backup alpine tar -czf /backup/maymessenger_audio_$(date +\%Y\%m\%d).tar.gz -C /data .
```

### Восстановление из backup

```bash
# Восстановить images
docker run --rm -v maymessenger_images:/data -v /root/backups:/backup alpine tar -xzf /backup/maymessenger_images_20251219.tar.gz -C /data

# Восстановить audio
docker run --rm -v maymessenger_audio:/data -v /root/backups:/backup alpine tar -xzf /backup/maymessenger_audio_20251219.tar.gz -C /data
```

---

## ❓ Troubleshooting

### Volume не создается

**Решение:**
```bash
docker volume create maymessenger_images
docker-compose up -d maymessenger_backend
```

### Папка images пустая после обновления

**Решение:**
```bash
docker exec maymessenger_backend mkdir -p /app/wwwroot/images
docker exec maymessenger_backend chmod 755 /app/wwwroot/images
```

### Изображения не сохраняются

**Проверить:**
1. Volume примонтирован? → `docker inspect maymessenger_backend | grep images`
2. Папка существует? → `docker exec maymessenger_backend ls /app/wwwroot/images`
3. Права корректны? → `docker exec maymessenger_backend ls -la /app/wwwroot/images`

---

## 📋 Чеклист обновления

- [ ] Обновлен `docker-compose.yml` (добавлен volume для images)
- [ ] Обновлен `Dockerfile` (создание директории images)
- [ ] Изменения применены на сервере
- [ ] Volume `maymessenger_images` создан
- [ ] Директория `/app/wwwroot/images` существует
- [ ] API endpoint `/api/messages/image` работает
- [ ] Изображения доступны через `/images/...`
- [ ] MediaCleanupService запускается
- [ ] Backup настроен

---

## 🎯 Следующие шаги

1. ✅ Применить изменения на сервере
2. ✅ Протестировать отправку изображения
3. ✅ Настроить Firebase (см. `FIREBASE_SERVER_SETUP.md`)
4. ⏳ Настроить автоматический backup
5. ⏳ Мониторить использование диска

---

**Дата:** 19 декабря 2025  
**Проект:** Депеша  
**Версия:** 1.0

**Docker конфигурация обновлена! 🐳✅**

