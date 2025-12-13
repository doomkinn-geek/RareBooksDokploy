# Firebase Push Notifications Setup Guide

## Обзор

May Messenger использует Firebase Cloud Messaging (FCM) для отправки push-уведомлений на мобильные устройства, когда пользователь не в сети.

## Архитектура

- **Backend**: Firebase Admin SDK для отправки push-уведомлений через FCM
- **Mobile App**: Firebase Messaging SDK для получения токенов и уведомлений
- **Database**: PostgreSQL хранит FCM токены пользователей и информацию об устройствах

## 1. Создание Firebase проекта

### 1.1 Firebase Console

1. Перейдите на [Firebase Console](https://console.firebase.google.com/)
2. Создайте новый проект или выберите существующий
3. Нажмите на иконку настроек (⚙️) → Project Settings

### 1.2 Service Account для Backend

1. В Project Settings перейдите на вкладку **Service accounts**
2. Нажмите **Generate new private key**
3. Сохраните файл JSON (например, `firebase_service_account.json`)
4. Поместите его в `_may_messenger_secrets/firebase_service_account.json`

**⚠️ ВАЖНО**: Не коммитьте этот файл в Git! Он содержит приватные ключи.

### 1.3 google-services.json для Android

1. В Project Settings перейдите на вкладку **General**
2. В разделе **Your apps** добавьте Android приложение:
   - Android package name: `com.maymessenger.mobile_app` (из `android/app/build.gradle.kts`)
   - App nickname: `May Messenger` (опционально)
   - Debug signing certificate SHA-1: (опционально, для тестирования)
3. Скачайте файл `google-services.json`
4. Поместите его в `_may_messenger_mobile_app/android/app/google-services.json`

**⚠️ ВАЖНО**: Не коммитьте этот файл в Git! Он также добавлен в `.gitignore`.

## 2. Инициализация Backend (Сервер)

### 2.1 Через Setup Page (рекомендуется)

1. После развертывания backend, откройте в браузере:
   ```
   https://messenger.rare-books.ru/messenger/setup/
   ```

2. Вставьте содержимое `firebase_service_account.json` в форму

3. Нажмите **"Проверить JSON"** для валидации

4. Нажмите **"Инициализировать Firebase"**

5. Перезапустите backend:
   ```bash
   docker compose restart maymessenger_backend
   ```

### 2.2 Ручная установка

1. Скопируйте Service Account JSON на сервер:
   ```bash
   # На локальной машине
   scp _may_messenger_secrets/firebase_service_account.json root@your-server:/root/firebase_config.json
   ```

2. На сервере:
   ```bash
   docker compose down
   docker volume create maymessenger_firebase
   docker run --rm -v maymessenger_firebase:/data -v /root:/host alpine cp /host/firebase_config.json /data/firebase_config.json
   rm /root/firebase_config.json  # Удалите файл с сервера после копирования
   docker compose up -d
   ```

### 2.3 Проверка инициализации

1. Проверьте логи backend:
   ```bash
   docker compose logs maymessenger_backend | grep -i firebase
   ```

2. Должны увидеть:
   ```
   Firebase initialized from /app/firebase_config/firebase_config.json
   ```

## 3. Сборка и развертывание мобильного приложения

### 3.1 Убедитесь, что google-services.json на месте

```bash
ls _may_messenger_mobile_app/android/app/google-services.json
```

Если файл не найден, скопируйте его из `_may_messenger_secrets/`.

### 3.2 Установите зависимости

```bash
cd _may_messenger_mobile_app
flutter pub get
```

### 3.3 Соберите и установите приложение

**Android**:
```bash
flutter build apk --release
# или для debug версии:
flutter run
```

**iOS** (требуется дополнительная настройка):
- Скачайте `GoogleService-Info.plist` из Firebase Console
- Поместите в `_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist`
- Откройте `ios/Runner.xcworkspace` в Xcode
- Настройте Push Notifications capability
- Настройте APNs в Firebase Console

## 4. Тестирование

### 4.1 Проверка регистрации FCM токена

1. Запустите мобильное приложение
2. Войдите или зарегистрируйтесь
3. В логах приложения должно быть:
   ```
   FCM Token: <токен>
   FCM token registered successfully
   ```

4. Проверьте в backend API:
   ```bash
   curl -X GET https://messenger.rare-books.ru/api/notifications/tokens \
     -H "Authorization: Bearer YOUR_JWT_TOKEN"
   ```

### 4.2 Проверка отправки push уведомлений

1. Откройте чат в web-клиенте: https://messenger.rare-books.ru/web/
2. Отправьте сообщение пользователю, у которого открыто мобильное приложение
3. **Закройте или сверните мобильное приложение** (чтобы пользователь был "offline")
4. Отправьте еще одно сообщение из web-клиента
5. На мобильном устройстве должно появиться push-уведомление

### 4.3 Проверка логов backend

```bash
docker compose logs -f maymessenger_backend | grep -i "push\|firebase"
```

Должны увидеть:
```
Sending push notification to user <userId>, <count> tokens
```

## 5. Структура БД

### Таблица FcmTokens

| Поле | Тип | Описание |
|------|-----|----------|
| Id | Guid | Уникальный ID токена |
| UserId | Guid | ID пользователя |
| Token | string(500) | FCM токен устройства |
| DeviceInfo | string(200) | Информация об устройстве (OS, модель) |
| RegisteredAt | DateTime | Время регистрации токена |
| LastUsedAt | DateTime? | Последнее использование токена |
| IsActive | bool | Активен ли токен |

### Миграция

Таблица создается автоматически при первом запуске backend после обновления.

Для применения миграции вручную:
```bash
cd _may_messenger_backend
dotnet ef database update --project src/MayMessenger.Infrastructure
```

## 6. API Endpoints

### POST /api/notifications/register-token

Регистрация FCM токена для пользователя.

**Request**:
```json
{
  "token": "fcm_token_here",
  "deviceInfo": "Android 13 - Pixel 6"
}
```

**Headers**:
- `Authorization: Bearer <JWT_TOKEN>`

### POST /api/notifications/deactivate-token

Деактивация FCM токена (при logout).

**Request**:
```json
{
  "token": "fcm_token_here"
}
```

### GET /api/notifications/tokens

Получение списка активных токенов текущего пользователя.

**Response**:
```json
{
  "count": 2,
  "tokens": [
    {
      "id": "...",
      "userId": "...",
      "token": "...",
      "deviceInfo": "Android 13 - Pixel 6",
      "registeredAt": "2024-01-15T10:30:00Z",
      "lastUsedAt": "2024-01-15T12:45:00Z",
      "isActive": true
    }
  ]
}
```

## 7. Troubleshooting

### Проблема: "Firebase not initialized"

**Решение**:
1. Проверьте, что файл `firebase_config.json` существует в Docker volume:
   ```bash
   docker run --rm -v maymessenger_firebase:/data alpine ls -la /data
   ```
2. Проверьте права доступа к файлу
3. Перезапустите backend

### Проблема: "google-services.json not found"

**Решение**:
1. Убедитесь, что файл в правильной директории: `android/app/google-services.json`
2. Проверьте, что package name в `google-services.json` совпадает с `applicationId` в `build.gradle.kts`
3. Пересоберите приложение: `flutter clean && flutter pub get`

### Проблема: Push уведомления не приходят

**Решение**:
1. Проверьте, что приложение свернуто или закрыто (foreground notifications требуют отдельной обработки)
2. Проверьте логи backend на наличие ошибок отправки
3. Убедитесь, что FCM токен зарегистрирован (см. раздел 4.1)
4. Проверьте, что устройство имеет стабильное интернет-соединение
5. Проверьте, что Google Play Services установлены и обновлены (Android)

### Проблема: Build error "Duplicate class"

**Решение**:
```bash
cd _may_messenger_mobile_app/android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

## 8. Безопасность

### Service Account JSON

- ❌ Никогда не коммитьте в Git
- ❌ Никогда не отправляйте по незащищенным каналам
- ✅ Храните в защищенном месте (например, `_may_messenger_secrets/`)
- ✅ Используйте Setup Page для загрузки на сервер
- ✅ После загрузки на сервер файл сохраняется в Docker volume

### google-services.json

- ❌ Не коммитьте в Git
- ✅ Добавлен в `.gitignore`
- ✅ Каждый разработчик должен получить свою копию из Firebase Console

### FCM Tokens

- Токены хранятся в БД с шифрованием (через PostgreSQL)
- При logout токен деактивируется (не удаляется, для аналитики)
- Токены автоматически обновляются при изменении

## 9. Файлы проекта

### Backend

- `src/MayMessenger.API/FirebaseSetup/index.html` - Setup UI
- `src/MayMessenger.API/Controllers/SetupController.cs` - Setup API
- `src/MayMessenger.Application/Services/FirebaseService.cs` - Firebase Admin SDK
- `src/MayMessenger.API/Controllers/NotificationsController.cs` - FCM token management
- `src/MayMessenger.API/Controllers/MessagesController.cs` - Push sending logic
- `src/MayMessenger.Domain/Entities/FcmToken.cs` - Entity
- `src/MayMessenger.Infrastructure/Repositories/FcmTokenRepository.cs` - Repository

### Mobile App

- `lib/core/services/fcm_service.dart` - FCM client service
- `lib/presentation/providers/auth_provider.dart` - Auto-registration logic
- `android/app/google-services.json` - Firebase config (не коммитится)
- `android/app/build.gradle.kts` - Google Services plugin
- `android/settings.gradle.kts` - Plugin classpath

### Infrastructure

- `docker-compose.yml` - `maymessenger_firebase` volume
- `nginx/nginx_prod.conf` - `/messenger/setup/` route

## 10. Следующие шаги

После успешной настройки:

1. ✅ Протестируйте на нескольких устройствах
2. ✅ Настройте мониторинг Firebase Console → Cloud Messaging
3. ✅ Настройте rate limiting для предотвращения спама
4. ⬜ Реализуйте foreground notifications (когда приложение открыто)
5. ⬜ Добавьте rich notifications (изображения, действия)
6. ⬜ Настройте topics для групповых уведомлений
7. ⬜ Реализуйте iOS push notifications (APNs)

## 11. Дополнительные ресурсы

- [Firebase Cloud Messaging Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Firebase Admin SDK for .NET](https://firebase.google.com/docs/admin/setup#dotnet)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [FCM HTTP v1 API Reference](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)
