---
name: Messenger Sync Fix
overview: "Исправление критических проблем синхронизации мессенджера: долгое переподключение SignalR, рассинхронизация превью и содержимого чата, застревание индикатора загрузки при отсутствии получателя в сети."
todos:
  - id: cache-signalr-msg
    content: Сохранять сообщения SignalR напрямую в Hive кэш до обновления провайдеров
    status: completed
  - id: optimize-reconnect
    content: Оптимизировать backoff переподключения и добавить общий таймаут 15 сек
    status: completed
  - id: fix-race-condition
    content: Добавить pending queue для сообщений приходящих во время загрузки
    status: completed
  - id: add-api-timeout
    content: Добавить таймаут 10 сек для API запросов загрузки сообщений
    status: completed
  - id: graceful-loading
    content: Улучшить graceful degradation при ошибках загрузки
    status: completed
---

# Исправление синхронизации мессенджера

## Выявленные критические проблемы

### 1. Рассинхронизация превью чата и содержимого

**Файл**: [`signalr_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart)Когда приходит сообщение через SignalR:

- Превью чата обновляется (строка 174) `updateChatLastMessage()`
- Но `messagesProvider` может не существовать (чат не открыт)
- При открытии чата `loadMessages()` загружает из кэша, но сообщение не было сохранено

**Следствие**: Сообщения видны в превью, но отсутствуют при открытии чата.

### 2. Долгое переподключение SignalR

**Файл**: [`signalr_service.dart`](_may_messenger_mobile_app/lib/data/datasources/signalr_service.dart)

- Exponential backoff достигает 30 секунд (строка 279)
- Ограничение в 5 попыток переподключения
- Нет таймаута для общего процесса reconnect
- При возврате из background (> 10 сек) показывается баннер и начинается медленный процесс

### 3. Race condition при загрузке сообщений

**Файл**: [`messages_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/messages_provider.dart)

- `loadMessages()` вызывается в конструкторе (строка 90)
- `addMessage()` может прийти во время загрузки
- Новое сообщение может быть перезаписано старыми данными из кэша

### 4. Отсутствие таймаута загрузки

При отсутствии сети или медленном соединении:

- API запросы могут висеть неопределённо долго
- `isLoading = true` остаётся активным
- Пользователь видит бесконечный индикатор загрузки

## План исправлений

### Фаза 1: Исправление кэширования сообщений при SignalR событии

1. В `signalr_provider.dart` при получении сообщения - **сначала** сохранять в Hive кэш, **затем** обновлять провайдеры
2. Гарантировать сохранение сообщения в persistent storage независимо от состояния MessagesProvider

### Фаза 2: Улучшение логики переподключения

1. Уменьшить exponential backoff: `[0, 500, 1000, 2000, 3000]` вместо текущего с 30 сек максимумом
2. Добавить таймаут на весь процесс reconnect (максимум 15 секунд)
3. Улучшить `forceReconnectFromLifecycle()` - немедленная попытка без лишних проверок при возврате из background

### Фаза 3: Исправление race condition

1. Добавить очередь входящих сообщений, которая обрабатывается после завершения `loadMessages()`
2. При `addMessage()` во время `isLoading=true` - добавлять в pending queue
3. После завершения загрузки - мержить pending сообщения с загруженными

### Фаза 4: Добавление таймаутов и graceful degradation

1. Добавить таймаут для API запросов загрузки сообщений (10 секунд)
2. При таймауте - показывать кэшированные данные с индикатором "Нет связи"
3. Обеспечить сброс `isLoading=false` даже при ошибках

### Фаза 5: Улучшение UI при отсутствии получателя

1. Не блокировать UI индикатором загрузки при отправке сообщений
2. Статус "sent" показывать сразу после успешной отправки на сервер
3. Добавить визуальную индикацию "получатель не в сети"

## Ключевые файлы для изменения

1. [`signalr_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart) - сохранение в кэш
2. [`signalr_service.dart`](_may_messenger_mobile_app/lib/data/datasources/signalr_service.dart) - улучшение reconnect