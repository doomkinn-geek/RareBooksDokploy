# Исправление ошибок компиляции Flutter приложения

## Проблема

При сборке Android приложения (`flutter build apk --release`) возникали ошибки компиляции:

```
lib/presentation/providers/auth_provider.dart:229:43: Error: The method 'getToken' isn't defined for the type 'AuthRepository'.
lib/presentation/providers/auth_provider.dart:230:44: Error: The method 'getUserId' isn't defined for the type 'AuthRepository'.
```

## Причина

В `auth_provider.dart` был вызов несуществующих методов:
- `_authRepository.getToken()` - правильный метод: `getStoredToken()`
- `_authRepository.getUserId()` - метод отсутствует, но не нужен (userId извлекается из JWT токена на backend)

## Решение

### 1. Упрощена сигнатура `fcm_service.registerToken()`

**Было:**
```dart
Future<void> registerToken(String userId, String token) async
```

**Стало:**
```dart
Future<void> registerToken(String token) async
```

**Причина:** Backend извлекает `userId` из JWT токена автоматически (из `ClaimTypes.NameIdentifier`), поэтому передавать его явно не нужно.

### 2. Исправлен `auth_provider.dart`

**Было:**
```dart
Future<void> _registerFcmToken() async {
  try {
    final token = await _authRepository.getToken();      // ❌ Метод не существует
    final userId = await _authRepository.getUserId();    // ❌ Метод не существует
    
    if (token != null && userId != null) {
      await _fcmService.registerToken(userId, token);
      print('FCM token registered after auth');
    }
  } catch (e) {
    print('Failed to register FCM token after auth: $e');
  }
}
```

**Стало:**
```dart
Future<void> _registerFcmToken() async {
  try {
    final token = await _authRepository.getStoredToken();  // ✅ Правильный метод
    
    if (token != null) {
      await _fcmService.registerToken(token);              // ✅ Упрощенная сигнатура
      print('FCM token registered after auth');
    }
  } catch (e) {
    print('Failed to register FCM token after auth: $e');
    // Don't fail the auth flow if FCM registration fails
  }
}
```

## Измененные файлы

1. `lib/core/services/fcm_service.dart`:
   - Удален параметр `userId` из метода `registerToken()`

2. `lib/presentation/providers/auth_provider.dart`:
   - `_authRepository.getToken()` → `_authRepository.getStoredToken()`
   - Удален вызов `_authRepository.getUserId()`
   - Упрощен вызов `_fcmService.registerToken(token)` (без userId)

## Проверка

После исправлений приложение должно собираться без ошибок:

```bash
cd _may_messenger_mobile_app
flutter clean
flutter pub get
flutter build apk --release
```

## Дополнительно

### Backend автоматически извлекает userId

В `NotificationsController.cs`:

```csharp
[HttpPost("register-token")]
public async Task<IActionResult> RegisterToken([FromBody] RegisterTokenRequest request)
{
    var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    if (userId == null || !Guid.TryParse(userId, out var userGuid))
    {
        return Unauthorized();
    }
    
    // userId извлечен из JWT токена автоматически
    await _unitOfWork.FcmTokens.RegisterOrUpdateAsync(userGuid, request.Token, request.DeviceInfo ?? "Unknown");
    // ...
}
```

Поэтому передавать userId с клиента не требуется - достаточно JWT токена в заголовке `Authorization: Bearer <token>`.
