---
name: Web Client Local-First Upgrade
overview: "Привести веб-клиент May Messenger в соответствие с мобильным приложением: внедрить local-first архитектуру с гарантированной доставкой сообщений, правильным отслеживанием статусов и offline поддержкой."
todos:
  - id: web-indexeddb
    content: Create IndexedDB storage service for web client
    status: completed
  - id: web-outbox
    content: Create outbox repository for pending messages
    status: completed
    dependencies:
      - web-indexeddb
  - id: web-types
    content: Update message types with localId and isLocalOnly fields
    status: completed
  - id: web-local-first
    content: Implement local-first sending in messageStore
    status: completed
    dependencies:
      - web-outbox
      - web-types
  - id: web-delivery-confirm
    content: Add auto delivery confirmation to SignalR service
    status: completed
  - id: web-status-polling
    content: Create status polling fallback service
    status: completed
  - id: web-offline-sync
    content: Create offline sync service with retry logic
    status: completed
    dependencies:
      - web-outbox
  - id: web-ui-updates
    content: Update MessageBubble with status icons and retry button
    status: completed
  - id: web-cache-strategy
    content: Implement cache-first loading strategy
    status: completed
---

# Web Client: Local-First Message Delivery System

## Обзор

Внедрить в веб-клиент те же улучшения, что были реализованы в мобильном приложении: local-first отправку сообщений, outbox queue для pending сообщений, автоматическую подтверждение доставки, status polling fallback и offline поддержку.

## Текущие проблемы веб-клиента

**messageStore.ts**:

- Отправляет сообщение через API и ждет SignalR для отображения
- Нет оптимистичного UI обновления
- Нет очереди для offline сообщений

**signalRService.ts**:

- Нет автоматического подтверждения доставки
- Нет fallback механизма при отключении

**Отсутствующие компоненты**:

- Нет outbox repository для pending сообщений
- Нет offline sync service
- Нет status polling fallback
- Нет локального хранилища (IndexedDB/localStorage)

## План реализации

### Фаза 1: Локальное хранилище и Outbox

**1.1. Создать IndexedDB Storage Service**

- Файл: `src/services/indexedDBStorage.ts`
- Методы для работы с IndexedDB
- Хранение pending сообщений и кэша

**1.2. Создать Outbox Repository**

- Файл: `src/repositories/outboxRepository.ts`
- Аналог мобильного `OutboxRepository`
- Хранение pending сообщений с temp ID
- Отслеживание sync состояния: `localOnly`, `syncing`, `synced`, `failed`

**1.3. Обновить типы сообщений**

- Файл: `src/types/chat.ts`
- Добавить `localId?: string`
- Добавить `isLocalOnly?: boolean`
- Добавить интерфейс `PendingMessage`

### Фаза 2: Local-First отправка (Web)

**2.1. Обновить messageStore**

- Файл: `src/stores/messageStore.ts`
- Реализовать оптимистичное обновление UI
- Создать сообщение с temp UUID
- Отобразить немедленно со статусом `Sending`
- Сохранить в outbox
- Отправить в backend асинхронно
- Обработать успех/ошибку

**2.2. Обновить MessageBubble**

- Файл: `src/components/message/MessageBubble.tsx`
- Отображать правильные иконки статусов
- Показывать кнопку retry для failed сообщений

### Фаза 3: Автоматическое подтверждение доставки

**3.1. Обновить SignalR Service**

- Файл: `src/services/signalRService.ts`
- При получении сообщения автоматически вызывать `MessageDelivered`
- Добавить метод `markMessageAsDelivered`
- Пропускать подтверждение для своих сообщений

**3.2. Добавить batch read receipts**

- Новый метод в `messageApi.ts`: `batchMarkAsRead`
- Вызывать при открытии чата
- Отмечать все непрочитанные сообщения

### Фаза 4: Status Polling Fallback

**4.1. Создать Status Sync Service**

- Файл: `src/services/statusSyncService.ts`
- Polling статусов когда SignalR отключен
- Автоматический старт/стоп на основе SignalR состояния
- Интервал: 5 секунд

**4.2. Добавить endpoint для статусов**

- В `messageApi.ts`: `getStatusUpdates(chatId, since)`
- Получение пропущенных обновлений статусов

### Фаза 5: Offline Sync Service

**5.1. Создать Offline Sync Service**

- Файл: `src/services/offlineSyncService.ts`
- Мониторинг сетевого соединения (Navigator.onLine)
- Автоматическая синхронизация при восстановлении связи
- Exponential backoff для повторных попыток
- Периодическая синхронизация каждые 30 секунд

**5.2. Интеграция с messageStore**

- Запуск service при инициализации
- Callback для обновления UI при синхронизации
- Обработка статусов pending сообщений

### Фаза 6: Улучшенная диагностика

**6.1. Добавить структурированное логирование**

- Теги: `[MSG_SEND]`, `[MSG_RECV]`, `[STATUS_UPDATE]`, `[SIGNALR]`, `[SYNC]`
- Console.log с префиксами для легкой фильтрации
- Timestamp для каждого лога

**6.2. Debug панель (опционально)**

- Компонент для отображения состояния outbox
- Показывать pending/failed сообщения
- Кнопки для ручной синхронизации

### Фаза 7: Cache Strategy

**7.1. Обновить messageStore для кэширования**

- Загружать из IndexedDB при loadMessages
- Показывать закэшированные сообщения моментально
- Обновлять в фоне через API
- Merge локальных и серверных сообщений

**7.2. Обновить chatStore для кэширования**

- Кэшировать список чатов
- Моментальная загрузка из кэша
- Фоновое обновление

## Архитектура потока сообщений

```
SENDER (Web):
1. User отправляет → Создать с temp UUID → Показать в UI
2. Сохранить в IndexedDB outbox
3. POST /api/messages (async)
4. Success: Заменить temp ID на server ID
5. Failed: Пометить как failed, показать retry

BACKEND:
(без изменений - уже обновлен для мобильного)

RECEIVER (Web):
1. Получить через SignalR
2. Добавить в IndexedDB cache
3. Отобразить в UI
4. Отправить MessageDelivered
5. При открытии чата: batch mark as read
```

## Ключевые файлы для изменения

**Новые файлы**:

- `src/services/indexedDBStorage.ts` - IndexedDB wrapper
- `src/repositories/outboxRepository.ts` - Pending messages queue
- `src/services/statusSyncService.ts` - Status polling fallback
- `src/services/offlineSyncService.ts` - Offline message sync
- `src/utils/uuid.ts` - UUID generator

**Изменяемые файлы**:

- `src/types/chat.ts` - Добавить поля для sync tracking
- `src/stores/messageStore.ts` - Local-first sending
- `src/services/signalRService.ts` - Auto delivery confirmation
- `src/api/messageApi.ts` - Batch read, status updates endpoints
- `src/components/message/MessageBubble.tsx` - Status icons & retry button

**Зависимости для добавления** (`package.json`):

- `uuid` - для генерации temp IDs
- `idb` - удобная обёртка для IndexedDB (опционально)

## Сравнение: До и После

### До (текущий веб-клиент)

```typescript
sendTextMessage: async (chatId, content) => {
  set({ isSending: true });
  await messageApi.sendMessage({ chatId, type: Text, content });
  set({ isSending: false });
  // Wait for SignalR to show message
}
```

### После (local-first)

```typescript
sendTextMessage: async (chatId, content) => {
  const tempId = uuidv4();
  const localMessage = {
    id: tempId,
    chatId,
    content,
    status: MessageStatus.Sending,
    isLocalOnly: true,
    ...
  };
  
  // Show immediately
  addMessage(localMessage);
  
  // Save to outbox
  await outbox.add(localMessage);
  
  // Sync async
  syncToBackend(tempId, chatId, content);
}
```

## Ожидаемые результаты

✅ Сообщения появляются мгновенно в веб-клиенте

✅ Работает offline режим с автоматической синхронизацией

✅ Статусы обновляются корректно (⏱ → ✓ → ✓✓ → ✓✓)

✅ Failed сообщения можно retry

✅ Fallback polling когда SignalR отключен

✅ Кэшированные сообщения загружаются моментально

✅ Единообразный опыт с мобильным приложением

## Тестирование

**Сценарии**:

1. Отправить сообщение online → проверить мгновенное отображение
2. Отключить сеть → отправить → включить → проверить синхронизацию
3. Открыть в двух вкладках → проверить статусы
4. Отключить SignalR → проверить polling fallback
5. Закрыть браузер с pending → открыть → проверить синхронизацию

**Console команды для мониторинга**:

```javascript
// В DevTools Console
console.log('[MSG_SEND]', ...); // Отправка
console.log('[MSG_RECV]', ...); // Получение
console.log('[SYNC]', ...); // Синхронизация
console.log('[SIGNALR]', ...); // SignalR события
```

## Порядок реализации

1. IndexedDB storage service
2. Outbox repository & types
3. Local-first отправка в messageStore
4. Auto delivery confirmation в signalRService
5. Status polling fallback service
6. Offline sync service
7. UI updates (MessageBubble retry button)
8. Cache strategy
9. Logging & debugging

## Совместимость

- ✅ Обратная совместимость с текущим backend
- ✅ Работает параллельно с мобильным приложением
- ✅ Можно деплоить независимо
- ✅ Graceful degradation если features не поддерживаются

## Оценка сложности

- **Время**: ~6-8 часов разработки
- **Риски**: Низкие (архитектура уже проверена на мобильном)
- **Тестирование**: 2-3 часа
- **Приоритет**: Высокий (критично для UX)

---

После реализации веб-клиент будет иметь те же возможности, что и мобильное приложение, обеспечивая единообразный и надежный пользовательский опыт на всех платформах.