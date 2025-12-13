# Debug Analysis - FCM Token Registration Issue

## Root Cause Found ✅

**Problem:** FCM tokens are NOT being registered for mobile users.

**Evidence from logs:**
```
[H4-TOKENS] Retrieved 0 FCM tokens for user 942a32ce-c4ef-4b0e-a547-3eb2e176d04f
[H4-NO-TOKENS] User 942a32ce-c4ef-4b0e-a547-3eb2e176d04f has NO active FCM tokens registered
```

## Why FCM Token Registration Failed

### Issue 1: Missing Registration After FCM Initialize

**Location:** `lib/main.dart` lines 50-56

**Problem:** After calling `fcmService.initialize()`, the code did NOT call `registerToken()`.

```dart
// BEFORE (BROKEN):
final fcmService = ref.read(fcmServiceProvider);
await fcmService.initialize();  // ❌ No token registration!
```

**Fix Applied:**
```dart
// AFTER (FIXED):
final fcmService = ref.read(fcmServiceProvider);
await fcmService.initialize();
// ✅ Now register the token immediately
final authRepo = ref.read(authRepositoryProvider);
final token = await authRepo.getStoredToken();
if (token != null) {
  await fcmService.registerToken(token);
}
```

### Issue 2: Auth Provider Registration Might Run Too Early

**Location:** `lib/presentation/providers/auth_provider.dart`

The `_registerFcmToken()` in auth_provider might execute BEFORE `fcmService.initialize()` completes, causing the FCM token to be NULL.

## Instrumentation Added

### H4.1: Firebase & FCM Initialization
- `main.dart`: Firebase.initializeApp() logging
- `main.dart`: fcmService.initialize() + registerToken() logging
- `fcm_service.dart`: initialize() entry, permission check, getToken() result

### H4.2: FCM Token Retrieval
- Logs when `_messaging.getToken()` is called
- Logs token result (first 20 chars or NULL)

### H4.3: Registration Flow
- `auth_provider.dart`: _registerFcmToken() entry, stored token check, call to fcmService
- `fcm_service.dart`: registerToken() entry, token presence check

### H4.4: API Request
- `fcm_service.dart`: POST request to /api/notifications/register-token
- Success/error logging

## Expected Log Flow (After Fix)

When user logs in or app starts with authenticated user:

```
[H4.1-MAIN] Initializing Firebase...
[H4.1-MAIN] Firebase initialized successfully
[H4.1-APP] User authenticated, initializing services...
[H4.1-APP] Calling fcmService.initialize()...
[H4.1-ENTRY] FCM Service initialize() called
[H4.1-PERMISSION] FCM permission status: AuthorizationStatus.authorized
[H4.2-GETTING-TOKEN] Calling getToken()...
[H4.2-TOKEN-RESULT] FCM Token: fH3k9L2mN... (not NULL)
[H4.1-APP] fcmService.initialize() completed, now registering token...
[H4.1-APP] Got stored token: YES
[H4.1-APP] Calling fcmService.registerToken()...
[H4.3-ENTRY] registerToken() called, _fcmToken: fH3k9L2mN...
[H4.4-API-REQUEST] Sending POST to /api/notifications/register-token
[H4.4-API-SUCCESS] FCM token registered successfully
[H4.1-APP] fcmService.registerToken() completed
```

**Backend should then show:**
```
[H4-TOKENS] Retrieved 1 FCM tokens for user 942a32ce-c4ef-4b0e-a547-3eb2e176d04f
[H3-PUSH] Sending push to user ...
[H3-SEND] Calling FirebaseService.SendNotificationAsync
[H3-RESULT] Push send result: true
```

## Next Steps

1. Rebuild mobile app with instrumentation
2. Login to mobile app (or restart if already logged in)
3. Check console logs for [H4.1-*], [H4.2-*], [H4.3-*], [H4.4-*]
4. Verify backend shows non-zero FCM tokens
5. Test push notification when app is minimized
