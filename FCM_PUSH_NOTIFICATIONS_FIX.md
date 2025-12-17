# Исправления Push-уведомлений (FCM)

## Дата: 18 декабря 2024

## Проблема
Когда мобильное приложение свернуто, сообщения не приходят и нет push-уведомлений.

## Корневая причина
1. **Background handler не показывал уведомления** - функция `_firebaseMessagingBackgroundHandler` только логировала, но не создавала локальные уведомления
2. **Foreground handler игнорировал сообщения** - метод `_handleForegroundMessage` не показывал уведомления
3. **Отсутствовали Android разрешения** - не было `POST_NOTIFICATIONS` и других необходимых разрешений
4. **Не инициализированы локальные уведомления** - FCM service не создавал Android notification channel

## Исправления

### 1. FCM Service (`lib/core/services/fcm_service.dart`)

#### Добавлен background handler с локальными уведомлениями:
```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('[FCM_BG] Handling background message: ${message.messageId}');
  
  // Show local notification
  const androidDetails = AndroidNotificationDetails(
    'messages_channel',
    'Messages',
    channelDescription: 'Notifications for new messages',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
  );
  
  final chatId = message.data['chatId'] as String?;
  await _localNotifications.show(
    chatId.hashCode,
    message.notification?.title ?? 'New Message',
    message.notification?.body ?? '',
    notificationDetails,
    payload: chatId,
  );
}
```

#### Добавлен foreground handler с условным показом:
```dart
void _handleForegroundMessage(RemoteMessage message) async {
  final chatId = message.data['chatId'] as String?;
  
  // Don't show notification if user is currently in this chat
  if (chatId != null && chatId == _currentChatId) {
    return;
  }
  
  // Show local notification
  await _localNotifications.show(...);
}
```

#### Добавлена инициализация локальных уведомлений и Android channel:
```dart
Future<void> initialize() async {
  // Initialize local notifications
  await _localNotifications.initialize(...);
  
  // Create Android notification channel
  const androidChannel = AndroidNotificationChannel(
    'messages_channel',
    'Messages',
    description: 'Notifications for new messages',
    importance: Importance.high,
  );
  
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);
}
```

#### Добавлено отслеживание текущего чата:
```dart
void setCurrentChat(String? chatId) {
  _currentChatId = chatId;
}
```

### 2. ChatScreen (`lib/presentation/screens/chat_screen.dart`)

Добавлено уведомление FCM service о текущем чате:

```dart
@override
void initState() {
  super.initState();
  Future.microtask(() async {
    // Уведомить FCM что пользователь в этом чате
    final fcmService = ref.read(fcmServiceProvider);
    fcmService.setCurrentChat(widget.chatId);
  });
}

@override
void dispose() {
  // Очистить текущий чат при выходе
  final fcmService = ref.read(fcmServiceProvider);
  fcmService.setCurrentChat(null);
  super.dispose();
}
```

### 3. AndroidManifest.xml

Добавлены необходимые разрешения и сервисы:

```xml
<!-- Permissions for notifications -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>

<!-- Intent filter for notification tap -->
<intent-filter>
    <action android:name="FLUTTER_NOTIFICATION_CLICK" />
    <category android:name="android.intent.category.DEFAULT" />
</intent-filter>

<!-- FCM Service -->
<service
    android:name="com.google.firebase.messaging.FirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

## Как работает система уведомлений

### 1. Приложение в foreground (открыто)
- SignalR получает сообщение в реальном времени
- Если пользователь **не в этом чате** → показывается локальное уведомление
- Если пользователь **в чате** → сообщение просто добавляется в UI

### 2. Приложение в background (свернуто)
- Firebase Cloud Messaging получает push от backend
- `_firebaseMessagingBackgroundHandler` создает локальное уведомление
- При тапе на уведомление вызывается `onMessageTap` → приложение открывается на нужном чате

### 3. Приложение убито (закрыто)
- Firebase Cloud Messaging все равно получает push
- Android показывает уведомление
- При тапе приложение запускается и открывает нужный чат

## Тестирование

### Шаг 1: Сборка и установка
```bash
cd _may_messenger_mobile_app
flutter clean
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Шаг 2: Проверка регистрации FCM токена
```bash
# Запустить логи
adb logcat | grep -E "FCM|firebase"

# В логах должно быть:
# [FCM] User granted permission
# [FCM] Token: <токен>
# FCM token registered successfully
```

### Шаг 3: Тестовые сценарии

#### Сценарий 1: Приложение открыто, но в другом чате
1. Открыть приложение и зайти в чат A
2. С другого устройства отправить сообщение в чат B
3. **Ожидается**: Локальное уведомление о новом сообщении в чате B

#### Сценарий 2: Приложение свернуто
1. Открыть приложение, затем свернуть (Home button)
2. С другого устройства отправить сообщение
3. **Ожидается**: Push-уведомление в шторке
4. Тап на уведомление → приложение открывается на нужном чате

#### Сценарий 3: Приложение полностью закрыто
1. Закрыть приложение (swipe up из Recent Apps)
2. С другого устройства отправить сообщение
3. **Ожидается**: Push-уведомление в шторке
4. Тап на уведомление → приложение запускается и открывает нужный чат

### Шаг 4: Проверка логов

#### Успешная доставка в background:
```
[FCM_BG] Handling background message: <messageId>
[FCM_BG] Title: Новое сообщение от <sender>
[FCM_BG] Body: <message text>
[FCM_BG] Data: {chatId: <chatId>, messageId: <messageId>}
[FCM_BG] Local notification shown
```

#### Успешная доставка в foreground:
```
[FCM_FG] Foreground message: Новое сообщение от <sender>
[FCM_FG] Data: {chatId: <chatId>, messageId: <messageId>}
[FCM_FG] Local notification shown
```

#### Подавление уведомления (пользователь в чате):
```
[FCM] Current chat set to: <chatId>
[FCM_FG] Foreground message: ...
[FCM_FG] User in current chat, not showing notification
```

## Диагностика на backend

Проверить отправку push с сервера:
```bash
GET https://messenger.rare-books.ru/api/diagnostics/message/<messageId>
```

В ответе должно быть:
```json
{
  "id": "<messageId>",
  "status": 1,  // Sent
  "deliveryReceipts": [...]
}
```

Проверить логи сервера:
```
Sending push notification to user <userId>, 1 tokens
```

## Известные ограничения

1. **Android 13+** требует явного разрешения на уведомления - пользователь должен разрешить при первом запуске
2. **Battery optimization** может блокировать фоновую доставку - нужно отключить для приложения
3. **Data Saver** может ограничивать фоновую сеть
4. **FCM токены** истекают - нужна периодическая перерегистрация (TODO)

## TODO для будущих улучшений

- [ ] Добавить периодическое обновление FCM токена
- [ ] Добавить группировку уведомлений по чатам
- [ ] Добавить действия в уведомлениях (reply, mark as read)
- [ ] Добавить кастомный звук для уведомлений
- [ ] Обработка случаев когда FCM токен не зарегистрирован

