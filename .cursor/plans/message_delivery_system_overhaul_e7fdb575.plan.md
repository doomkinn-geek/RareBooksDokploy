---
name: Message Delivery System Overhaul
overview: Implement a robust local-first messaging system with guaranteed delivery, proper status tracking (sending→sent→delivered→read), offline support, and reliable synchronization between mobile app and backend.
todos:
  - id: outbox-queue
    content: Create OutboxRepository for pending messages queue in mobile app
    status: completed
  - id: local-first-send
    content: Update MessagesProvider to create messages locally first, then sync to backend
    status: completed
    dependencies:
      - outbox-queue
  - id: message-model-sync
    content: Add localId, serverId, and syncState fields to Message model
    status: completed
  - id: backend-status-tracking
    content: Enhance MessagesController with systematic status tracking and sync endpoints
    status: completed
  - id: signalr-delivery-confirm
    content: Update SignalR provider to automatically send delivery confirmations
    status: completed
    dependencies:
      - local-first-send
  - id: status-polling-fallback
    content: Add REST API status polling when SignalR is disconnected
    status: completed
    dependencies:
      - backend-status-tracking
  - id: read-receipts-batch
    content: Implement batched read receipts when opening chat
    status: completed
  - id: offline-sync-service
    content: Create background sync service with retry logic for offline messages
    status: completed
    dependencies:
      - outbox-queue
  - id: enhanced-diagnostics
    content: Add comprehensive logging and diagnostic endpoints for debugging
    status: completed
  - id: fcm-push-improvements
    content: Fix push notification handling to ensure messages visible when tapped
    status: completed
---

# Reliable Message Delivery System

## Overview

Transform the messenger into a local-first system with guaranteed message delivery and accurate status tracking. Messages will be created locally immediately, then synchronized with the backend asynchronously. Status updates will flow reliably through both REST and SignalR channels with proper fallbacks.

## Current Architecture Problems

**Mobile App ([lib/presentation/providers/messages_provider.dart](lib/presentation/providers/messages_provider.dart)):**

- Sends message via REST API but waits for SignalR to show it in UI
- No temporary message ID for optimistic updates
- No offline queue or retry logic

**Backend ([src/MayMessenger.API/Controllers/MessagesController.cs](src/MayMessenger.API/Controllers/MessagesController.cs)):**

- Creates messages with "Sent" status immediately
- Delivery/read receipts exist but aren't consistently triggered
- No systematic delivery confirmation flow

**SignalR Hub ([src/MayMessenger.API/Hubs/ChatHub.cs](src/MayMessenger.API/Hubs/ChatHub.cs)):**

- Status update events work but aren't reliably triggered by all clients
- No fallback when SignalR is disconnected

## Implementation Plan

### Phase 1: Local-First Message Creation (Mobile)

**1.1. Add Pending Messages Queue**

- Create `OutboxRepository` in `lib/data/repositories/` to store pending messages
- Store messages with temporary UUID before sending to backend
- Track message state: `pending`, `sending`, `sent`, `failed`

**1.2. Update Messages Provider ([lib/presentation/providers/messages_provider.dart](lib/presentation/providers/messages_provider.dart))**

- `sendMessage()`: Create message locally with `MessageStatus.sending` immediately
- Add message to UI state instantly (optimistic update)
- Save to outbox queue
- Send to backend asynchronously
- On success: Replace temp ID with server ID, update status to `sent`
- On failure: Mark as `failed`, show retry button
- Remove reliance on SignalR for showing own messages

**1.3. Update Message Model ([lib/data/models/message_model.dart](lib/data/models/message_model.dart))**

- Add `localId` field (UUID for client-side tracking)
- Add `serverId` field (replaced after backend confirms)
- Add `syncState` enum: `local_only`, `syncing`, `synced`, `failed`

### Phase 2: Systematic Status Tracking (Backend)

**2.1. Update MessagesController ([src/MayMessenger.API/Controllers/MessagesController.cs](src/MayMessenger.API/Controllers/MessagesController.cs))**

- When message is created: status = `Sent`, emit SignalR event
- Add automatic delivery tracking when message is retrieved via API
- Add GET endpoint to check pending status updates for a chat

**2.2. Enhance ChatHub ([src/MayMessenger.API/Hubs/ChatHub.cs](src/MayMessenger.API/Hubs/ChatHub.cs))**

- On `ReceiveMessage` event: Client immediately calls `MessageDelivered`
- Ensure status update events are sent to ALL participants
- Add connection state tracking per user
- When user reconnects: send missed status updates

**2.3. Add Status Sync Mechanism**

- Create periodic background job to check undelivered messages
- If message is >30 seconds old and still "Sent", query client connectivity
- Add REST API endpoint: `GET /api/messages/{chatId}/status-updates` to pull missed updates

### Phase 3: Guaranteed Delivery Confirmation (Mobile)

**3.1. Update SignalR Provider ([lib/presentation/providers/signalr_provider.dart](lib/presentation/providers/signalr_provider.dart))**

- On `onReceiveMessage`: 
  - Add message to local cache immediately
  - Call `markMessageAsDelivered` to backend
  - Update message status in UI to `delivered`
- Track delivery confirmation success/failure

**3.2. Add Status Polling Fallback**

- If SignalR is disconnected: poll status updates every 5 seconds
- Pull status changes from REST endpoint when entering chat
- Merge status updates from both SignalR and REST sources

**3.3. Implement Read Receipts Properly**

- When chat is opened and scrolled to bottom: mark all unread messages as read
- Batch read confirmations (send one request for multiple messages)
- Update local status immediately, sync to backend

### Phase 4: Offline & Retry Support

**4.1. Create Message Sync Service (Mobile)**

- Background worker that processes outbox queue
- Retry failed messages with exponential backoff
- Detect network connectivity changes and trigger sync

**4.2. Add Conflict Resolution**

- If message already exists on server (detected by temp ID), merge
- If message was deleted while offline, show conflict notification
- Handle clock skew issues with message timestamps

**4.3. Update Local Cache Strategy ([lib/data/datasources/local_datasource.dart](lib/data/datasources/local_datasource.dart))**

- Always load from cache first
- Show messages immediately even if stale
- Refresh from backend in background
- Merge updates intelligently

### Phase 5: Enhanced Diagnostics

**5.1. Mobile App Logging**

- Add structured logging to `adb logcat` with tags:
  - `[MSG_SEND]`: Message sending flow
  - `[MSG_RECV]`: Message receiving flow
  - `[STATUS_UPDATE]`: Status change events
  - `[SIGNALR]`: SignalR connection events
  - `[SYNC]`: Synchronization operations

**5.2. Backend Diagnostics ([src/MayMessenger.API/Controllers/DiagnosticsController.cs](src/MayMessenger.API/Controllers/DiagnosticsController.cs))**

- Add endpoint: `GET /api/diagnostics/message/{messageId}` - full message lifecycle
- Add endpoint: `GET /api/diagnostics/user/{userId}/connection-state` - SignalR state
- Add endpoint: `GET /api/diagnostics/delivery-receipts/{messageId}` - who received/read
- Enhanced logging for message delivery pipeline

### Phase 6: Push Notification Improvements

**6.1. Update FCM Service ([lib/core/services/fcm_service.dart](lib/core/services/fcm_service.dart))**

- When push notification is tapped: force refresh messages for that chat
- Ensure message is in local cache before navigating
- Add retry if message fetch fails

**6.2. Backend Push Notification Enhancement ([src/MayMessenger.API/Controllers/MessagesController.cs](src/MayMessenger.API/Controllers/MessagesController.cs))**

- Include message ID and preview in push payload
- Add silent data notifications for status updates
- Track if push was delivered successfully

## Testing Strategy

**Manual Testing Flow:**

1. Send message while online → verify instant local display
2. Send message while offline → verify queued and sent when online
3. Receive message via SignalR → verify delivered status sent back
4. Open chat via push notification → verify message visible
5. Mark messages as read → verify sender sees green checkmarks
6. Disconnect SignalR → verify status polling fallback works

**Diagnostic Commands:**

```bash
# Mobile - Monitor message flow
adb logcat | grep -E "MSG_SEND|MSG_RECV|STATUS_UPDATE|SIGNALR"

# Backend - Check message status
curl https://messenger.rare-books.ru/api/diagnostics/message/{messageId}
curl https://messenger.rare-books.ru/api/diagnostics/logs
```

## Expected Outcomes

✅ Messages appear instantly in sender's chat (local-first)

✅ Messages reliably deliver to recipients even if SignalR is slow

✅ Status transitions work consistently: sending → sent → delivered → read

✅ Offline messages queue and send when connection restored

✅ Push notifications always show the correct message

✅ Failed messages show retry button

✅ Comprehensive diagnostics for debugging

## Key Files to Modify

**Mobile App:**

- `lib/data/repositories/message_repository.dart` - Add outbox queue
- `lib/presentation/providers/messages_provider.dart` - Local-first sending
- `lib/presentation/providers/signalr_provider.dart` - Delivery confirmation
- `lib/data/models/message_model.dart` - Add sync state tracking
- `lib/core/services/fcm_service.dart` - Push notification handling

**Backend:**

- `src/MayMessenger.API/Controllers/MessagesController.cs` - Status sync endpoints
- `src/MayMessenger.API/Hubs/ChatHub.cs` - Reliable status broadcasting
- `src/MayMessenger.API/Controllers/DiagnosticsController.cs` - Enhanced diagnostics
- `src/MayMessenger.Domain/Entities/Message.cs` - Track delivery attempts