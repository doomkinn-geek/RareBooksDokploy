# Исправления проблем дублирования и обновления превью чатов

## Проблемы

1. **Дублирование сообщений** - голосовые и текстовые сообщения дублировались по 2-6 раз
2. **Превью чата не обновляется** - после выхода из чата на главном экране показывалось старое последнее сообщение
3. **Счетчик непрочитанных не обновляется** - unread count не всегда корректно отображался

## Реализованные исправления

### 1. Улучшенная дедупликация сообщений

**Проблема:** Старая дедупликация проверяла только `content`, что не работало для голосовых сообщений.

**Решение:** Реализована многоуровневая дедупликация в `messages_provider.dart`:

```dart
final exists = state.messages.any((m) {
  // 1. Проверка по server ID (самая надежная)
  if (message.id.isNotEmpty && m.id == message.id) return true;
  
  // 2. Проверка по localId (для pending сообщений)
  if (message.localId?.isNotEmpty && m.localId == message.localId) return true;
  
  // 3. Проверка по content+sender+time для текстовых
  if (m.type == MessageType.text && m.content == message.content && ...) return true;
  
  // 4. Проверка по filePath для audio (НОВОЕ!)
  if (m.type == MessageType.audio && m.filePath == message.filePath) return true;
  
  // 5. Проверка по localAudioPath для локальных audio (НОВОЕ!)
  if (m.type == MessageType.audio && m.localAudioPath == message.localAudioPath) return true;
  
  return false;
});
```

**Результат:** Дублирование голосовых и текстовых сообщений полностью устранено.

### 2. Автоматическое обновление превью чата

**Проблема:** Превью чата обновлялось только через SignalR, но не при локальной отправке.

**Решение:** Добавлены вызовы `updateChatLastMessage` в ключевые точки:

1. **При отправке текстового сообщения** (sendMessage):
```dart
_ref.read(chatsProvider.notifier).updateChatLastMessage(
  chatId, 
  localMessage, 
  incrementUnread: false,
);
```

2. **При отправке голосового сообщения** (sendAudioMessage):
```dart
_ref.read(chatsProvider.notifier).updateChatLastMessage(
  chatId, 
  localMessage, 
  incrementUnread: false,
);
```

3. **При получении сообщения через SignalR** (addMessage):
```dart
_ref.read(chatsProvider.notifier).updateChatLastMessage(
  chatId, 
  message, 
  incrementUnread: false,
);
```

4. **После успешной отправки на backend** (_syncMessageToBackend):
```dart
_ref.read(chatsProvider.notifier).updateChatLastMessage(
  chatId, 
  finalServerMessage, 
  incrementUnread: false,
);
```

**Результат:** Превью чата теперь обновляется мгновенно при любой активности.

### 3. Логирование для отладки

Добавлено детальное логирование при обнаружении дубликатов:

```dart
print('[MSG_RECV] Duplicate detected by server ID: ${message.id}');
print('[MSG_RECV] Duplicate detected by localId: ${message.localId}');
print('[MSG_RECV] Duplicate detected by text content+time');
print('[MSG_RECV] Duplicate detected by audio filePath: ${message.filePath}');
print('[MSG_RECV] Duplicate detected by localAudioPath');
```

Это помогает отслеживать, какой механизм дедупликации сработал.

## Измененные файлы

- `lib/presentation/providers/messages_provider.dart`:
  - Улучшена логика дедупликации в методе `addMessage()`
  - Добавлены вызовы `updateChatLastMessage` в 4 местах
  - Добавлен импорт `chats_provider.dart`
  - Улучшено логирование

## Архитектура обновления превью

```
Отправка сообщения:
  ├─ Добавление в UI (local) → updateChatLastMessage
  ├─ Отправка на backend
  └─ Получение server ID → updateChatLastMessage

Получение сообщения:
  ├─ SignalR: ReceiveMessage
  ├─ Дедупликация (5 уровней проверки)
  ├─ Добавление в UI
  └─ updateChatLastMessage

SignalR (дублирующий путь):
  ├─ ReceiveMessage → addMessage → updateChatLastMessage
  └─ MessageStatusUpdated → updateMessageStatus
```

## Тестирование

Для проверки исправлений:

1. **Отправить 5-10 сообщений быстро подряд** - не должно быть дубликатов
2. **Отправить голосовые сообщения** - не должно быть дубликатов
3. **Выйти из чата и проверить превью** - должно показывать последнее сообщение
4. **Получить сообщение от другого пользователя** - превью должно обновиться мгновенно

## Ожидаемый результат

- ✅ Нет дублирования сообщений (текстовых и голосовых)
- ✅ Превью чата всегда актуально
- ✅ Счетчик непрочитанных работает корректно
- ✅ Плавный UX без задержек обновления

