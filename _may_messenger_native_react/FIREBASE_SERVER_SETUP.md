# 🔥 Firebase - Настройка на сервере

## Где находится бэкенд?

API мессенджера разворачивается через Docker вместе с Rare Books Service.

**Местоположение:**
- Docker Compose: `/root/RareBooksServicePublic/docker-compose.yml`
- Бэкенд контейнер: `maymessenger_backend`
- Volume для Firebase: `maymessenger_firebase`

---

## 📋 Что нужно

1. **Service Account JSON** от Firebase
2. Доступ к серверу по SSH
3. Права на перезапуск Docker контейнеров

---

## 🚀 Пошаговая настройка

### Шаг 1: Получить Service Account JSON

1. Откройте https://console.firebase.google.com/
2. Выберите проект "Depesha" (или создайте если нет)
3. **Project settings** (⚙️) → **Service accounts**
4. Нажмите **"Generate new private key"**
5. Подтвердите в диалоге
6. Скачается файл типа `depesha-firebase-adminsdk-xxxxx-xxxxxxxxxx.json`
7. **Переименуйте** файл в `firebase_config.json`

---

### Шаг 2: Загрузить на сервер

#### Вариант 1: SCP (Windows → Linux)

```powershell
# Замените путь к файлу и данные сервера
scp C:\Downloads\firebase_config.json root@ваш-сервер.ru:/tmp/

# После загрузки подключитесь по SSH
ssh root@ваш-сервер.ru
```

#### Вариант 2: FileZilla / WinSCP

1. Подключитесь к серверу
2. Загрузите `firebase_config.json` в `/tmp/`

---

### Шаг 3: Разместить в Docker volume

```bash
# Подключиться к серверу
ssh root@ваш-сервер.ru

# Перейти в папку проекта
cd /root/RareBooksServicePublic

# Создать директорию для Firebase config в volume
docker exec maymessenger_backend mkdir -p /app/firebase_config

# Скопировать файл в контейнер
docker cp /tmp/firebase_config.json maymessenger_backend:/app/firebase_config/firebase_config.json

# Проверить что файл на месте
docker exec maymessenger_backend ls -la /app/firebase_config/

# Должно показать:
# -rw-r--r-- 1 root root 2461 Dec 19 12:00 firebase_config.json

# Удалить временный файл
rm /tmp/firebase_config.json
```

---

### Шаг 4: Обновить конфигурацию (если нужно)

Firebase конфигурация указывается в docker-compose.yml через environment или через файл.

**Проверьте docker-compose.yml:**

```yaml
maymessenger_backend:
  # ...
  volumes:
    - maymessenger_audio:/app/wwwroot/audio
    - maymessenger_images:/app/wwwroot/images
    - maymessenger_firebase:/app/firebase_config  # ← Должен быть
```

**Volume уже настроен!** ✅

---

### Шаг 5: Перезапустить контейнер

```bash
# Вариант 1: Перезапуск только мессенджера
docker restart maymessenger_backend

# Вариант 2: Полная пересборка (если обновлялся код)
cd /root/RareBooksServicePublic
docker-compose build maymessenger_backend
docker-compose up -d maymessenger_backend

# Вариант 3: Пересборка всех сервисов
docker-compose down
docker-compose up -d --build
```

**Рекомендуется:** Вариант 1 (быстро, 10 секунд)

---

### Шаг 6: Проверить инициализацию

**Проверка 1: Логи контейнера**

```bash
docker logs maymessenger_backend --tail 50 | grep -i firebase
```

**Должно быть:**
```
Firebase initialized from /app/firebase_config/firebase_config.json
```

**Если ошибка:**
```
Firebase config not found at /app/firebase_config/firebase_config.json
```

**Проверка 2: Health Check API**

```bash
curl https://messenger.rare-books.ru/health
```

**Должен вернуть:**
```json
{
  "status": "Healthy",
  "checks": [
    {
      "name": "firebase",
      "status": "Healthy",
      "description": null
    }
  ]
}
```

**Если Unhealthy:**
- Файл не найден
- Файл поврежден
- Неверный формат JSON
- Неверные права доступа

---

## 🔧 Настройка путей (если нужно)

### Вариант 1: Через переменные окружения

Файл: `docker-compose.yml`

```yaml
maymessenger_backend:
  environment:
    - Firebase__ConfigPath=/app/firebase_config/firebase_config.json
```

### Вариант 2: Через appsettings.json

Файл: `_may_messenger_backend/src/MayMessenger.API/appsettings.Production.json`

```json
{
  "Firebase": {
    "ConfigPath": "/app/firebase_config/firebase_config.json"
  }
}
```

**По умолчанию:** Уже настроено правильно ✅

---

## 🐳 Docker Volume пояснение

### Что такое Volume?

Volume `maymessenger_firebase` - это постоянное хранилище Docker.

**Преимущества:**
- ✅ Файлы сохраняются при перезапуске контейнера
- ✅ Файлы сохраняются при обновлении образа
- ✅ Можно делать backup

**Где физически хранятся файлы?**

```bash
# Узнать местоположение volume
docker volume inspect maymessenger_firebase

# Вывод покажет:
# "Mountpoint": "/var/lib/docker/volumes/maymessenger_firebase/_data"
```

**Просмотр файлов:**

```bash
# Прямой доступ (требует root)
ls -la /var/lib/docker/volumes/maymessenger_firebase/_data/

# Через контейнер (безопаснее)
docker exec maymessenger_backend ls -la /app/firebase_config/
```

---

## 📦 Backup Firebase конфигурации

### Создать backup

```bash
# Способ 1: Из volume
sudo cp /var/lib/docker/volumes/maymessenger_firebase/_data/firebase_config.json \
        /root/backups/firebase_config_$(date +%Y%m%d).json

# Способ 2: Из контейнера
docker cp maymessenger_backend:/app/firebase_config/firebase_config.json \
          /root/backups/firebase_config_$(date +%Y%m%d).json

# Проверить backup
ls -lh /root/backups/firebase_config_*.json
```

### Восстановить из backup

```bash
# Скопировать обратно
docker cp /root/backups/firebase_config_20251219.json \
          maymessenger_backend:/app/firebase_config/firebase_config.json

# Перезапустить
docker restart maymessenger_backend
```

---

## 🔍 Troubleshooting

### Ошибка: "Firebase config not found"

**Причина:** Файл не найден по указанному пути

**Решение:**

```bash
# 1. Проверить существование файла
docker exec maymessenger_backend ls -la /app/firebase_config/

# 2. Если нет - скопировать снова
docker cp firebase_config.json maymessenger_backend:/app/firebase_config/

# 3. Проверить права
docker exec maymessenger_backend chmod 644 /app/firebase_config/firebase_config.json

# 4. Перезапустить
docker restart maymessenger_backend
```

---

### Ошибка: "Failed to initialize Firebase"

**Причина:** Неверный формат JSON или поврежденный файл

**Решение:**

```bash
# 1. Проверить содержимое
docker exec maymessenger_backend cat /app/firebase_config/firebase_config.json | jq .

# Должен вывести структурированный JSON без ошибок

# 2. Если ошибка - файл поврежден, скачайте новый с Firebase Console
```

---

### Ошибка: "Error 401: Unauthorized" при отправке push

**Причина:** Неверный Service Account или истек срок

**Решение:**

1. Скачать новый Service Account JSON с Firebase Console
2. Заменить файл на сервере
3. Перезапустить контейнер

---

### Push-уведомления не приходят

**Чеклист:**

1. ✅ Firebase инициализирован? → `docker logs maymessenger_backend | grep Firebase`
2. ✅ FCM токен зарегистрирован в БД? → Проверить таблицу FcmTokens
3. ✅ Приложение в background? (foreground обрабатывается по-другому)
4. ✅ Google Play Services установлены? (на реальном устройстве)
5. ✅ Internet доступен на телефоне?

---

## 🔄 Обновление Firebase конфигурации

### Когда нужно обновлять?

- 🔄 Истек срок действия Service Account
- 🔄 Изменился Firebase проект
- 🔄 Скомпрометирован ключ
- 🔄 Переезд на другой сервер

### Процесс обновления

```bash
# 1. Скачать новый firebase_config.json с Firebase Console

# 2. Загрузить на сервер
scp firebase_config.json root@сервер:/tmp/

# 3. Заменить в контейнере
ssh root@сервер
docker cp /tmp/firebase_config.json maymessenger_backend:/app/firebase_config/firebase_config.json

# 4. Перезапустить
docker restart maymessenger_backend

# 5. Проверить логи
docker logs maymessenger_backend --tail 20 | grep Firebase

# 6. Удалить временный файл
rm /tmp/firebase_config.json
```

**Время простоя:** ~10 секунд

---

## 📊 Мониторинг Firebase

### Проверка работоспособности

```bash
# Health check
curl https://messenger.rare-books.ru/health | jq .checks[] | grep firebase

# Логи (последние 100 строк)
docker logs maymessenger_backend --tail 100 | grep -i firebase

# Отправка тестового push (через API)
curl -X POST https://messenger.rare-books.ru/api/messages \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"chatId":"...","content":"Test"}'
```

### Статистика Firebase

1. Откройте Firebase Console
2. **Engage** → **Cloud Messaging**
3. Просмотр статистики отправленных уведомлений

---

## 🎯 Финальная проверка

```bash
# 1. Файл существует
docker exec maymessenger_backend test -f /app/firebase_config/firebase_config.json && echo "OK" || echo "FAIL"

# 2. Firebase инициализирован
docker logs maymessenger_backend 2>&1 | grep "Firebase initialized" && echo "OK" || echo "FAIL"

# 3. Health check
curl -s https://messenger.rare-books.ru/health | jq -r '.checks[] | select(.name=="firebase") | .status' | grep "Healthy" && echo "OK" || echo "FAIL"

# Все 3 должны вернуть "OK"
```

---

## 📝 Чеклист настройки

- [ ] Service Account JSON скачан с Firebase Console
- [ ] Файл переименован в `firebase_config.json`
- [ ] Файл загружен на сервер
- [ ] Файл скопирован в контейнер `/app/firebase_config/firebase_config.json`
- [ ] Контейнер перезапущен
- [ ] Логи показывают "Firebase initialized"
- [ ] Health check возвращает "Healthy"
- [ ] Backup конфигурации создан

---

## 🔐 Безопасность

### ⚠️ ВАЖНО

1. **НЕ коммитьте** `firebase_config.json` в Git
2. **Ограничьте доступ** к файлу (chmod 600)
3. **Делайте backup** конфигурации
4. **Обновляйте** Service Account при компрометации
5. **Используйте** разные проекты для dev/prod

### Рекомендуемые права

```bash
# На сервере
docker exec maymessenger_backend chmod 600 /app/firebase_config/firebase_config.json
docker exec maymessenger_backend chown root:root /app/firebase_config/firebase_config.json
```

---

## 📞 Поддержка

### Полезные команды

```bash
# Логи контейнера (real-time)
docker logs -f maymessenger_backend

# Перезапуск
docker restart maymessenger_backend

# Пересборка (если изменялся код)
cd /root/RareBooksServicePublic
docker-compose build maymessenger_backend
docker-compose up -d maymessenger_backend

# Проверка здоровья
docker ps | grep maymessenger_backend
curl https://messenger.rare-books.ru/health
```

---

**Дата:** 19 декабря 2025  
**Проект:** Депеша  
**Версия:** 1.0

**Firebase настроен! 🔥✅**

