---
name: Messenger Mobile Improvements
overview: "План улучшения мобильного приложения Депеша: аудио через датчик приближения, улучшенный просмотр изображений, исправление двойных эмодзи, управление участниками групп и оптимизация работы с батареей Android."
todos:
  - id: fix-emoji
    content: Исправить двойную вставку эмодзи в message_input.dart
    status: completed
  - id: image-viewer
    content: Добавить double-tap zoom в fullscreen_image_viewer.dart
    status: completed
  - id: proximity-audio
    content: Реализовать переключение на earpiece при приближении к уху
    status: completed
  - id: backend-participants
    content: Добавить API для управления участниками группы в backend
    status: completed
  - id: mobile-participants
    content: Создать экран управления участниками группы в mobile app
    status: completed
    dependencies:
      - backend-participants
  - id: battery-optimization
    content: Добавить запрос исключения из оптимизации батареи Android
    status: completed
---

# План улучшений мобильного приложения Депеша

---

## 1. Аудио через датчик приближения (Earpiece Mode)

**Цель**: При поднесении телефона к уху автоматически переключать воспроизведение на разговорный динамик с уменьшенной громкостью.**Требуемые пакеты**:

- `proximity_sensor: ^1.0.5` — для определения приближения к уху
- `audio_session` (уже есть как зависимость `just_audio`) — для переключения audio route

**Ключевые изменения**:

1. Добавить зависимость в [`pubspec.yaml`](d:/_SOURCES/source/RareBooksServicePublic/_may_messenger_mobile_app/pubspec.yaml)
2. Создать сервис `ProximitySensorService` в `lib/data/services/`:

- Подписка на события датчика приближения
- Управление флагом "телефон у уха"

3. Модифицировать [`message_bubble.dart`](d:/_SOURCES/source/RareBooksServicePublic/_may_messenger_mobile_app/lib/presentation/widgets/message_bubble.dart):

- Добавить подписку на proximity sensor
- При приближении: переключить AudioSession на `.communication` mode (earpiece)
- При удалении: вернуть `.playback` mode (speaker)

4. Добавить разрешение в `AndroidManifest.xml`:
   ```xml
         <uses-feature android:name="android.hardware.sensor.proximity" android:required="false"/>
   ```


---

## 2. Улучшенный просмотр изображений (Double-tap и Pinch-to-Zoom)

**Текущее состояние**: [`fullscreen_image_viewer.dart`](d:/_SOURCES/source/RareBooksServicePublic/_may_messenger_mobile_app/lib/presentation/widgets/fullscreen_image_viewer.dart) уже использует `InteractiveViewer` с pinch-to-zoom, но отсутствует double-tap для увеличения/уменьшения.**Изменения**:

1. Добавить `GestureDetector` с `onDoubleTap`:

- При первом double-tap — zoom in до 2x в точке нажатия
- При повторном double-tap — zoom out до 1x (сброс)

2. Использовать `AnimationController` для плавной анимации масштабирования
3. Сохранить существующую логику swipe-to-dismiss (только при масштабе 1x)

---

## 3. Исправление двойных смайликов

**Проблема найдена** в [`message_input.dart`](d:/_SOURCES/source/RareBooksServicePublic/_may_messenger_mobile_app/lib/presentation/widgets/message_input.dart):

```dart
EmojiPicker(
  onEmojiSelected: _onEmojiSelected,     // <-- вставляет эмодзи
  textEditingController: _textController, // <-- EmojiPicker тоже вставляет эмодзи
),
```

Когда передается `textEditingController`, EmojiPicker автоматически вставляет эмодзи. Плюс вызывается `_onEmojiSelected`, который тоже вставляет — получается двойная вставка.**Исправление**: Убрать `onEmojiSelected` callback, оставив только `textEditingController`:

```dart
EmojiPicker(
  textEditingController: _textController,
),
```

---

## 4. Управление участниками группы

Это наиболее масштабная функция, требующая изменений как в backend, так и в mobile app.

### 4.1 Backend изменения

**Модификация модели** в [`ChatParticipant.cs`](d:/_SOURCES/source/RareBooksServicePublic/_may_messenger_backend/src/MayMessenger.Domain/Entities/ChatParticipant.cs):

```csharp
public class ChatParticipant
{
    public Guid ChatId { get; set; }
    public Guid UserId { get; set; }
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
    public bool IsOwner { get; set; } = false;    // <-- НОВОЕ: создатель группы
    public bool IsAdmin { get; set; } = false;
    // ...
}
```

**Новые API endpoints** в `ChatsController.cs`:| Endpoint | Метод | Описание ||----------|-------|----------|| `/api/chats/{chatId}/participants` | GET | Получить список участников с ролями || `/api/chats/{chatId}/participants` | POST | Добавить участников (только owner/admin) || `/api/chats/{chatId}/participants/{userId}` | DELETE | Удалить участника (только owner/admin) || `/api/chats/{chatId}/admins/{userId}` | POST | Назначить администратора (только owner) || `/api/chats/{chatId}/admins/{userId}` | DELETE | Снять администратора (только owner) |**Права доступа**:

- **Owner (создатель)**: добавление/удаление участников, удаление любых сообщений, назначение/снятие админов
- **Admin**: добавление/удаление участников (не может удалять сообщения других)
- **Member**: только чтение и отправка своих сообщений

### 4.2 Mobile App изменения

1. **Обновить модели** в `lib/data/models/`:

- Добавить `ParticipantRole` enum
- Обновить `chat_model.dart` для хранения информации о роли текущего пользователя

2. **Добавить API методы** в [`api_datasource.dart`](d:/_SOURCES/source/RareBooksServicePublic/_may_messenger_mobile_app/lib/data/datasources/api_datasource.dart):

- `getParticipants(chatId)`
- `addParticipants(chatId, userIds)`
- `removeParticipant(chatId, userId)`
- `setAdmin(chatId, userId, isAdmin)`

3. **Создать экран управления группой** `lib/presentation/screens/group_settings_screen.dart`:

- Список участников с их ролями
- Кнопки добавления/удаления (для owner/admin)
- Переключатель роли админа (только для owner)

4. **Обновить** [`chat_screen.dart`](d:/_SOURCES/source/RareBooksServicePublic/_may_messenger_mobile_app/lib/presentation/screens/chat_screen.dart):

- Добавить навигацию к экрану настроек группы при нажатии на info icon (для групповых чатов)

5. **SignalR события** для уведомления об изменениях состава группы

---

## 5. Оптимизация работы с батареей Android

**Текущее состояние**: FCM уже используется для push-уведомлений, что хорошо. Однако агрессивная оптимизация батареи (Doze mode, App Standby) может влиять на:

- Своевременную доставку push-уведомлений
- Работу SignalR при возврате из фона

**Рекомендуемые улучшения**:

### 5.1 Запрос исключения из оптимизации батареи

Добавить пакет и запрос разрешения:

```dart
// Пакет: disable_battery_optimization: ^1.1.1
// Или: optimize_battery: ^0.0.4
```

Добавить в `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

Показывать диалог при первом запуске с объяснением, почему это важно для доставки сообщений.

### 5.2 Улучшение FCM High Priority

Убедиться, что backend отправляет FCM с `priority: "high"` для Android — это обходит Doze mode.

### 5.3 WorkManager для фоновой синхронизации

Добавить `workmanager` пакет для периодической фоновой синхронизации статусов и непрочитанных сообщений:

```yaml
dependencies:
  workmanager: ^0.5.2
```

---

## Оценка сложности и приоритеты

| Задача | Сложность | Приоритет | Затрагивает backend ||--------|-----------|-----------|---------------------|| Исправление двойных эмодзи | Легко | Высокий | Нет || Улучшение просмотра изображений | Средне | Высокий | Нет || Аудио через датчик приближения | Средне | Средний | Нет || Управление участниками группы | Сложно | Средний | Да || Оптимизация батареи | Средне | Низкий | Частично |---