---
name: Рефакторинг May Messenger
overview: Комплексный рефакторинг приложения для обмена сообщениями с фокусом на устранение дубликатов, мгновенную доставку, надежные статусы и работу в офлайн-режиме. Включает архитектурные улучшения backend и mobile app.
todos:
  - id: db-migration
    content: Создать EF Core миграцию для уникального индекса ClientMessageId и таблицы MessageStatusEvents
    status: completed
  - id: backend-idempotency
    content: Рефакторинг MessagesController.SendMessage с транзакциями SERIALIZABLE
    status: completed
  - id: backend-event-sourcing
    content: Реализовать Event Sourcing для статусов сообщений с таблицей событий
    status: completed
  - id: backend-ack-service
    content: Расширить AckRetryService для retry неподтвержденных статусов и FCM fallback
    status: completed
  - id: backend-chathub
    content: Добавить heartbeat механизм и incremental sync в ChatHub
    status: completed
  - id: backend-presence
    content: Реализовать PresenceMonitor background service для отслеживания онлайн/офлайн
    status: completed
  - id: backend-batch
    content: Добавить batch операции для массового обновления статусов
    status: completed
  - id: backend-search
    content: Оптимизировать поиск сообщений с full-text search PostgreSQL
    status: completed
  - id: backend-diagnostics
    content: Создать DiagnosticsController для мониторинга метрик
    status: completed
  - id: mobile-event-queue
    content: Создать EventQueueService для централизованной обработки событий
    status: completed
  - id: mobile-messages-refactor
    content: "Упростить messages_provider: удалить сложную дедупликацию и defensive cleanup"
    status: completed
    dependencies:
      - mobile-event-queue
  - id: mobile-signalr-reconnect
    content: Улучшить SignalR reconnection с exponential backoff + jitter и incremental sync
    status: completed
  - id: mobile-outbox-cleanup
    content: Реализовать немедленное удаление из Outbox после успешной отправки
    status: completed
  - id: mobile-outbox-reliability
    content: Добавить corruption recovery и atomic operations в OutboxRepository
    status: completed
  - id: mobile-heartbeat
    content: Реализовать heartbeat timer для отправки ping каждые 30 секунд
    status: completed
  - id: mobile-typing
    content: Улучшить typing indicators с debouncing
    status: completed
  - id: mobile-debug-screen
    content: Создать debug settings screen для диагностики
    status: completed
  - id: data-migration
    content: Написать и протестировать скрипты миграции данных
    status: completed
    dependencies:
      - db-migration
      - backend-event-sourcing
  - id: nginx-config
    content: Обновить nginx конфигурацию для оптимальных WebSocket настроек
    status: completed
  - id: qa-testing
    content: Комплексное manual QA тестирование всех сценариев
    status: completed
    dependencies:
      - backend-idempotency
      - mobile-messages-refactor
      - data-migration
  - id: performance-testing
    content: Нагрузочное тестирование с 100+ параллельными клиентами
    status: completed
    dependencies:
      - qa-testing
---

# План комплексного рефакторинга May Messenger

## 1. Анализ текущего состояния

### 1.1. Выявленные критические проблемы

**Backend проблемы:**

- Отсутствие идемпотентности при обработке дубликатов сообщений через SignalR
- Слабая обработка race conditions между REST API и SignalR
- Недостаточная валидация `ClientMessageId`
- Отсутствие транзакционных гарантий при обновлении статусов
- Нет оптимистичных блокировок (concurrency control)
- Отсутствие батчинга операций для групповых чатов

**Mobile App проблемы:**

- Сложная многоуровневая дедупликация в [`messages_provider.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\providers\messages_provider.dart) (строки 929-977)
- Риск потери сообщений при сбое синхронизации outbox
- Недостаточная обработка переподключений SignalR
- Слабая синхронизация LRU cache, Hive cache и outbox
- Отсутствие централизованной очереди событий
- Нет механизма восстановления после катастрофических сбоев

**Инфраструктурные проблемы:**

- Отсутствие мониторинга здоровья SignalR соединений
- Нет метрик производительности
- Отсутствие distributed tracing для отладки

---

## 2. Архитектурные улучшения

### 2.1. Backend: Гарантированная идемпотентность

**Цель**: Полностью устранить дубликаты на уровне базы данных.**Решение**:

1. **Уникальный индекс на `ClientMessageId`** в БД PostgreSQL

- Файл: [`d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.Infrastructure\Data\AppDbContext.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.Infrastructure\Data\AppDbContext.cs)
- Добавить: `CreateIndex("IX_Messages_ClientMessageId", x => x.ClientMessageId).IsUnique()`

2. **Обновить [`MessagesController.SendMessage`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Controllers\MessagesController.cs:302-421)**:

- Обернуть проверку существования и вставку в транзакцию с уровнем изоляции `SERIALIZABLE`
- Обрабатывать `DbUpdateException` как валидный случай (сообщение уже существует)
- Возвращать существующее сообщение с HTTP 200 (не 409)

3. **Deprecate SignalR `SendMessage`**:

- Уже помечено как `[Obsolete]` в [`ChatHub.cs:98`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Hubs\ChatHub.cs:98)
- Удалить полностью после миграции клиентов

### 2.2. Backend: Event Sourcing для статусов

**Цель**: Гарантировать корректность и полноту истории статусов сообщений.**Решение**:

1. **Новая таблица `MessageStatusEvents`**:
   ```csharp
            public class MessageStatusEvent 
            {
                public Guid Id { get; set; }
                public Guid MessageId { get; set; }
                public MessageStatus Status { get; set; }
                public Guid? UserId { get; set; } // Для delivered/read в группах
                public DateTime Timestamp { get; set; }
                public string Source { get; set; } // "REST", "SignalR", "Background"
            }
   ```




2. **Агрегирующая функция**:

- Вычисляет финальный статус сообщения на основе событий
- Для групп: статус = MIN(статусы всех участников)

3. **Миграция данных**:

- EF Core миграция для создания таблицы
- Скрипт миграции существующих статусов в события

### 2.3. Backend: Background Job для надежности

**Цель**: Гарантировать доставку уведомлений даже при сбоях SignalR.**Решение**:

1. **Расширить `AckRetryService`** ([`d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Services\AckRetryService.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Services\AckRetryService.cs)):

- Добавить retry для неподтвержденных статусов
- Использовать exponential backoff: 10s, 30s, 1m, 5m, 15m

2. **Fallback на Push Notifications**:

- Если SignalR ACK не получен за 30 секунд, отправить FCM
- Обновить [`FirebaseService`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.Application\Services\FirebaseService.cs)

### 2.4. Mobile: Централизованная Event Queue

**Цель**: Упростить обработку событий и гарантировать порядок.**Решение**:

1. **Новый сервис `EventQueueService`**:
   ```dart
            class EventQueueService {
              final Queue<Event> _queue = Queue();
              Future<void> processEvent(Event event);
              void enqueue(Event event);
            }
   ```




2. **Типы событий**:

- `MessageReceivedEvent` - новое сообщение через SignalR
- `MessageSentEvent` - сообщение отправлено через API
- `StatusUpdateEvent` - обновление статуса
- `SyncCompleteEvent` - синхронизация завершена

3. **Обработка событий последовательно**:

- Все события обрабатываются в порядке поступления
- Гарантия: дедупликация происходит в одном месте

### 2.5. Mobile: Упрощение кеширования

**Цель**: Устранить рассинхронизацию между тремя кешами.**Решение**:

1. **Единая архитектура**:

- **Outbox** (Hive) - только для неотправленных сообщений
- **Message Cache** (Hive) - только для синхронизированных сообщений
- **LRU Cache** (память) - для быстрого доступа

2. **Правила**:

- Сообщение либо в Outbox, либо в Message Cache, но не в обоих
- При успешной отправке: удалить из Outbox → добавить в Message Cache
- LRU cache заполняется из обоих источников

3. **Рефакторинг [`messages_provider.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\providers\messages_provider.dart)**:

- Упростить логику загрузки (строки 245-391)
- Удалить сложную дедупликацию (строки 929-977)
- Переместить дедупликацию в `EventQueueService`

---

## 3. Детальная реализация по компонентам

### 3.1. Backend: Database Schema

**Файлы**:

- Новая миграция EF Core
- [`AppDbContext.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.Infrastructure\Data\AppDbContext.cs)

**Изменения**:

1. **Уникальный индекс**:
   ```csharp
            modelBuilder.Entity<Message>()
                .HasIndex(m => m.ClientMessageId)
                .IsUnique()
                .HasFilter("ClientMessageId IS NOT NULL");
   ```




2. **Таблица событий статусов**:
   ```csharp
            modelBuilder.Entity<MessageStatusEvent>()
                .HasIndex(e => new { e.MessageId, e.Timestamp });
   ```




3. **Timestamp для UpdatedAt**:

- Добавить триггер PostgreSQL для автоматического обновления `UpdatedAt`

### 3.2. Backend: MessagesController рефакторинг

**Файл**: [`MessagesController.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Controllers\MessagesController.cs)**Метод `SendMessage` (строки 302-421)**:

1. **Обернуть в транзакцию**:
   ```csharp
            using var transaction = await _unitOfWork.BeginTransactionAsync(IsolationLevel.Serializable);
   ```




2. **Упростить idempotency check**:

- Убрать логику строк 321-357
- Полагаться на уникальный индекс БД
- Обрабатывать `DbUpdateException` с кодом ошибки duplicate key

3. **Создание pending acks**:

- Переместить в отдельный метод `CreatePendingAcksAsync`
- Вызывать в той же транзакции

4. **SignalR notification**:

- Отправлять ТОЛЬКО после успешного commit транзакции
- Обработать `HubException` и добавить в retry queue

**Новый метод `SendMessageBatch`**:

- Принимает массив сообщений для группового чата
- Использует одну транзакцию для всех сообщений
- Отправляет одно SignalR уведомление

### 3.3. Backend: ChatHub улучшения

**Файл**: [`ChatHub.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Hubs\ChatHub.cs)**OnConnectedAsync (строки 27-53)**:

1. **Heartbeat механизм**:

- Добавить периодическую отправку `Ping` каждые 30 секунд
- Клиент отвечает `Pong`
- Disconnect если нет ответа за 60 секунд

2. **Incremental sync при переподключении**:

- Получить `lastSyncTimestamp` от клиента
- Отправить все пропущенные события (сообщения + статусы)

**MessageDelivered/MessageRead (строки 107-217)**:

1. **Транзакционность**:

- Обернуть обновление в транзакцию
- Создать `MessageStatusEvent` вместо прямого обновления

2. **Батчинг**:

- Добавить новый метод `BatchMarkMessagesAs(status, messageIds[])`
- Клиент может отправить массив из 50 сообщений за раз

### 3.4. Mobile: EventQueueService реализация

**Новый файл**: `lib/data/services/event_queue_service.dart`

```dart
class EventQueueService {
  final Queue<Event> _queue = Queue();
  bool _processing = false;
  
  void enqueue(Event event) {
    _queue.add(event);
    _processQueue();
  }
  
  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;
    
    while (_queue.isNotEmpty) {
      final event = _queue.removeFirst();
      await _processEvent(event);
    }
    
    _processing = false;
  }
  
  Future<void> _processEvent(Event event) async {
    // Обработка с дедупликацией
  }
}
```



### 3.5. Mobile: SignalR reconnection improvements

**Файл**: [`signalr_service.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\data\datasources\signalr_service.dart)**Улучшения reconnect логики (строки 65-108)**:

1. **Exponential backoff с jitter**:

- Добавить случайную задержку 0-2 секунды
- Предотвращает thundering herd

2. **Incremental sync после reconnect**:
   ```dart
            Future<void> onReconnected() async {
              final lastSync = await getLastSyncTimestamp();
              await invokeServerSync(lastSync);
            }
   ```




3. **Heartbeat на клиенте**:

- Отправлять Pong в ответ на Ping
- Форсировать reconnect если Ping не приходит 90 секунд

### 3.6. Mobile: Messages Provider упрощение

**Файл**: [`messages_provider.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\providers\messages_provider.dart)**Упрощение метода `loadMessages` (строки 245-391)**:

1. **Удалить defensive cleanup** (строки 286-308):

- Больше не нужно, так как outbox очищается сразу после успешной отправки

2. **Упростить merge логику** (строки 330-360):

- Использовать только `ClientMessageId` для сопоставления
- Fallback на content matching удалить

**Упрощение метода `addMessage` (строки 851-1021)**:

1. **Удалить сложную дедупликацию** (строки 929-977):

- Переместить в `EventQueueService`
- Оставить только проверку по `id`

2. **Упростить matching** (строки 1024-1035):

- Только по `ClientMessageId`

### 3.7. Mobile: Outbox reliability

**Файл**: `lib/data/repositories/outbox_repository.dart`**Улучшения**:

1. **Atomic operations**:

- Все операции обернуть в Hive транзакции
- Использовать write-ahead log

2. **Corruption recovery**:

- При старте проверять консистентность Hive
- Если ошибка - удалить поврежденные записи, отправить в Sentry

3. **Age-based cleanup**:

- Автоматически удалять failed messages старше 7 дней

---

## 4. Миграция данных

### 4.1. Backend Migration Script

**Новая миграция**: `20240101_RefactorMessageStatuses`

1. **Создать таблицы**:

- `MessageStatusEvents`
- Индексы

2. **Мигрировать существующие данные**:
   ```sql
            INSERT INTO MessageStatusEvents (MessageId, Status, Timestamp, Source)
            SELECT Id, Status, CreatedAt, 'Migration'
            FROM Messages;
   ```




3. **Добавить ClientMessageId для старых сообщений**:

- Оставить NULL (не критично для старых сообщений)

### 4.2. Mobile App Migration

**Версионирование Hive**:

1. **Проверить версию при старте**:
   ```dart
            final version = await box.get('schema_version') ?? 0;
            if (version < 2) {
              await migrateToV2();
            }
   ```




2. **Миграция v1 → v2**:

- Очистить LRU cache (устаревшие данные)
- Переиндексировать Message Cache
- Очистить Outbox от synced messages

---

## 5. Функциональные улучшения

### 5.1. User Presence (онлайн/офлайн)

**Backend**:

1. **Heartbeat в ChatHub**:

- Клиент отправляет heartbeat каждые 30 секунд
- Сервер обновляет `LastHeartbeatAt` в таблице `Users`

2. **Background service `PresenceMonitor`**:

- Каждые 60 секунд проверяет `LastHeartbeatAt`
- Если > 90 секунд, помечает пользователя offline
- Рассылает события через SignalR

**Mobile**:

1. **Heartbeat timer**:
   ```dart
            Timer.periodic(Duration(seconds: 30), (_) {
              signalRService.sendHeartbeat();
            });
   ```




2. **UI обновление**:

- Слушать `UserStatusChanged` events
- Обновлять статус в списке чатов и в header чата

### 5.2. Typing Indicators улучшения

**Текущая реализация**: базовая есть в [`ChatHub.cs:219-226`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Hubs\ChatHub.cs:219-226)**Улучшения**:

1. **Debouncing на клиенте**:

- Отправлять `isTyping=true` только после 300ms непрерывного набора
- Автоматически отправлять `isTyping=false` через 3 секунды

2. **Оптимизация на сервере**:

- Не рассылать typing events для больших групп (>50 участников)

### 5.3. Message Search оптимизация

**Текущая реализация**: [`MessagesController.SearchMessages`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Controllers\MessagesController.cs:951-1011)**Проблема**: загружает все сообщения в память (строка 976)**Решение**:

1. **Full-text search в PostgreSQL**:

- Добавить GIN индекс на `Content`
- Использовать `to_tsvector` для русского языка

2. **Pagination**:

- Cursor-based pagination для результатов поиска

---

## 6. Мониторинг и диагностика

### 6.1. Backend Metrics

**Новый контроллер**: `DiagnosticsController`**Метрики**:

1. **SignalR health**:

- Количество активных соединений
- Частота disconnects
- Latency RTT (ping-pong)

2. **Message delivery**:

- Средняя задержка доставки (REST → SignalR)
- Процент failed deliveries
- Размер pending acks queue

3. **Database performance**:

- Количество дубликатов (пойманных unique constraint)
- Длительность транзакций

**Endpoint**: `GET /api/diagnostics/metrics`

### 6.2. Mobile App Diagnostics

**Новый экран**: Debug Settings (только в dev build)**Информация**:

1. **SignalR connection**:

- Статус подключения
- Время последнего reconnect
- Количество reconnects за сессию

2. **Message sync**:

- Количество сообщений в Outbox
- Количество pending status updates
- Время последней успешной синхронизации

3. **Cache stats**:

- LRU cache size / hit rate
- Hive cache size
- Количество corrupted entries

---

## 7. Порядок выполнения (приоритетный)

### Фаза 1: Критические исправления (1-2 дня)

1. ✅ **Backend**: Уникальный индекс на `ClientMessageId`
2. ✅ **Backend**: Транзакции в `SendMessage`
3. ✅ **Mobile**: Немедленное удаление из Outbox после отправки
4. ✅ **Mobile**: Упрощение дедупликации в `addMessage`

### Фаза 2: Event Sourcing и надежность (2-3 дня)

5. ✅ **Backend**: Таблица `MessageStatusEvents`
6. ✅ **Backend**: Миграция существующих статусов
7. ✅ **Backend**: Обновить `MessageDelivered/Read` для использования событий
8. ✅ **Backend**: Расширить `AckRetryService`

### Фаза 3: Mobile архитектура (3-4 дня)

9. ✅ **Mobile**: Реализовать `EventQueueService`
10. ✅ **Mobile**: Рефакторинг `messages_provider` для использования queue
11. ✅ **Mobile**: Улучшить SignalR reconnection
12. ✅ **Mobile**: Incremental sync при переподключении

### Фаза 4: Функциональные улучшения (2-3 дня)

13. ✅ **Backend**: Heartbeat и PresenceMonitor
14. ✅ **Mobile**: Heartbeat timer
15. ✅ **Backend/Mobile**: Улучшенные typing indicators
16. ✅ **Backend**: Batch операции для статусов

### Фаза 5: Оптимизация и мониторинг (2-3 дня)

17. ✅ **Backend**: Full-text search оптимизация
18. ✅ **Backend**: DiagnosticsController с метриками
19. ✅ **Mobile**: Debug settings screen
20. ✅ **Инфраструктура**: Обновить nginx конфигурацию для лучших WebSocket settings

### Фаза 6: Миграция и тестирование (2-3 дня)

21. ✅ **Backend**: Запустить миграцию БД на продакшене
22. ✅ **Mobile**: Выпустить обновление приложения с схемой v2
23. ✅ **Manual QA**: Комплексное тестирование всех сценариев
24. ✅ **Performance testing**: Нагрузочное тестирование с 100+ параллельными клиентами

---

## 8. Критерии успеха

### Количественные метрики:

1. **Дубликаты**: 0% дубликатов сообщений (измерено через уникальный индекс)
2. **Задержка доставки**: <100ms p95 для сообщений через SignalR
3. **Надежность статусов**: >99.9% статусов доставлены и отображены корректно
4. **User presence**: <5 секунд задержка обновления онлайн/офлайн статуса
5. **Offline sync**: 100% сообщений из Outbox успешно отправлены после восстановления связи

### Качественные критерии:

1. Приложение работает стабильно без перезапуска в течение 24+ часов
2. Нет визуальных глюков (мерцание, скачки UI)
3. Сообщения появляются мгновенно для обоих участников
4. Статусы обновляются в реальном времени
5. Офлайн режим работает без потери данных

---

## 9. Технические риски и митигация

| Риск | Вероятность | Воздействие | Митигация ||------|-------------|-------------|-----------|| Потеря сообщений при миграции БД | Низкая | Критическое | Полный бэкап перед миграцией, rollback план || Несовместимость старых клиентов | Средняя | Высокое | Постепенный rollout, поддержка старого API 2 недели || Performance degradation из-за событий | Средняя | Среднее | Мониторинг, индексы на все lookup поля || SignalR connection storms после deploy | Высокая | Среднее | Exponential backoff с jitter, rate limiting || Hive corruption на старых устройствах | Низкая | Среднее | Corruption recovery механизм, fallback на API |---

## 10. Ключевые файлы для изменения

### Backend (C#/.NET):

1. [`AppDbContext.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.Infrastructure\Data\AppDbContext.cs) - схема БД
2. [`MessagesController.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Controllers\MessagesController.cs) - REST API
3. [`ChatHub.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Hubs\ChatHub.cs) - SignalR хаб
4. [`AckRetryService.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.API\Services\AckRetryService.cs) - retry механизм
5. [`MessageRepository.cs`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_backend\src\MayMessenger.Infrastructure\Repositories\MessageRepository.cs) - доступ к данным

### Mobile (Flutter/Dart):

1. [`messages_provider.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\providers\messages_provider.dart) - state management
2. [`signalr_service.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\data\datasources\signalr_service.dart) - WebSocket клиент
3. [`signalr_provider.dart`](d:\_SOURCES\source\RareBooksServicePublic\_may_messenger_mobile_app\lib\presentation\providers\signalr_provider.dart) - SignalR integration
4. Новый: `lib/data/services/event_queue_service.dart` - централизованная очередь
5. `lib/data/repositories/outbox_repository.dart` - offline persistence

### Infrastructure:

1. [`docker-compose.yml`](d:\_SOURCES\source\RareBooksServicePublic\docker-compose.yml) - конфигурация контейнеров
2. [`nginx_prod.conf`](d:\_SOURCES\source\RareBooksServicePublic\nginx\nginx_prod.conf) - WebSocket настройки

---

## Итого