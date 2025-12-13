# Debug Mode - Message Delivery Investigation

## Hypotheses

**H1: SignalR handler не получает события от backend**
- Проверка: Логи `[H1]` покажут, срабатывает ли `onReceiveMessage` в Flutter
- Ожидаем: Логи `[H1,H2-CRITICAL] ReceiveMessage event FIRED` при отправке из web

**H2: SignalR соединение мобильного приложения не активно**
- Проверка: Логи `[H2]` покажут состояние соединения
- Ожидаем: `OnConnectedAsync` вызывается, `state: Connected`, `connectionId` присутствует

**H3: Backend не вызывает SendPushNotificationsAsync или падает внутри**
- Проверка: Логи `[H3-*]` покажут весь флоу push уведомлений
- Ожидаем: `[H3-ENTRY]`, `[H3-FIREBASE]`, `[H3-PUSH]`, `[H3-SEND]`, `[H3-RESULT]`

**H4: FCM токен не зарегистрирован для мобильного пользователя**
- Проверка: Логи `[H4-TOKENS]` и `[H4-NO-TOKENS]` покажут количество токенов
- Ожидаем: Либо токены найдены, либо `NO active FCM tokens`

**H5: Messages provider не обновляется (проблема state management)**
- Проверка: Логи `[H1]` покажут, добавляется ли сообщение в provider
- Ожидаем: `Message added to provider` или `Error accessing messages provider`

## Instrumentation Added

### Backend (C#)
- `MessagesController.cs`: 15+ логов в `SendPushNotificationsAsync`
  - Entry/exit, Firebase init check, participant loop, token retrieval, send results, errors

### Flutter (Dart)
- `signalr_service.dart`: Логи подключения, регистрации handler, получения событий
- `signalr_provider.dart`: Уже имелись логи обработки сообщений

## Deployment Steps

1. **Backend:**
   ```bash
   cd /root/rarebooks
   git pull origin master
   docker compose build maymessenger_backend
   docker compose up -d maymessenger_backend
   ```

2. **Mobile App:**
   ```bash
   cd _may_messenger_mobile_app
   flutter build apk --release
   # Install APK on device
   ```

## Log Retrieval

Логи будут доступны через API endpoint:
```
https://messenger.rare-books.ru/api/Diagnostics/logs
```

## Expected Log Flow (Normal Case)

### When sending from Web → Mobile:

**Backend:**
1. `[H1,H4] REST SendMessage called`
2. `[H1,H4] Message saved to DB`
3. `[H1,H4-FIX] SignalR notification sent to user X`
4. `[H3-ENTRY] SendPushNotificationsAsync called`
5. `[H3-FIREBASE] Firebase IS initialized`
6. `[H4-TOKENS] Retrieved N FCM tokens for user X`
7. `[H3-PUSH] Sending push to user X`
8. `[H3-SEND] Calling FirebaseService.SendNotificationAsync`
9. `[H3-RESULT] Push send result: true/false`

**Mobile (via LoggerService → API):**
1. `[H1,H2-CRITICAL] ReceiveMessage event FIRED from backend`
2. `[H1,H2] Message parsed successfully`
3. `[H1,H2] Callback executed`
4. `[H1] Message added to provider`

## Analysis Points

1. If no `[H1,H2-CRITICAL]` logs → SignalR not firing (H1/H2 CONFIRMED)
2. If no `[H3-ENTRY]` logs → Push method not called (H3 CONFIRMED)
3. If `[H4-NO-TOKENS]` → FCM not registered (H4 CONFIRMED)
4. If `[H1] Error accessing messages provider` → State issue (H5 CONFIRMED)
