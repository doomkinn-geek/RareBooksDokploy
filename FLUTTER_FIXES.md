# Исправления Flutter приложения

## Проблема: Сообщения не отображаются в мобильном приложении

### Симптомы
1. При отправке сообщения из web клиента → сообщение не появляется в Flutter приложении
2. При отправке сообщения из Flutter приложения → сообщение не появляется в самом Flutter приложении (но приходит на web клиент)

### Причины

#### 1. Riverpod Family Provider не сохраняет состояние
`messagesProvider` использует `StateNotifierProvider.family<>`, который создает отдельный экземпляр для каждого `chatId`. По умолчанию, когда пользователь покидает экран чата, Riverpod может dispose этот провайдер, **даже без явного `autoDispose`**.

#### 2. SignalR отправляет сообщения, но провайдер может не существовать
Когда приходит сообщение через SignalR:
```dart
_ref.read(messagesProvider(message.chatId).notifier).addMessage(message);
```
Если провайдер для этого `chatId` не был создан (пользователь не открывал чат), Riverpod создаст новый экземпляр, но он может быть сразу disposed.

#### 3. addMessage не проверял, для какого чата сообщение
Метод `addMessage` в `MessagesNotifier` не проверял, соответствует ли `chatId` сообщения текущему `chatId` провайдера.

### Решения

#### 1. Добавлен `ref.keepAlive()` в messagesProvider
```dart
final messagesProvider = StateNotifierProvider.family<MessagesNotifier, MessagesState, String>(
  (ref, chatId) {
    // Keep the provider alive even when not used
    ref.keepAlive();
    return MessagesNotifier(ref.read(messageRepositoryProvider), chatId);
  },
);
```

**Эффект**: Провайдер сохраняет состояние даже когда пользователь не на экране чата.

#### 2. Улучшена обработка ошибок в signalr_provider.dart
```dart
try {
  _ref.read(messagesProvider(message.chatId).notifier).addMessage(message);
  _logger.debug('signalr_provider.onReceiveMessage.added', '[H1] Message added to provider', {'messageId': message.id, 'chatId': message.chatId});
} catch (e) {
  _logger.error('signalr_provider.onReceiveMessage.providerError', '[H1] Error accessing messages provider', {'error': e.toString(), 'messageId': message.id, 'chatId': message.chatId});
  // Provider might not be initialized yet - that's OK, message will be loaded from API when chat opens
}
```

**Эффект**: 
- Добавлено логирование для диагностики
- Разделена обработка ошибок для провайдера и уведомлений
- Уведомления показываются независимо от состояния провайдера

#### 3. Добавлена проверка chatId в addMessage
```dart
void addMessage(Message message) {
  _logger.debug('messages_provider.addMessage.entry', '[H1] addMessage called', {'messageId': message.id, 'chatId': message.chatId, 'currentChatId': chatId, 'currentCount': '${state.messages.length}'});
  
  // Проверяем, что сообщение для этого чата
  if (message.chatId != chatId) {
    _logger.debug('messages_provider.addMessage.wrongChat', '[H1] Message for different chat, ignoring', {'messageId': message.id, 'messageChatId': message.chatId, 'currentChatId': chatId});
    return;
  }
  
  // ... rest of the code
}
```

**Эффект**: Гарантируется, что сообщения добавляются только в правильный провайдер.

## Тестирование

### Сценарий 1: Отправка из web → Flutter
1. Откройте Flutter приложение, откройте чат
2. В web клиенте отправьте сообщение в тот же чат
3. **Ожидается**: Сообщение появится в Flutter приложении в реальном времени

### Сценарий 2: Отправка из Flutter → Flutter
1. Откройте Flutter приложение, откройте чат
2. Отправьте сообщение
3. **Ожидается**: Сообщение появится в списке сообщений

### Сценарий 3: Офлайн сообщения
1. Откройте Flutter приложение, НЕ открывайте чат
2. В web клиенте отправьте несколько сообщений
3. Откройте чат в Flutter
4. **Ожидается**: Все сообщения загрузятся через API (не только через SignalR)

## Логирование

В коде добавлены метки `[H1]`, `[H2]`, `[H3]`, `[H4]`, `[H5]` для отслеживания потока сообщений:

- **[H1]**: Получение сообщения через SignalR и добавление в UI
- **[H2]**: JoinChat / OnConnectedAsync в SignalR
- **[H3]**: Отправка текстового сообщения
- **[H4]**: Отправка аудио сообщения
- **[H5]**: Подключение к SignalR

### Просмотр логов
```bash
# В Flutter приложении логи выводятся в консоль
flutter logs

# В backend логи доступны через /api/diagnostics
curl https://messenger.rare-books.ru/api/diagnostics
```

## Дополнительные улучшения (опционально)

### 1. Глобальное хранилище сообщений
Вместо family provider можно использовать один глобальный провайдер с Map<chatId, List<Message>>:

```dart
final allMessagesProvider = StateNotifierProvider<AllMessagesNotifier, Map<String, List<Message>>>((ref) {
  return AllMessagesNotifier();
});

// Отдельный провайдер для фильтрации по chatId
final chatMessagesProvider = Provider.family<List<Message>, String>((ref, chatId) {
  final allMessages = ref.watch(allMessagesProvider);
  return allMessages[chatId] ?? [];
});
```

### 2. Персистентное хранилище
Использовать Hive или SharedPreferences для кеширования сообщений:

```dart
@override
void addMessage(Message message) {
  // Add to state
  state = state.copyWith(messages: [...state.messages, message]);
  
  // Save to local storage
  _localDataSource.cacheMessages(chatId, state.messages);
}
```

### 3. Оптимизация SignalR reconnect
Добавить автоматический reconnect при потере соединения:

```dart
_hubConnection?.onreconnecting((error) {
  _logger.debug('signalr.reconnecting', 'Reconnecting...', {'error': error});
});

_hubConnection?.onreconnected((connectionId) {
  _logger.debug('signalr.reconnected', 'Reconnected', {'connectionId': connectionId});
  // Rejoin all chats
});
```

## Деплой

```bash
# На сервере
cd /root/rarebooks
git pull origin master

# Пересборка не требуется для Flutter (изменения только в коде)
# Но если нужно собрать новый APK:
cd _may_messenger_mobile_app
flutter build apk --release
```

## Статус
- ✅ Добавлен `ref.keepAlive()` в messagesProvider
- ✅ Улучшена обработка ошибок в signalr_provider
- ✅ Добавлена проверка chatId в addMessage
- ✅ Добавлено детальное логирование
- ⏳ Требуется тестирование на реальных устройствах
