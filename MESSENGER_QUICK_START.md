# May Messenger - Quick Start Guide

## Installation & Setup

### Mobile App

1. **Install dependencies**:
```bash
cd _may_messenger_mobile_app
flutter pub get
```

2. **Build and run**:
```bash
# For Android
flutter run

# For release build
flutter build apk --release
```

### Backend

1. **Restore packages**:
```bash
cd _may_messenger_backend
dotnet restore
```

2. **Run**:
```bash
cd src/MayMessenger.API
dotnet run
```

## Testing the New Features

### 1. Test Local-First Sending

**Steps**:
1. Open app and navigate to a chat
2. Send a message
3. **Expected**: Message appears instantly with clock icon (sending)
4. After ~1 second: Clock changes to single checkmark (sent)

**Monitor logs**:
```bash
adb logcat | grep "MSG_SEND"
```

### 2. Test Offline Mode

**Steps**:
1. Turn off WiFi/mobile data
2. Send several messages
3. **Expected**: Messages appear with clock icon
4. Turn on network
5. **Expected**: Messages sync automatically, icons change to checkmarks

**Monitor logs**:
```bash
adb logcat | grep "SYNC"
```

### 3. Test Delivery Confirmation

**Steps**:
1. User A sends message to User B
2. User B opens app (doesn't open chat)
3. **Expected**: User A sees double gray checkmarks (delivered)

**Monitor logs**:
```bash
# On User B's device
adb logcat | grep "MSG_RECV"
```

### 4. Test Read Receipts

**Steps**:
1. User A sends message to User B
2. User B opens the chat
3. **Expected**: User A sees double green checkmarks (read)

**Monitor logs**:
```bash
adb logcat | grep "STATUS_UPDATE"
```

### 5. Test Push Notifications

**Steps**:
1. User A sends message to User B
2. User B receives push notification
3. User B taps notification
4. **Expected**: App opens directly to chat with message visible

**Monitor logs**:
```bash
adb logcat | grep "FCM"
```

### 6. Test SignalR Fallback

**Steps**:
1. Disconnect SignalR (simulate by killing backend temporarily)
2. Send messages from another device
3. **Expected**: Status updates via polling (every 5 seconds)

**Monitor logs**:
```bash
adb logcat | grep "SYNC"
```

## Diagnostic Commands

### Backend Diagnostics

```bash
# Check specific message
curl https://messenger.rare-books.ru/api/diagnostics/message/{messageId}

# Check delivery receipts
curl https://messenger.rare-books.ru/api/diagnostics/delivery-receipts/{messageId}

# Check recent messages
curl https://messenger.rare-books.ru/api/diagnostics/recent-messages?count=10

# View diagnostic logs
curl https://messenger.rare-books.ru/api/diagnostics/logs

# Clear logs
curl -X DELETE https://messenger.rare-books.ru/api/diagnostics/logs

# Health check
curl https://messenger.rare-books.ru/api/diagnostics/health
```

### Mobile App Logs

```bash
# All message-related logs
adb logcat | grep -E "MSG_SEND|MSG_RECV|STATUS_UPDATE|SIGNALR|SYNC|FCM|NOTIFICATION"

# Just sending
adb logcat | grep "MSG_SEND"

# Just receiving
adb logcat | grep "MSG_RECV"

# Status updates
adb logcat | grep "STATUS_UPDATE"

# SignalR events
adb logcat | grep "SIGNALR"

# Sync operations
adb logcat | grep "SYNC"

# Push notifications
adb logcat | grep -E "FCM|NOTIFICATION"
```

## Common Issues & Solutions

### Issue: Messages not appearing instantly

**Solution**: Check that outbox repository is initialized
```bash
adb logcat | grep "OUTBOX"
```

### Issue: Status not updating

**Solution**: Check SignalR connection
```bash
adb logcat | grep "SignalR"
```

If disconnected, status polling should activate:
```bash
adb logcat | grep "SYNC.*polling"
```

### Issue: Messages stuck in "sending" state

**Solution**: Check outbox for failed messages
```bash
adb logcat | grep "SYNC.*failed"
```

Failed messages will retry automatically with exponential backoff.

### Issue: Push notification doesn't show message

**Solution**: Check notification tap handler
```bash
adb logcat | grep "FCM.*tapped"
```

Should see:
1. "Refreshing chats list..."
2. "Loading messages for chat..."
3. "Navigating to chat screen..."

## Performance Monitoring

### Message Send Latency

**Expected timings**:
- Local display: < 50ms
- Backend sync: 500-2000ms
- SignalR broadcast: 100-300ms
- Total end-to-end: 600-2300ms

### Status Update Latency

**Expected timings**:
- Delivery confirmation: 100-500ms
- Read confirmation: 100-500ms
- Status polling (fallback): 5000ms

### Offline Sync

**Expected behavior**:
- First retry: 10 seconds
- Second retry: 20 seconds
- Third retry: 40 seconds
- Maximum retries: 10

## Troubleshooting Checklist

- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] Backend running and accessible
- [ ] Firebase configured (for push notifications)
- [ ] Device has internet connection
- [ ] SignalR connection established
- [ ] User authenticated
- [ ] Permissions granted (notifications, storage)

## Development Tips

### Enable Verbose Logging

Add to `main.dart`:
```dart
void main() async {
  // Enable verbose logging
  debugPrint('Verbose logging enabled');
  
  // ... rest of initialization
}
```

### Test Offline Sync Manually

```dart
// In offline_sync_service.dart, reduce sync interval for testing
_syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
  syncNow();
});
```

### Test Status Polling Manually

```dart
// In message_sync_service.dart, reduce polling interval for testing
void startPolling({
  Duration interval = const Duration(seconds: 2), // Reduced from 5
}) {
  // ...
}
```

## Next Steps

1. **Test all scenarios** listed above
2. **Monitor logs** during testing
3. **Check diagnostics endpoints** for message flow
4. **Report any issues** with log excerpts
5. **Deploy to production** when satisfied

## Support

For issues or questions:
1. Check logs using commands above
2. Use diagnostic endpoints to inspect message state
3. Review MESSENGER_IMPLEMENTATION_SUMMARY.md for architecture details
4. Check the plan file for implementation details

## Success Criteria

✅ Messages appear instantly when sent
✅ Messages sync successfully to backend
✅ Status indicators work correctly (sending → sent → delivered → read)
✅ Offline messages queue and sync when online
✅ Push notifications open correct chat with message visible
✅ Failed messages show retry option
✅ Diagnostics endpoints provide useful information

---

**Implementation Date**: December 17, 2025
**Status**: All features implemented and ready for testing

