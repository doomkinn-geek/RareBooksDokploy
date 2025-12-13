# Резюме изменений - Firebase Push Notifications + Fixes

## Исправления

### 1. ✅ signalr_provider.dart - Исправлен краш при пустом списке чатов

**Проблема**: `firstWhere().orElse(() => chatsState.chats.first)` падал с `IndexError`, если список чатов пустой.

**Решение**: Добавлена проверка `chatsState.chats.isEmpty` перед попыткой получить чат. Если список пустой, уведомление пропускается.

```dart
if (chatsState.chats.isEmpty) {
  _logger.debug('signalr_provider.onReceiveMessage.noChats', '[H1] Chats list is empty, skipping notification', {'messageId': message.id});
  return;
}
```

## Firebase Push Notifications - Полная реализация

### Backend

#### 1. ✅ Setup System
- `FirebaseSetup/index.html` - UI для загрузки Service Account JSON
- `SetupController.cs` - API endpoints для инициализации Firebase
- Доступ: `https://messenger.rare-books.ru/messenger/setup/`

#### 2. ✅ Firebase Admin SDK Integration
- `FirebaseService.cs` - Сервис для отправки push уведомлений
- `FcmToken` entity - Хранение FCM токенов пользователей
- `FcmTokenRepository` - Работа с токенами в БД
- EF Core миграция `AddFcmTokens` - Создание таблицы

#### 3. ✅ Push Notification Logic
- `MessagesController.cs` - Автоматическая отправка push offline пользователям
- `NotificationsController.cs` - Регистрация/деактивация токенов
- Push отправляется после каждого сообщения (текст/аудио)

#### 4. ✅ Infrastructure
- Docker volume `maymessenger_firebase` для хранения конфигурации
- Nginx route `/messenger/setup/` для Setup страницы
- Автоматическая инициализация Firebase при старте backend

### Mobile App

#### 1. ✅ FCM Service Enhancement
- `device_info_plus` dependency добавлена
- `_getDeviceInfo()` - Получение информации об устройстве (OS, модель)
- `registerToken()` - Отправка токена с deviceInfo на backend

#### 2. ✅ Auto-registration after Auth
- `auth_provider.dart` - Автоматическая регистрация FCM токена после login/register
- `_registerFcmToken()` - Метод регистрации токена
- Не блокирует auth flow при ошибке регистрации токена

#### 3. ✅ Android Configuration
- `google-services.json` README с инструкциями
- `build.gradle.kts` - Google Services plugin применен
- `.gitignore` - Firebase конфиги исключены из Git

### Документация

#### ✅ FIREBASE_SETUP.md
Полное руководство по настройке Firebase Push Notifications:
- Создание Firebase проекта
- Получение Service Account JSON и google-services.json
- Инициализация backend (Setup Page + ручная установка)
- Сборка мобильного приложения
- Тестирование и troubleshooting
- API endpoints
- Безопасность
- Файловая структура

## Файлы изменены

### Backend
- `src/MayMessenger.API/FirebaseSetup/index.html` (создан)
- `src/MayMessenger.API/Controllers/SetupController.cs` (создан)
- `src/MayMessenger.Application/Services/FirebaseService.cs` (создан)
- `src/MayMessenger.Domain/Entities/FcmToken.cs` (создан)
- `src/MayMessenger.Domain/Interfaces/IFcmTokenRepository.cs` (создан)
- `src/MayMessenger.Infrastructure/Repositories/FcmTokenRepository.cs` (создан)
- `src/MayMessenger.API/Controllers/MessagesController.cs` (изменен)
- `src/MayMessenger.API/Controllers/NotificationsController.cs` (изменен)
- `src/MayMessenger.Infrastructure/Data/AppDbContext.cs` (изменен)
- `src/MayMessenger.Domain/Interfaces/IUnitOfWork.cs` (изменен)
- `src/MayMessenger.Infrastructure/Repositories/UnitOfWork.cs` (изменен)
- `src/MayMessenger.API/Program.cs` (изменен)
- `src/MayMessenger.API/appsettings.json` (изменен)
- `src/MayMessenger.API/MayMessenger.API.csproj` (изменен)
- `src/MayMessenger.Application/MayMessenger.Application.csproj` (изменен)
- `src/MayMessenger.Infrastructure/Migrations/AddFcmTokens.cs` (создан миграцией)

### Mobile App
- `lib/presentation/providers/signalr_provider.dart` (исправлен crash)
- `lib/core/services/fcm_service.dart` (улучшен)
- `lib/presentation/providers/auth_provider.dart` (интеграция FCM)
- `pubspec.yaml` (добавлен device_info_plus)
- `android/app/GOOGLE_SERVICES_README.md` (создан)
- `android/app/build.gradle.kts` (изменен)
- `android/settings.gradle.kts` (изменен)
- `.gitignore` (обновлен)

### Infrastructure
- `docker-compose.yml` (добавлен volume maymessenger_firebase)
- `nginx/nginx_prod.conf` (добавлен route /messenger/setup/)

### Документация
- `FIREBASE_SETUP.md` (создан)

## Следующие шаги

1. **Копирование Firebase конфигов**:
   - Скопируйте `firebase_service_account.json` в `_may_messenger_secrets/`
   - Скопируйте `google-services.json` в `_may_messenger_mobile_app/android/app/`

2. **Деплой на сервер**:
   ```bash
   git pull origin master
   docker compose down
   docker compose build maymessenger_backend
   docker compose up -d
   ```

3. **Инициализация Firebase**:
   - Откройте `https://messenger.rare-books.ru/messenger/setup/`
   - Вставьте содержимое `firebase_service_account.json`
   - Нажмите "Инициализировать Firebase"
   - Перезапустите backend: `docker compose restart maymessenger_backend`

4. **Пересборка мобильного приложения**:
   ```bash
   cd _may_messenger_mobile_app
   flutter pub get
   flutter build apk --release
   ```

5. **Тестирование**:
   - Установите приложение на устройство
   - Войдите в систему
   - Проверьте регистрацию FCM токена (логи backend)
   - Отправьте сообщение из web-клиента
   - Сверните приложение → должно прийти push-уведомление

## Полезные команды

```bash
# Логи backend
docker compose logs -f maymessenger_backend | grep -i "push\|firebase"

# Проверка конфига Firebase в volume
docker run --rm -v maymessenger_firebase:/data alpine ls -la /data

# Проверка токенов через API
curl -X GET https://messenger.rare-books.ru/api/notifications/tokens \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

Для подробной информации см. `FIREBASE_SETUP.md`.
