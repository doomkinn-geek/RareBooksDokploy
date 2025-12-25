---
name: Fix SignalR Reconnect & Outbox Sync
overview: Исправление критических ошибок в системе переподключения SignalR и синхронизации outbox, которые приводят к "зависанию" сообщений в статусе отправки и нестабильному соединению.
todos:
  - id: fix-connectivity-types
    content: Исправить типизацию connectivity_plus (List<ConnectivityResult>)
    status: completed
  - id: create-outbox-sync-service
    content: Создать OutboxSyncService для автоматической синхронизации pending messages
    status: completed
    dependencies:
      - fix-connectivity-types
  - id: integrate-connection-state-callback
    content: Добавить setOnConnectionStateChanged callback в signalr_provider
    status: completed
    dependencies:
      - fix-connectivity-types
  - id: integrate-outbox-sync-reconnect
    content: Интегрировать OutboxSyncService в reconnected callback
    status: completed
    dependencies:
      - create-outbox-sync-service
  - id: sync-pending-on-load
    content: Запускать синхронизацию pending messages при loadMessages
    status: completed
    dependencies:
      - create-outbox-sync-service
  - id: test-and-build
    content: Собрать APK и протестировать reconnect сценарий
    status: completed
    dependencies:
      - integrate-outbox-sync-reconnect
      - sync-pending-on-load
---

# Исправление системы переподключения SignalR и синхронизации Outbox

## Диагностика проблемы

Анализ скриншотов и кода выявил **4 критические ошибки**:

```mermaid
flowchart TD
    subgraph problems [Выявленные проблемы]
        P1[Ошибка типов connectivity_plus]
        P2[Outbox не синхронизируется при reconnect]
        P3[Состояние isConnected не обновляется]
        P4[Pending messages не ретраятся]
    end
    
    subgraph symptoms [Симптомы]
        S1[Оранжевый индикатор - бесконечный reconnect]
        S2[Зелёный индикатор - сообщения не отправляются]
        S3[Серый индикатор - потеря соединения]
    end
    
    P1 --> S1
    P2 --> S2
    P3 --> S1
    P4 --> S2
    P1 --> S3
```

---

## Ошибка 1: Некорректная типизация connectivity_plus (КРИТИЧЕСКАЯ)

**Файл**: [`_may_messenger_mobile_app/lib/data/datasources/signalr_service.dart`](_may_messenger_mobile_app/lib/data/datasources/signalr_service.dart)В connectivity_plus v5.x метод `onConnectivityChanged` возвращает `List<ConnectivityResult>`, а не одиночный `ConnectivityResult`:

```dart
// ТЕКУЩИЙ КОД (строка 375) - ОШИБКА:
_connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
  _hasInternetConnection = result != ConnectivityResult.none; // result это List!
});
```

Сравнение `List != enum` всегда true, поэтому приложение НИКОГДА не определяет потерю интернета!**Исправление**: Проверять первый элемент списка.---

## Ошибка 2: Outbox не синхронизируется при восстановлении соединения

**Файл**: [`_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart)В callback `setOnReconnectedCallback` синхронизируются только статусы, но **НЕ** pending messages из outbox:

```dart
_signalRService.setOnReconnectedCallback(() async {
  await statusSyncService.forceSync();  // Только статусы!
  // Outbox НЕ синхронизируется!
});
```

**Исправление**: Создать `OutboxSyncService` и вызывать его при reconnect.---

## Ошибка 3: Состояние isConnected не синхронизировано с реальным

**Файл**: [`_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart](_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart)_signalRService.setOnConnectionStateChanged()` никогда не вызывается, поэтому UI показывает неверный индикатор соединения.**Исправление**: Установить callback для обновления состояния.---

## Ошибка 4: Pending messages не синхронизируются при загрузке

**Файл**: [`_may_messenger_mobile_app/lib/presentation/providers/messages_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/messages_provider.dart)При `loadMessages()` pending сообщения загружаются из outbox и отображаются, но их синхронизация не запускается:

```dart
// Шаг 3: Load pending messages from outbox
final pendingMessages = await _outboxRepository.getPendingMessagesForChat(chatId);
// ... конвертация в Message для отображения
// НО НЕТ КОДА ДЛЯ ИХ ОТПРАВКИ!
```

---

## План исправлений

### Шаг 1: Исправить connectivity_plus типизацию

В `signalr_service.dart`:

- Изменить обработчик `onConnectivityChanged` для работы с `List<ConnectivityResult>`
- Исправить `checkConnectivity()` для возврата `List`

### Шаг 2: Создать OutboxSyncService

Новый файл `_may_messenger_mobile_app/lib/data/services/outbox_sync_service.dart`:

- Сервис для автоматической синхронизации pending messages
- Вызывается при восстановлении соединения
- Периодически проверяет outbox
- Использует exponential backoff

### Шаг 3: Интегрировать OutboxSyncService

В `signalr_provider.dart`:

- Добавить вызов OutboxSyncService в reconnected callback
- Установить `setOnConnectionStateChanged` callback для синхронизации состояния

### Шаг 4: Запускать синхронизацию при loadMessages

В `messages_provider.dart`:

- При загрузке сообщений проверять есть ли pending messages
- Если соединение активно - запускать их синхронизацию

### Шаг 5: Добавить провайдер для OutboxSyncService

В `auth_provider.dart`:

- Создать provider для OutboxSyncService

---

## Изменяемые файлы

| Файл | Изменения |

|------|-----------|

| [`signalr_service.dart`](_may_messenger_mobile_app/lib/data/datasources/signalr_service.dart) | Исправить типы connectivity_plus |

| [`signalr_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/signalr_provider.dart) | Добавить connection state callback и outbox sync |

| [`messages_provider.dart`](_may_messenger_mobile_app/lib/presentation/providers/messages_provider.dart) | Запускать синхронизацию pending при loadMessages |

| [`outbox_sync_service.dart`](_may_messenger_mobile_app/lib/data/services/outbox_sync_service.dart) | **Новый файл** - сервис синхронизации outbox |