# Анализ архитектуры мессенджера May Messenger

## Общая архитектура

May Messenger представляет собой полнофункциональный мессенджер с поддержкой текстовых, аудио и изображений сообщений. Система состоит из четырех основных компонентов:

1. **Бэкенд (ASP.NET Core)** - серверная часть с API и SignalR для real-time коммуникации
2. **Мобильное приложение (Flutter)** - клиент для Android/iOS
3. **Веб-клиент (React)** - веб-интерфейс
4. **База данных (PostgreSQL)** - хранение данных

Все компоненты работают внутри Docker-контейнеров и обслуживаются через nginx reverse proxy.

## Детальный анализ каждого компонента

### 1. Бэкенд (ASP.NET Core)

#### Архитектурные паттерны
- **Clean Architecture** с разделением на слои:
  - **Domain** - бизнес-логика и сущности
  - **Application** - сервисы и DTO
  - **Infrastructure** - репозитории и внешние сервисы
  - **API** - контроллеры и конфигурация

#### Ключевые компоненты

##### Domain Layer
**Сущности:**
- `User` - пользователи с поддержкой онлайн-статуса и контактов
- `Chat` - чаты (приватные и групповые)
- `Message` - сообщения с типами (Text, Audio, Image)
- `MessageStatus` - статусы доставки (Sending, Sent, Delivered, Read, Played)

**Перечисления:**
- `MessageType` - типы сообщений
- `MessageStatus` - статусы сообщений
- `ChatType` - типы чатов

##### SignalR Hub (ChatHub.cs)
**Основной компонент real-time коммуникации:**

```csharp
public class ChatHub : Hub
{
    // Управление подключением пользователей
    public override async Task OnConnectedAsync()
    public override async Task OnDisconnectedAsync()

    // Методы для сообщений
    public async Task MessageDelivered(Guid messageId, Guid chatId)
    public async Task MessageRead(Guid messageId, Guid chatId)

    // Пакетные операции
    public async Task BatchMarkMessagesAs(Guid chatId, List<Guid> messageIds, MessageStatus status)

    // Инкрементальная синхронизация
    public async Task IncrementalSync(DateTime lastSyncTimestamp, List<string>? chatIds = null)

    // Уведомления о наборе текста
    public async Task TypingIndicator(Guid chatId, bool isTyping)

    // Heartbeat для поддержания соединения
    public async Task Heartbeat()
}
```

**Особенности SignalR реализации:**
1. **Аутентификация через JWT** в query параметрах
2. **Групповые чаты** - пользователи автоматически добавляются в группы чатов
3. **ACK механизм** - подтверждения доставки сообщений
4. **Event sourcing** - статусы сообщений хранятся как события
5. **Пакетная обработка** - оптимизация для групповых чатов

##### API Контроллеры

**MessagesController** - основной контроллер для работы с сообщениями:

```csharp
[HttpPost]
public async Task<ActionResult<MessageDto>> SendMessage([FromBody] SendMessageDto dto)

[HttpPost("audio")]
public async Task<ActionResult<MessageDto>> SendAudioMessage([FromForm] Guid chatId, IFormFile audioFile)

[HttpPost("image")]
public async Task<ActionResult<MessageDto>> SendImageMessage([FromForm] Guid chatId, IFormFile imageFile)

[HttpGet("search")]
public async Task<ActionResult<IEnumerable<MessageSearchResultDto>>> SearchMessages([FromQuery] string query)
```

**Ключевые особенности:**
1. **Идемпотентность** - защита от дублирования сообщений через `ClientMessageId`
2. **Оптимистичные блокировки** - `READ_COMMITTED` изоляция для высокой производительности
3. **Автоматическая доставка** - сообщения помечаются как доставленные при получении
4. **FCM push-уведомления** - отправка уведомлений оффлайн пользователям

##### Background Services
```csharp
// Очистка старых файлов
AddHostedService<MediaCleanupService>()

// Очистка недействительных FCM токенов
AddHostedService<CleanupInvalidTokensService>()

// Повторная отправка ACK подтверждений
AddHostedService<AckRetryService>()

// Мониторинг присутствия пользователей
AddHostedService<PresenceMonitorService>()
```

##### Firebase Integration
- **FCM токены** хранятся в отдельной таблице
- **Автоматическая доставка** - сообщения помечаются как доставленные при успешной отправке push
- **Токены деактивируются** при получении ошибок

### 2. Мобильное приложение (Flutter)

#### Архитектура состояния (Riverpod)
Приложение использует **Riverpod** для управления состоянием:

```dart
final signalRConnectionProvider = StateNotifierProvider<SignalRConnectionNotifier, SignalRConnectionState>
final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>
final chatsProvider = StateNotifierProvider<ChatsNotifier, ChatsState>
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>
```

#### SignalR интеграция
**SignalRService** управляет WebSocket соединением:

```dart
class SignalRService {
  Future<void> connect(String token)
  void onReceiveMessage(Function(MessageModel) callback)
  void onMessageStatusUpdated(Function(String, MessageStatus) callback)
  void onUserTyping(Function(String, String, bool) callback)
  Future<void> markMessageAsDelivered(String messageId, String chatId)
}
```

#### Lifecycle Management
Приложение корректно обрабатывает жизненный цикл:

```dart
class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state)

  Future<void> _performResumeSync() // Синхронизация при возврате в приложение
}
```

#### Push-уведомления
**FCM интеграция:**
- **Background handler** для обработки уведомлений в фоне
- **Foreground notifications** для активных пользователей
- **Deep linking** - переход к чату из уведомления
- **Reply actions** - ответ прямо из уведомления

#### Локальное хранение
- **Hive** для кэширования данных
- **Offline-first подход** с синхронизацией при подключении

### 3. Веб-клиент (React)

#### Архитектура
- **React** с хуками для управления состоянием
- **SignalR** для real-time коммуникации
- **TypeScript** для типизации

#### Ключевые компоненты
```tsx
// Основные компоненты
<ChatList />     // Список чатов
<ChatWindow />   // Окно чата
<MessageInput /> // Ввод сообщений
<AudioRecorder /> // Запись аудио
```

#### Offline поддержка
- **IndexedDB** для локального хранения
- **Service Worker** для background синхронизации
- **Connectivity monitoring** для отслеживания подключения

### 4. Инфраструктура

#### Docker Compose
```yaml
services:
  maymessenger_backend:     # ASP.NET Core API + SignalR
  maymessenger_web_client:  # React SPA
  db_maymessenger:          # PostgreSQL
  proxy:                    # nginx
```

#### Nginx конфигурация
**Ключевые особенности:**
- **WebSocket проксирование** для SignalR с длинными таймаутами
- **SSL termination** для HTTPS
- **Статические файлы** обслуживаются напрямую nginx
- **Кэширование** медиафайлов
- **Rate limiting** для защиты от спама

#### База данных
**PostgreSQL** с оптимизациями:
- **GIN индексы** для полнотекстового поиска
- **Event sourcing** для статусов сообщений
- **Партиционирование** по времени (не реализовано)
- **Connection pooling** через nginx upstreams

## Технические особенности реализации

### 1. Надежная доставка сообщений
- **ACK механизм** с повторными попытками
- **Event sourcing** для статусов
- **Идемпотентность** через `ClientMessageId`
- **Pending ACKs** для гарантии доставки

### 2. Real-time коммуникация
- **SignalR** с автоматическим переподключением
- **Групповые чаты** с автоматическим управлением группами
- **Typing indicators** для отображения набора текста
- **Presence monitoring** для онлайн-статуса

### 3. Медиа поддержка
- **Аудио сообщения** с потоковой загрузкой
- **Изображения** с автоматическим сжатием
- **Файловое хранение** с cleanup сервисами
- **CDN готовность** через nginx

### 4. Push-уведомления
- **Firebase Cloud Messaging** для мобильных устройств
- **Автоматическая доставка** при успешной отправке push
- **Токен менеджмент** с автоматической очисткой

### 5. Поиск и производительность
- **Полнотекстовый поиск** с поддержкой русского языка
- **Cursor-based пагинация** для эффективной загрузки
- **Batch операции** для массовых обновлений
- **Кэширование** на уровне nginx

## Масштабируемость и ограничения

### Текущие ограничения
1. **Монолитная архитектура** - все сервисы в одном контейнере
2. **Отсутствие шардирования** базы данных
3. **Ограниченная горизонтальная масштабируемость** из-за SignalR групп
4. **Отсутствие CDN** для медиафайлов

### Положительные аспекты
1. **Микросервисная готовность** - разделение на сервисы
2. **Docker containerization** - легкое масштабирование
3. **База данных оптимизации** - индексы и prepared statements
4. **Efficient protocols** - WebSocket вместо polling

## Безопасность

### Реализованные меры
- **JWT аутентификация** для всех API вызовов
- **SignalR аутентификация** через query параметры
- **Rate limiting** на уровне nginx
- **HTTPS only** для production
- **SQL injection защита** через EF Core
- **XSS защита** в веб-клиенте

### Потенциальные уязвимости
- **FCM токены** хранятся в plain text (можно шифровать)
- **Отсутствие API versioning** для backward compatibility
- **Неограниченный upload** (нужны лимиты на размер файлов)

## Вывод

May Messenger представляет собой хорошо спроектированную систему с современными технологиями и паттернами. Архитектура следует best practices, имеет хорошую разделение ответственности и поддерживает основные функции современного мессенджера. Основные сильные стороны - надежная доставка сообщений, real-time коммуникация и кросс-платформенная поддержка.