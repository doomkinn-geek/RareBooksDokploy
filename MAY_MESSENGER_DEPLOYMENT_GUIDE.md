# Руководство по развертыванию May Messenger на сервер с RareBooks Service

## 📋 Содержание

1. [Обзор](#обзор)
2. [Архитектура](#архитектура)
3. [Подготовка к развертыванию](#подготовка-к-развертыванию)
4. [Развертывание на сервере](#развертывание-на-сервере)
5. [Проверка работоспособности](#проверка-работоспособности)
6. [Управление сервисами](#управление-сервисами)
7. [Диагностика проблем](#диагностика-проблем)
8. [Откат изменений](#откат-изменений)
9. [API документация](#api-документация)

---

## 🎯 Обзор

Данное руководство описывает процесс интеграции API мессенджера **May Messenger** на существующий сервер Ubuntu с **RareBooks Service**. После развертывания на одном сервере будут работать два независимых веб-приложения:

- **www.rare-books.ru** - основное приложение RareBooks (frontend + backend)
- **messenger.rare-books.ru** - API мессенджера May Messenger

### Особенности

- ✅ Оба приложения работают на одном сервере
- ✅ Изолированные базы данных для каждого приложения
- ✅ Единая Docker сеть `rarebooks_network`
- ✅ Nginx как reverse proxy для обоих доменов
- ✅ SSL/TLS сертификаты через Let's Encrypt
- ✅ Автоматический перезапуск контейнеров
- ✅ Health checks для всех сервисов

---

## 🏗️ Архитектура

### Структура сервисов Docker

```
┌─────────────────────────────────────────────────────────────┐
│                     Nginx Reverse Proxy                      │
│              (порты 80, 443 открыты наружу)                  │
└───────────────┬─────────────────────┬───────────────────────┘
                │                     │
    ┌───────────▼──────────┐  ┌──────▼──────────────────┐
    │  RareBooks Services  │  │  May Messenger Services │
    ├──────────────────────┤  ├─────────────────────────┤
    │ • frontend:80        │  │ • maymessenger_backend  │
    │ • backend:80         │  │   :5000                 │
    │ • db_books:5432      │  │ • db_maymessenger:5432  │
    │ • db_users:5432      │  │                         │
    └──────────────────────┘  └─────────────────────────┘
                │                     │
                └─────────┬───────────┘
                          │
            ┌─────────────▼──────────────┐
            │   rarebooks_network        │
            │   (Docker bridge network)  │
            └────────────────────────────┘
```

### Добавленные сервисы

#### 1. `db_maymessenger`
- **Образ:** postgres:15
- **База данных:** maymessenger
- **Учетные данные:** postgres / postgres123
- **Volume:** db_maymessenger_data
- **Healthcheck:** pg_isready

#### 2. `maymessenger_backend`
- **Платформа:** ASP.NET Core 8.0
- **Порт:** 5000
- **Build context:** ./MayMessenger/backend
- **Volume:** maymessenger_audio (для аудио файлов)
- **Healthcheck:** curl http://localhost:5000/health

### Nginx конфигурация

#### Upstream'ы

```nginx
upstream maymessenger_backend {
    server maymessenger_backend:5000;
}
```

#### Server blocks

- **messenger.rare-books.ru (HTTPS)**
  - `/api/` → May Messenger API
  - `/hubs/` → SignalR WebSocket
  - `/swagger` → Swagger UI документация
  - `/health` → Health check endpoint
  - `/` → редирект на /swagger

- **messenger.rare-books.ru (HTTP)**
  - Редирект на HTTPS

---

## 🚀 Подготовка к развертыванию

### Шаг 1: Подготовка файлов (локально в Windows)

#### 1.1. Создание архива backend

Запустите скрипт подготовки:

```powershell
# В Git Bash или WSL
cd D:\_SOURCES\source\RareBooksServicePublic
./prepare_deployment_package.sh
```

Или вручную:

```powershell
cd _may_messenger_backend
Compress-Archive -Path * -DestinationPath ..\may_messenger_backend.zip -Force
cd ..
```

#### 1.2. Проверка файлов

Убедитесь, что созданы/обновлены следующие файлы:

- ✅ `docker-compose.yml` - обновленная конфигурация
- ✅ `nginx/nginx_prod.conf` - обновленная конфигурация Nginx
- ✅ `may_messenger_backend.zip` - архив с кодом backend
- ✅ `deploy_maymessenger.sh` - скрипт развертывания
- ✅ `verify_services.sh` - скрипт проверки
- ✅ `check_messenger_logs.sh` - скрипт просмотра логов
- ✅ `rollback_deployment.sh` - скрипт отката

### Шаг 2: Загрузка файлов на сервер

#### 2.1. Загрузка через SCP

```bash
# Загрузка конфигураций
scp docker-compose.yml root@217.198.5.89:/root/RareBooksDokploy/docker-compose.yml.new
scp nginx/nginx_prod.conf root@217.198.5.89:/root/RareBooksDokploy/nginx/nginx_prod.conf.new

# Загрузка архива backend
scp may_messenger_backend.zip root@217.198.5.89:/root/RareBooksDokploy/

# Загрузка скриптов
scp deploy_maymessenger.sh root@217.198.5.89:/root/RareBooksDokploy/
scp verify_services.sh root@217.198.5.89:/root/RareBooksDokploy/
scp check_messenger_logs.sh root@217.198.5.89:/root/RareBooksDokploy/
scp rollback_deployment.sh root@217.198.5.89:/root/RareBooksDokploy/
```

#### 2.2. Альтернативный метод (через SFTP)

Используйте FileZilla, WinSCP или другой SFTP клиент для загрузки файлов в `/root/RareBooksDokploy/`.

---

## 🎬 Развертывание на сервере

### Шаг 1: Подключение к серверу

```bash
ssh root@217.198.5.89
cd /root/RareBooksDokploy
```

### Шаг 2: Распаковка архива backend

```bash
# Удаляем старые папки (если есть)
rm -rf MayMessenger backend

# Создаем структуру директорий
mkdir -p MayMessenger

# Распаковываем архив
unzip -q may_messenger_backend.zip -d MayMessenger/backend

# Проверяем структуру
ls -la MayMessenger/backend/
ls -la MayMessenger/backend/src/
```

Должна получиться следующая структура:

```
MayMessenger/
└── backend/
    ├── Dockerfile
    ├── MayMessenger.sln
    ├── env.example
    └── src/
        ├── MayMessenger.API/
        ├── MayMessenger.Application/
        ├── MayMessenger.Domain/
        └── MayMessenger.Infrastructure/
```

### Шаг 3: Применение конфигураций

```bash
# Создаем backup текущих конфигураций
mkdir -p backups
cp docker-compose.yml backups/docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
cp nginx/nginx_prod.conf backups/nginx_prod.conf.backup.$(date +%Y%m%d_%H%M%S)

# Применяем новые конфигурации
cp docker-compose.yml.new docker-compose.yml
cp nginx/nginx_prod.conf.new nginx/nginx_prod.conf
```

### Шаг 4: Автоматическое развертывание (рекомендуется)

```bash
# Делаем скрипт исполняемым
chmod +x deploy_maymessenger.sh

# Запускаем развертывание
./deploy_maymessenger.sh
```

Скрипт автоматически:
- ✅ Проверит окружение
- ✅ Создаст backup
- ✅ Проверит конфигурацию Docker Compose
- ✅ Запустит новые сервисы
- ✅ Перезапустит Nginx
- ✅ Проверит работоспособность

### Шаг 5: Ручное развертывание (альтернатива)

Если предпочитаете выполнить вручную:

```bash
# 1. Проверка конфигурации
docker compose config

# 2. Запуск базы данных May Messenger
docker compose up -d db_maymessenger

# Ждем 30 секунд для инициализации БД
sleep 30

# 3. Сборка и запуск backend
docker compose build maymessenger_backend
docker compose up -d maymessenger_backend

# Ждем 90 секунд для запуска backend
sleep 90

# 4. Перезапуск Nginx
docker compose restart proxy

# Ждем 30 секунд
sleep 30

# 5. Проверка статуса
docker compose ps
```

---

## ✅ Проверка работоспособности

### Автоматическая проверка

```bash
# Делаем скрипт исполняемым
chmod +x verify_services.sh

# Запускаем проверку
./verify_services.sh
```

Скрипт проверит:
- Статус всех контейнеров
- Health checks
- Доступность API endpoints
- Работу баз данных
- Сеть Docker
- Наличие ошибок в логах

### Ручная проверка

#### 1. Проверка контейнеров

```bash
docker compose ps
```

Все контейнеры должны быть в статусе `Up` и `healthy`.

#### 2. Проверка May Messenger API

```bash
# Health check
curl -k https://messenger.rare-books.ru/health

# Swagger UI (должен вернуть HTML)
curl -k https://messenger.rare-books.ru/swagger

# API endpoint (должен вернуть 401 Unauthorized - это нормально)
curl -k https://messenger.rare-books.ru/api/chats
```

#### 3. Проверка RareBooks

```bash
# Главная страница
curl -k https://www.rare-books.ru/

# API endpoint
curl -k https://www.rare-books.ru/api/test/setup-status
```

#### 4. Проверка баз данных

```bash
# May Messenger DB
docker exec db_maymessenger psql -U postgres -d maymessenger -c "SELECT COUNT(*) FROM \"Users\";"

# RareBooks Books DB
docker exec rarebooks_books_db psql -U postgres -d RareBooks_Books -c "SELECT COUNT(*) FROM \"Books\";"

# RareBooks Users DB
docker exec rarebooks_users_db psql -U postgres -d RareBooks_Users -c "SELECT COUNT(*) FROM \"Users\";"
```

---

## 🛠️ Управление сервисами

### Просмотр логов

#### May Messenger

```bash
# В реальном времени
docker compose logs -f maymessenger_backend

# Последние 100 строк
docker compose logs maymessenger_backend --tail 100

# С помощью скрипта
chmod +x check_messenger_logs.sh
./check_messenger_logs.sh          # Анализ логов
./check_messenger_logs.sh -f       # В реальном времени
```

#### RareBooks

```bash
# Backend
docker compose logs -f backend

# Frontend
docker compose logs -f frontend

# Nginx
docker compose logs -f proxy
```

### Перезапуск сервисов

```bash
# Перезапуск May Messenger
docker compose restart maymessenger_backend

# Перезапуск базы данных
docker compose restart db_maymessenger

# Перезапуск Nginx
docker compose restart proxy

# Перезапуск всех сервисов
docker compose restart
```

### Остановка и запуск

```bash
# Остановка May Messenger
docker compose stop maymessenger_backend db_maymessenger

# Запуск May Messenger
docker compose start db_maymessenger maymessenger_backend

# Полная остановка всех сервисов
docker compose down

# Запуск всех сервисов
docker compose up -d
```

### Пересборка контейнеров

```bash
# Пересборка May Messenger backend
docker compose build --no-cache maymessenger_backend

# Запуск с пересборкой
docker compose up -d --build maymessenger_backend
```

---

## 🔍 Диагностика проблем

### May Messenger не отвечает

#### 1. Проверьте статус контейнера

```bash
docker compose ps maymessenger_backend
```

#### 2. Проверьте логи

```bash
docker compose logs maymessenger_backend --tail 200
```

#### 3. Проверьте healthcheck

```bash
docker inspect maymessenger_backend | grep -A 10 Health
```

#### 4. Тестируйте напрямую из Docker сети

```bash
docker exec nginx_container wget -qO- http://maymessenger_backend:5000/health
```

#### 5. Проверьте подключение к БД

```bash
docker exec maymessenger_backend curl http://localhost:5000/health
```

### RareBooks перестал работать

#### 1. Проверьте логи Nginx

```bash
docker compose logs proxy --tail 100
```

#### 2. Проверьте конфигурацию Nginx

```bash
docker exec nginx_container nginx -t
```

#### 3. Откатите изменения

См. раздел [Откат изменений](#откат-изменений).

### Проблемы с базой данных

#### 1. Проверьте статус БД

```bash
docker compose ps db_maymessenger
docker compose logs db_maymessenger --tail 50
```

#### 2. Проверьте подключение

```bash
docker exec db_maymessenger psql -U postgres -d maymessenger -c "\l"
```

#### 3. Пересоздайте БД (ВНИМАНИЕ: удалит все данные!)

```bash
docker compose down db_maymessenger
docker volume rm rarebooksdokploy_db_maymessenger_data
docker compose up -d db_maymessenger
```

### Проблемы с сетью

#### 1. Проверьте сеть

```bash
docker network inspect rarebooks_network
```

#### 2. Пересоздайте сеть

```bash
docker compose down
docker network rm rarebooks_network
docker compose up -d
```

---

## ⏮️ Откат изменений

### Автоматический откат

```bash
# Делаем скрипт исполняемым
chmod +x rollback_deployment.sh

# Запускаем откат
./rollback_deployment.sh
```

Скрипт автоматически:
- Остановит сервисы May Messenger
- Восстановит конфигурации из backup
- Перезапустит Nginx
- Проверит работу RareBooks

### Ручной откат

```bash
# 1. Остановка May Messenger сервисов
docker compose stop maymessenger_backend db_maymessenger

# 2. Восстановление конфигураций (замените YYYYMMDD_HHMMSS на дату backup)
cp backups/docker-compose.yml.backup.YYYYMMDD_HHMMSS docker-compose.yml
cp backups/nginx_prod.conf.backup.YYYYMMDD_HHMMSS nginx/nginx_prod.conf

# 3. Перезапуск Nginx
docker compose restart proxy

# 4. Проверка
docker compose ps
curl -k https://www.rare-books.ru/
```

---

## 📚 API документация

### May Messenger Endpoints

#### Base URL
```
https://messenger.rare-books.ru/api/
```

#### Swagger UI
```
https://messenger.rare-books.ru/swagger
```

#### Health Check
```
GET https://messenger.rare-books.ru/health
```

#### Основные endpoints

**Аутентификация**
- `POST /api/auth/register` - Регистрация нового пользователя
- `POST /api/auth/login` - Вход в систему

**Чаты**
- `GET /api/chats` - Получить список чатов
- `POST /api/chats` - Создать новый чат
- `GET /api/chats/{id}` - Получить информацию о чате
- `DELETE /api/chats/{id}` - Удалить чат

**Сообщения**
- `GET /api/messages/{chatId}` - Получить сообщения чата
- `POST /api/messages` - Отправить сообщение
- `DELETE /api/messages/{id}` - Удалить сообщение

**Admin**
- `GET /api/admin/users` - Получить список пользователей (требуется роль Admin)
- `DELETE /api/admin/users/{id}` - Удалить пользователя (требуется роль Admin)

#### SignalR Hub

**WebSocket endpoint**
```
wss://messenger.rare-books.ru/hubs/chat
```

**События**
- `ReceiveMessage` - Получение нового сообщения
- `UserConnected` - Пользователь подключился
- `UserDisconnected` - Пользователь отключился

### Учетные данные

**Администратор**
- Телефон: `+79604243127`
- Пароль: `ppAKiH1Y`

**Invite код для регистрации**
- Код: `WELCOME2024`

### База данных

**Подключение (внутри Docker сети)**
- Host: `db_maymessenger`
- Port: `5432`
- Database: `maymessenger`
- User: `postgres`
- Password: `postgres123`

---

## 📊 Мониторинг

### Использование ресурсов

```bash
# Просмотр использования CPU и RAM
docker stats

# Только May Messenger
docker stats maymessenger_backend db_maymessenger
```

### Размер Docker volumes

```bash
# Список volumes
docker volume ls

# Информация о volume
docker volume inspect rarebooksdokploy_db_maymessenger_data
docker volume inspect rarebooksdokploy_maymessenger_audio
```

### Логи Nginx

```bash
# Access logs
docker exec nginx_container tail -f /var/log/nginx/access.log

# Error logs
docker exec nginx_container tail -f /var/log/nginx/error.log
```

---

## 🔐 Безопасность

### SSL/TLS сертификаты

Используется wildcard сертификат для `*.rare-books.ru`:

```
/etc/letsencrypt/live/rare-books.ru/fullchain.pem
/etc/letsencrypt/live/rare-books.ru/privkey.pem
```

### Обновление сертификатов

```bash
# Обновление через certbot
certbot renew

# Перезапуск Nginx после обновления
docker compose restart proxy
```

### JWT секретный ключ

**Текущий JWT Secret (из конфигурации):**
```
MayMessenger_SuperSecret_Key_2024_Change_This_In_Production_12345678
```

**Для изменения JWT Secret:**

1. Отредактируйте `docker-compose.yml`:
```yaml
environment:
  - Jwt__Secret=ВАШ_НОВЫЙ_СЕКРЕТНЫЙ_КЛЮЧ
```

2. Перезапустите контейнер:
```bash
docker compose restart maymessenger_backend
```

### Изолированная сеть

Все сервисы изолированы в Docker сети `rarebooks_network`. Только Nginx имеет доступ извне через порты 80 и 443.

---

## 📝 Примечания

1. **Порты**: Все внутренние сервисы недоступны извне. Только Nginx открывает порты 80 и 443.

2. **Volumes**: Данные баз данных и файлы сохраняются в Docker volumes и не удаляются при перезапуске контейнеров.

3. **Автозапуск**: Все контейнеры настроены на `restart: unless-stopped` и запустятся автоматически после перезагрузки сервера.

4. **Healthchecks**: Все сервисы имеют health checks для контроля работоспособности.

5. **Backup**: Всегда создавайте backup перед обновлением конфигураций.

---

## 🆘 Поддержка

### Полезные ссылки

- **RareBooks Web**: https://www.rare-books.ru/
- **May Messenger API**: https://messenger.rare-books.ru/api/
- **May Messenger Swagger**: https://messenger.rare-books.ru/swagger

### Команды для быстрой диагностики

```bash
# Статус всех сервисов
docker compose ps

# Логи May Messenger
docker compose logs -f maymessenger_backend

# Проверка всех сервисов
./verify_services.sh

# Анализ логов
./check_messenger_logs.sh

# Откат изменений
./rollback_deployment.sh
```

---

**Версия документа**: 1.0  
**Дата**: Декабрь 2024  
**Автор**: AI Assistant

