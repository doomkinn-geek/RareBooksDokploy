# May Messenger - Развертывание

## Локальная сборка и проверка

### Web Client
```bash
cd _may_messenger_web_client
npm install
npm run build
npm run dev  # проверка на localhost:3000
```

## Развертывание на сервере

### 1. Остановка контейнеров
```bash
docker compose down
```

### 2. Пересборка контейнеров
```bash
docker compose build --no-cache maymessenger_backend
docker compose build --no-cache maymessenger_web_client
```

### 3. Запуск
```bash
docker compose up -d
```

### 4. Проверка логов
```bash
docker compose logs -f maymessenger_backend
docker compose logs -f maymessenger_web_client
docker compose logs -f proxy
```

### 5. Проверка статуса
```bash
docker compose ps
```

## Доступ к сервисам

- **Web Client**: https://messenger.rare-books.ru/web/
- **API**: https://messenger.rare-books.ru/api/
- **Swagger**: https://messenger.rare-books.ru/swagger
- **Health Check**: https://messenger.rare-books.ru/health

## Основные исправления

1. ✅ **Аудио файлы**: `/app/wwwroot/audio` + nginx location `/audio/`
2. ✅ **CORS**: Явные origins для Credentials
3. ✅ **Web Client**: React + TypeScript + Vite с `base=/web/`
4. ✅ **Nginx**: Проксирование `/web/` -> web_client `/`
5. ✅ **Docker**: npm install вместо npm ci

## Структура

- Backend: ASP.NET Core 8.0 на порту 5000
- Web Client: React на nginx:80 внутри контейнера
- Nginx Proxy: 80/443 снаружи
- PostgreSQL: 5432 внутри сети
- Volumes: `maymessenger_audio`, `db_maymessenger_data`
