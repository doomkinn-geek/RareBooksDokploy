---
name: Multi-fix Mobile App
overview: "Комплексное исправление: надежный статус онлайн, локальное хранение медиа, копирование телефона, улучшение голосования и iOS share."
todos:
  - id: presence-monitor-service
    content: "Бэкенд: создать PresenceMonitorService для автоматического offline по heartbeat"
    status: completed
  - id: improve-lifecycle
    content: "Клиент: улучшить обработку lifecycle для надежного online/offline"
    status: completed
  - id: background-image-download
    content: Добавить фоновую загрузку изображений при получении сообщения
    status: completed
  - id: copy-phone
    content: Добавить копирование телефона в буфер обмена в профиле
    status: completed
  - id: poll-votes-api
    content: "Бэкенд: API для получения списка голосов неанонимного опроса"
    status: completed
  - id: poll-votes-widget
    content: "Клиент: виджет отображения кто как проголосовал"
    status: completed
  - id: ios-share-fix
    content: Исправить iOS share с sharePositionOrigin
    status: completed
---

# Комплексное исправление мобильного приложения

## 1. Надежная система статусов онлайн/офлайн

### Проблема

Пользователь остается "онлайн" после сворачивания/закрытия приложения, потому что:

- При аварийном закрытии `goOffline()` не вызывается
- SignalR disconnect может не сработать при потере сети
- Нет серверного таймаута для проверки heartbeat

### Решение

**Бэкенд**: Добавить HostedService для автоматической проверки heartbeat:

- [`_may_messenger_backend/src/MayMessenger.API/Services/PresenceMonitorService.cs`](_may_messenger_backend/src/MayMessenger.API/Services/PresenceMonitorService.cs) - новый файл
- Каждые 60 секунд проверять пользователей где `IsOnline = true` и `LastHeartbeatAt < UtcNow - 2 min`
- Помечать таких пользователей как offline и отправлять SignalR уведомление

**Клиент**: Улучшить обработку lifecycle в [`_may_messenger_mobile_app/lib/main.dart`](_may_messenger_mobile_app/lib/main.dart):

- Использовать `WidgetsBindingObserver.didChangeAppLifecycleState`
- При `paused`/`inactive`/`detached` вызывать `goOffline()` синхронно
- При `resumed` мгновенно вызывать `goOnline()` + SignalR reconnect

---

## 2. Надежное локальное хранение медиа

### Текущее состояние

- [`_may_messenger_mobile_app/lib/data/services/image_storage_service.dart`](_may_messenger_mobile_app/lib/data/services/image_storage_service.dart) - есть, но не используется автоматически
- Аудио скачивается при воспроизведении

### Решение

В [`_may_messenger_mobile_app/lib/presentation/providers/messages_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/messages_provider.dart):

- При получении сообщения с изображением/аудио - запускать фоновую загрузку
- Добавить метод `_downloadImageInBackground(message)` аналогично существующему `_downloadAudioInBackground`
- При отображении изображения сначала проверять локальный кэш

---

## 3. Копирование телефона в профиле

### Изменения в [`_may_messenger_mobile_app/lib/presentation/screens/user_profile_screen.dart`](_may_messenger_mobile_app/lib/presentation/screens/user_profile_screen.dart):

- Обернуть `_buildInfoCard` для телефона в `GestureDetector` или `InkWell`
- При нажатии:
```dart
Clipboard.setData(ClipboardData(text: phoneNumber));
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Телефон скопирован в буфер обмена')),
);
```


---

## 4. Улучшение системы голосования

### 4.1 Виджет отображения голосов (для неанонимного голосования)

Добавить в [`_may_messenger_mobile_app/lib/presentation/widgets/poll_widget.dart`](_may_messenger_mobile_app/lib/presentation/widgets/poll_widget.dart):

- Кнопка "Посмотреть голоса" (только для неанонимных опросов)
- Модальное окно со списком: кто какой вариант выбрал
- Получение данных через API

### 4.2 Бэкенд: эндпоинт для получения голосов

В [`_may_messenger_backend/src/MayMessenger.API/Controllers/PollsController.cs`](_may_messenger_backend/src/MayMessenger.API/Controllers/PollsController.cs):

- Добавить `GET /api/polls/{pollId}/votes` - возвращает список голосов для неанонимного опроса
- Для анонимных опросов возвращать 403

### 4.3 Стилизация

- Poll widget уже использует `theme.outgoingTextColor` / `theme.incomingTextColor`
- Убедиться что все цвета берутся из темы

---

## 5. iOS Share - исправление ошибки

### Проблема

```
PlatformException(error, sharePositionOrigin: argument must be set, {{0, 0}, {0, 0}} must be non-zero...
```

На iOS/iPad нужен `sharePositionOrigin` для позиционирования share sheet.

### Решение

В [`_may_messenger_mobile_app/lib/core/services/share_send_service.dart`](_may_messenger_mobile_app/lib/core/services/share_send_service.dart):

```dart
import 'dart:io';
import 'package:flutter/material.dart';

Future<ShareResult> shareText(String text, {String? subject, Rect? sharePositionOrigin}) async {
  return Share.share(
    text,
    subject: subject,
    sharePositionOrigin: Platform.isIOS ? (sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100)) : null,
  );
}
```

Также обновить все места вызова share, передавая позицию кнопки через `RenderBox`:

```dart
final box = context.findRenderObject() as RenderBox;
final sharePosition = box.localToGlobal(Offset.zero) &amp; box.size;
shareSendService.shareText(text, sharePositionOrigin: sharePosition);
```

---

## Файлы для изменения

| Файл | Изменение |

|------|-----------|

| `_may_messenger_backend/.../Services/PresenceMonitorService.cs` | Новый: background service для heartbeat |

| `_may_messenger_backend/.../Program.cs` | Регистрация PresenceMonitorService |

| `_may_messenger_mobile_app/.../main.dart` | Улучшение lifecycle для статуса |

| `_may_messenger_mobile_app/.../messages_provider.dart` | Фоновая загрузка изображений |

| `_may_messenger_mobile_app/.../user_profile_screen.dart` | Копирование телефона |

| `_may_messenger_mobile_app/.../poll_widget.dart` | Виджет голосов |

| `_may_messenger_backend/.../PollsController.cs` | API для получения голосов |

| `_may_messenger_mobile_app/.../share_send_service.dart` | iOS share fix |

| `_may_messenger_mobile_app/.../message_bubble.dart` | Передача sharePositionOrigin |