---
name: UI и UX улучшения
overview: "Исправление трёх проблем: адаптивное меню выбора сообщений, индикатор прогресса загрузки для медиа, мгновенное позиционирование сообщений влево/вправо."
todos:
  - id: adaptive-menu
    content: Сделать меню выбора сообщений адаптивным с PopupMenu для узких экранов
    status: completed
  - id: upload-progress-model
    content: Добавить поле uploadProgress в Message и обновлять через API callback
    status: completed
  - id: upload-progress-ui
    content: Отобразить прогресс загрузки в message_bubble для изображений, аудио и файлов
    status: completed
  - id: fix-isMe-delay
    content: Исправить задержку isMe, используя profileState.userId вместо profile?.id
    status: completed
---

# Исправление UI/UX проблем

## Проблема 1: Меню не помещается на экране

**Причина:** В [`message_selection_app_bar.dart`](c:\rarebooks\_may_messenger_mobile_app\lib\presentation\widgets\message_selection_app_bar.dart) все 7-8 иконок добавляются в `actions` без адаптации к ширине экрана.**Решение:** Использовать `LayoutBuilder` для определения доступной ширины и группировать менее важные иконки в `PopupMenuButton`, когда места недостаточно.---

## Проблема 2: Нет индикатора прогресса загрузки

**Причина:** Модель `Message` не содержит поля `uploadProgress`, и виджеты не отображают прогресс при отправке изображений/аудио/файлов.**Решение:**

1. Добавить поле `uploadProgress` (0.0-1.0) в [`message_model.dart`](c:\rarebooks\_may_messenger_mobile_app\lib\data\models\message_model.dart)
2. Обновлять прогресс через `onSendProgress` callback в [`api_datasource.dart`](c:\rarebooks\_may_messenger_mobile_app\lib\data\datasources\api_datasource.dart)
3. Передавать обновления в [`messages_provider.dart`](c:\rarebooks\_may_messenger_mobile_app\lib\presentation\providers\messages_provider.dart)
4. Отображать `LinearProgressIndicator` или круговой прогресс в [`message_bubble.dart`](c:\rarebooks\_may_messenger_mobile_app\lib\presentation\widgets\message_bubble.dart) для сообщений со статусом `sending`

---

## Проблема 3: Задержка позиционирования сообщений лево/право

**Причина:** В [`message_bubble.dart`](c:\rarebooks\_may_messenger_mobile_app\lib\presentation\widgets\message_bubble.dart:1218) используется:

```dart
final isMe = (currentUserId != null && widget.message.senderId == currentUserId) ||
             (widget.message.isLocalOnly == true);
```

Но `currentUserId` берётся из `profileState.profile?.id`, который может быть `null` при начальной загрузке, хотя `cachedUserId` уже доступен.**Решение:** Изменить на использование `profileState.userId` (который уже есть - это getter возвращающий `profile?.id ?? cachedUserId`):

```dart
final currentUserId = profileState.userId; // Вместо profileState.profile?.id


```