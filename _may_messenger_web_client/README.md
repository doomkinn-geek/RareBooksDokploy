# May Messenger Web Client

Веб-клиент для мессенджера May Messenger, созданный на React с TypeScript.

## Возможности

- ✅ Авторизация и регистрация пользователей
- ✅ Real-time обмен сообщениями через SignalR/WebSocket
- ✅ Отправка и получение текстовых сообщений
- ✅ Запись и отправка аудио сообщений через микрофон
- ✅ Воспроизведение аудио сообщений
- ✅ Список чатов с последним сообщением
- ✅ Статусы сообщений (отправлено/прочитано)
- ✅ Responsive дизайн

## Технологический стек

- **React 18** - UI библиотека
- **TypeScript** - типизация
- **Vite** - сборщик
- **Zustand** - управление состоянием
- **Axios** - HTTP клиент
- **@microsoft/signalr** - WebSocket соединения
- **TailwindCSS** - стилизация
- **React Router** - навигация
- **Lucide React** - иконки

## Локальная разработка

### Предварительные требования

- Node.js 18+ и npm
- Backend API должен быть запущен

### Установка

```bash
cd _may_messenger_web_client
npm install
```

### Конфигурация

Создайте файл `.env` на основе `.env.example`:

```bash
VITE_API_URL=https://messenger.rare-books.ru
```

Для локальной разработки можете использовать:

```bash
VITE_API_URL=http://localhost:5000
```

### Запуск

```bash
npm run dev
```

Приложение будет доступно по адресу: `http://localhost:3000`

### Сборка

```bash
npm run build
```

Результат будет в папке `dist/`

## Docker

### Сборка образа

```bash
docker build -t maymessenger_web_client .
```

### Запуск контейнера

```bash
docker run -p 80:80 maymessenger_web_client
```

## Архитектура

### Структура папок

```
src/
├── api/              # HTTP клиенты (Axios)
├── components/       # React компоненты
│   ├── auth/        # Авторизация
│   ├── chat/        # Чаты
│   ├── message/     # Сообщения
│   └── layout/      # Макеты
├── pages/           # Страницы приложения
├── services/        # Бизнес-логика
│   ├── signalRService.ts   # WebSocket
│   ├── audioRecorder.ts    # Запись аудио
│   └── audioPlayer.ts      # Воспроизведение
├── stores/          # Zustand хранилища
├── types/           # TypeScript типы
└── utils/           # Вспомогательные функции
```

### Основные сервисы

#### SignalR Service
Управляет WebSocket соединением с backend:
- Автоматический реконнект
- Подписка на события (ReceiveMessage, MessageStatusUpdated)
- Отправка событий (JoinChat, MessageRead, TypingIndicator)

#### Audio Recorder
Запись аудио сообщений через Web Audio API:
- Запрос доступа к микрофону
- Запись в формате webm/opus или mp4
- Автоматическое определение поддерживаемого формата

#### Audio Player
Воспроизведение аудио сообщений:
- HTML5 Audio API
- Прогресс-бар с текущим временем
- Управление воспроизведением

### Zustand Stores

#### Auth Store
- Авторизация и регистрация
- Хранение токена и профиля пользователя
- Подключение к SignalR после входа

#### Chat Store
- Список чатов
- Выбранный чат
- Создание новых чатов

#### Message Store
- Сообщения по чатам
- Отправка текстовых/аудио сообщений
- Обновление статусов сообщений
- Real-time добавление новых сообщений

## API Endpoints

### Авторизация
- `POST /api/auth/login` - Вход
- `POST /api/auth/register` - Регистрация
- `GET /api/users/me` - Профиль пользователя

### Чаты
- `GET /api/chats` - Список чатов
- `GET /api/chats/{id}` - Информация о чате
- `POST /api/chats` - Создание чата

### Сообщения
- `GET /api/messages/{chatId}` - Сообщения чата
- `POST /api/messages` - Отправка текста
- `POST /api/messages/audio` - Отправка аудио

### SignalR Hub
- `/hubs/chat` - WebSocket endpoint

## Troubleshooting

### CORS ошибки

Убедитесь, что backend настроен с правильными origins:
```csharp
policy.WithOrigins(
    "https://messenger.rare-books.ru",
    "http://localhost:3000"
)
```

### Аудио не воспроизводится

1. Проверьте, что nginx проксирует `/audio/` к backend
2. Убедитесь, что файлы сохраняются в `/app/wwwroot/audio`
3. Проверьте доступность файла в браузере

### SignalR не подключается

1. Проверьте WebSocket соединение в DevTools (Network → WS)
2. Убедитесь, что токен JWT валидный
3. Проверьте логи backend

### Микрофон не работает

1. Браузер должен иметь разрешение на микрофон
2. HTTPS обязателен (в production)
3. В Chrome: Settings → Privacy → Site Settings → Microphone

## Production Deployment

Web-клиент развернут в Docker контейнере и доступен по адресу:

```
https://messenger.rare-books.ru/web
```

### Обновление

1. Внесите изменения в код
2. Пересоберите Docker образ:
   ```bash
   docker-compose build maymessenger_web_client
   ```
3. Перезапустите контейнер:
   ```bash
   docker-compose up -d maymessenger_web_client
   ```

## Безопасность

- JWT токены хранятся в localStorage
- CORS настроен только для доверенных доменов
- HTTPS обязателен в production
- WebSocket использует JWT авторизацию

## Лицензия

Proprietary - все права защищены
