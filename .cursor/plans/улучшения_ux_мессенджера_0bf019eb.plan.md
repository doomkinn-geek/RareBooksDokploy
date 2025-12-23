---
name: Улучшения UX мессенджера
overview: "План включает 8 улучшений: исправление индикатора набора, автопрокрутку, расширенный поиск, оптимизацию просмотра изображений, исправление race condition статуса \"прослушано\", кнопку прокрутки вниз, улучшение индикатора загрузки аудио и перегруппировку кнопок UI с добавлением emoji picker."
todos:
  - id: fix-typing-indicator
    content: Исправить индикатор "печатает" - показывать только в нужном чате
    status: completed
  - id: auto-scroll-new-message
    content: Добавить автопрокрутку при получении нового сообщения
    status: completed
  - id: extend-search
    content: Расширить поиск - добавить чаты/группы и контакты из телефонной книги
    status: completed
  - id: fix-image-viewer-gestures
    content: Оптимизировать жесты в просмотрщике изображений (pinch vs swipe)
    status: completed
  - id: fix-played-status-race
    content: Исправить race condition для статуса "прослушано"
    status: completed
  - id: add-scroll-to-bottom-fab
    content: Добавить кнопку прокрутки вниз (FAB)
    status: completed
  - id: audio-loading-indicator
    content: Перенести индикатор загрузки аудио в виджет
    status: completed
  - id: ui-buttons-emoji
    content: Перегруппировать кнопки UI + добавить emoji picker
    status: completed
---

# Улучшения UX мессенджера

## 1. Исправление индикатора "печатает"

**Проблема**: Индикатор набора текста показывается во всех чатах, а не только в том, где пользователь печатает.**Причина**: В [`signalr_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart) строки 266-286 при получении события `UserTyping` обновляется состояние для всех чатов:

```dart
for (final chat in chatsState.chats) {
  _ref.read(typingProvider.notifier).setUserTyping(
    chat.id, userId, userName, isTyping
  );
}
```

**Решение**: Backend отправляет `chatId` в событии `UserTyping`. Нужно использовать его вместо итерации по всем чатам.**Файлы**:

- [`signalr_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart) - обработчик `onUserTyping`
- [`signalr_service.dart`](_may_messenger_mobile_app/lib/data/datasources/signalr_service.dart) - если нужно добавить chatId в callback

---

## 2. Автопрокрутка при получении нового сообщения

**Проблема**: Чат не прокручивается вниз при получении нового сообщения.**Решение**: Добавить в [`chat_screen.dart`](_may_messenger_mobile_app/lib/presentation/screens/chat_screen.dart) реактивное отслеживание количества сообщений и автопрокрутку если пользователь находится близко к низу списка.

```dart
// В build() добавить ref.listen для messagesProvider
ref.listen(messagesProvider(widget.chatId), (previous, next) {
  if (previous?.messages.length != next.messages.length) {
    // Автопрокрутка если близко к низу
    _scrollToBottomIfNeeded();
  }
});
```

---

## 3. Расширенный поиск

**Проблема**: Поиск работает только по контактам и сообщениям на сервере, не ищет по чатам и группам.**Решение**: Расширить [`search_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/search_provider.dart) и [`search_screen.dart`](_may_messenger_mobile_app/lib/presentation/screens/search_screen.dart):

1. Добавить `chatResults` в `SearchState` для найденных чатов/групп
2. Добавить локальный поиск по `chatsProvider` (название чата/группы)
3. Добавить секцию "Чаты" в результаты поиска
4. При нажатии на чат/группу - открывать `ChatScreen`

---

## 4. Оптимизация просмотра изображений (pinch-to-zoom vs swipe)

**Проблема**: При попытке увеличить картинку срабатывает жест "смахнуть".**Причина**: В [`fullscreen_image_viewer.dart`](_may_messenger_mobile_app/lib/presentation/widgets/fullscreen_image_viewer.dart) `GestureDetector` обрабатывает вертикальные свайпы, а `InteractiveViewer` внутри - pinch. Конфликт жестов.**Решение**: Использовать `InteractiveViewer` с `onInteractionUpdate` для отслеживания scale и отключать swipe-to-dismiss когда идет увеличение:

```dart
// Отслеживать текущий scale
double _currentScale = 1.0;

// В GestureDetector проверять: если scale > 1, не обрабатывать swipe
onVerticalDragUpdate: _currentScale <= 1.0 ? (details) {...} : null,
```

---

## 5. Race condition для статуса "прослушано"

**Проблема**: После выхода из чата статус "прослушано" сбрасывается.**Причина**: В [`messages_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/messages_provider.dart) метод `_mergeMessagesPreservingPlayedStatus` сохраняет статус `played` только при сравнении с кэшем, но при полной перезагрузке данные с сервера перезаписывают локальный статус.**Решение**:

1. Убедиться что статус `played` корректно сохраняется на сервере через REST API
2. Добавить логирование для отладки потока обновления статуса
3. Проверить что `markAudioAsPlayed` вызывает `_unitOfWork.SaveChangesAsync()` на backend

---

## 6. Кнопка прокрутки вниз (FAB)

**Проблема**: Нет способа быстро вернуться к последнему сообщению.**Решение**: Добавить в [`chat_screen.dart`](_may_messenger_mobile_app/lib/presentation/screens/chat_screen.dart) FloatingActionButton:

1. Отслеживать позицию скролла
2. Показывать FAB когда пользователь прокрутил вверх более чем на 500px от низа
3. При нажатии - анимированная прокрутка к низу
```dart
Positioned(
  bottom: 80, right: 16,
  child: AnimatedOpacity(
    opacity: _showScrollToBottomButton ? 1.0 : 0.0,
    child: FloatingActionButton.small(
      onPressed: _scrollToBottom,
      child: Icon(Icons.keyboard_arrow_down),
    ),
  ),
),
```


---

## 7. Индикатор загрузки аудио в виджете

**Проблема**: SnackBar "Загрузка аудио..." мешает вводу сообщения.**Решение**: Заменить SnackBar в [`message_bubble.dart`](_may_messenger_mobile_app/lib/presentation/widgets/message_bubble.dart) строка 129 на индикатор внутри самого аудио-виджета:

1. Добавить состояние `_isDownloading`
2. Показывать `CircularProgressIndicator` вместо кнопки play во время загрузки
3. Убрать все `ScaffoldMessenger.showSnackBar` для загрузки аудио

---

## 8. Перегруппировка кнопок UI + Emoji Picker

**Проблема**: Кнопки изображения слева, нужна кнопка emoji.**Решение**: Изменить [`message_input.dart`](_may_messenger_mobile_app/lib/presentation/widgets/message_input.dart):

1. Добавить зависимость `emoji_picker_flutter` в `pubspec.yaml`
2. Слева от поля ввода - кнопка emoji (открывает панель снизу)
3. Справа после поля ввода - одна кнопка attachment (popup menu: камера/галерея)
4. Справа - кнопка send/mic

**Новая структура UI**:

```javascript
[emoji] [text field] [attachment] [send/mic]
```