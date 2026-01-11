# Подробная инструкция по настройке Firebase для проекта Депеша

## Текущее состояние

У вас уже есть файл `firebase_service_account.json` в папке `_may_messenger_secrets`. Теперь нужно добавить конфигурационные файлы для мобильных приложений.

## Что нужно создать

1. **google-services.json** (для Android)
2. **GoogleService-Info.plist** (для iOS)
3. **Настроить APNs** (для iOS Push Notifications)

---

## Часть 1: Создание google-services.json для Android

### Шаг 1: Войдите в Firebase Console

1. Откройте https://console.firebase.google.com
2. Войдите с тем же Google аккаунтом, который использовался для создания проекта

### Шаг 2: Найдите или создайте Android приложение

1. Выберите ваш проект Firebase (вероятно, называется MayMessenger или подобное)
2. На главной странице проекта найдите секцию **Your apps**
3. Если Android приложение уже существует:
   - Найдите приложение с package name `com.depesha`
   - Нажмите на иконку настроек (⚙️) → **Project settings**
4. Если Android приложения нет:
   - Нажмите **Add app** → выберите Android (иконка робота)
   - Заполните форму:
     ```
     Android package name: com.depesha
     App nickname: Депеша Android (опционально)
     Debug signing certificate SHA-1: (можно оставить пустым)
     ```
   - Нажмите **Register app**

### Шаг 3: Скачайте google-services.json

1. В Firebase Console → Project Settings → Your apps
2. Найдите Android приложение
3. Нажмите **Download google-services.json**
4. Файл скачается в папку Downloads

### Шаг 4: Скопируйте файл в проект

Выполните эти команды в терминале:

```bash
# Скопируйте в проект Android
cp ~/Downloads/google-services.json /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json

# Сохраните резервную копию в secrets
cp ~/Downloads/google-services.json /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/google-services.json

# Проверьте, что файл скопирован
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json

# Проверьте package name (должно быть com.depesha)
grep package_name /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json
```

### Шаг 5: Проверка содержимого

Файл должен содержать:

```json
{
  "project_info": {
    "project_number": "123456789",
    "project_id": "your-project-id",
    ...
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:123456789:android:abcdef",
        "android_client_info": {
          "package_name": "com.depesha"
        }
      },
      ...
    }
  ]
}
```

**ВАЖНО**: `package_name` ДОЛЖЕН быть `com.depesha` (как в вашем `android/app/build.gradle.kts`)

---

## Часть 2: Создание GoogleService-Info.plist для iOS

### Шаг 1: Добавление iOS приложения в Firebase

1. В Firebase Console выберите ваш проект
2. На главной странице найдите секцию **Your apps**
3. Если iOS приложение уже существует:
   - Найдите приложение с Bundle ID `com.maymessenger.mobileApp`
   - Нажмите на иконку настроек (⚙️)
4. Если iOS приложения нет:
   - Нажмите **Add app** → выберите iOS (иконка Apple)
   - Заполните форму:
     ```
     iOS bundle ID: com.maymessenger.mobileApp
     App nickname: Депеша iOS (опционально)
     App Store ID: (оставьте пустым, добавите позже)
     ```
   - Нажмите **Register app**

### Шаг 2: Скачайте GoogleService-Info.plist

1. На следующем экране нажмите **Download GoogleService-Info.plist**
2. Или в Project Settings → Your apps → iOS app → Download config file
3. Файл скачается в папку Downloads

### Шаг 3: Скопируйте файл в проект

```bash
# Скопируйте в проект iOS
cp ~/Downloads/GoogleService-Info.plist /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist

# Сохраните резервную копию в secrets
cp ~/Downloads/GoogleService-Info.plist /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/GoogleService-Info.plist

# Проверьте, что файл скопирован
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist

# Проверьте Bundle ID (должен быть com.maymessenger.mobileApp)
grep BUNDLE_ID /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist
```

### Шаг 4: ОБЯЗАТЕЛЬНО - Добавьте файл в Xcode

**Это критически важный шаг!** Просто скопировать файл недостаточно.

1. Откройте проект в Xcode:
   ```bash
   cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app
   open ios/Runner.xcworkspace
   ```

2. В Xcode:
   - В левой панели (Project Navigator) найдите папку **Runner**
   - Правый клик на папке **Runner** → **Add Files to "Runner"...**
   - Перейдите в папку `ios/Runner/`
   - Выберите файл `GoogleService-Info.plist`
   - В диалоге добавления файла:
     * ✅ Отметьте **"Copy items if needed"**
     * ✅ В секции "Add to targets" отметьте **Runner**
   - Нажмите **Add**

3. Проверьте:
   - Файл `GoogleService-Info.plist` должен быть виден в левой панели Xcode под папкой Runner
   - Кликните на файл - должно открыться его содержимое

### Шаг 5: Проверка содержимого

Файл должен содержать:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BUNDLE_ID</key>
    <string>com.maymessenger.mobileApp</string>
    <key>PROJECT_ID</key>
    <string>your-project-id</string>
    <key>GOOGLE_APP_ID</key>
    <string>1:xxxx:ios:xxxx</string>
    ...
</dict>
</plist>
```

**ВАЖНО**: `BUNDLE_ID` ДОЛЖЕН быть `com.maymessenger.mobileApp`

---

## Часть 3: Настройка Push Notifications для iOS (APNs)

Для работы push-уведомлений на iOS необходимо создать APNs ключ и загрузить его в Firebase.

### Шаг 1: Создание APNs Authentication Key в Apple Developer Portal

**Требования**: У вас должен быть активный Apple Developer Account ($99/год)

1. Откройте https://developer.apple.com/account/
2. Войдите с вашим Apple ID
3. Перейдите в **Certificates, Identifiers & Profiles**
4. В левом меню выберите **Keys**
5. Нажмите кнопку **+** (создать новый ключ)

6. Заполните форму:
   ```
   Key Name: Depesha Push Notifications Key
   ✅ Apple Push Notifications service (APNs)
   ```

7. Нажмите **Continue**
8. Нажмите **Register**

9. **КРИТИЧЕСКИ ВАЖНО**:
   - Нажмите **Download** и сохраните файл `.p8`
   - **Этот ключ можно скачать только один раз!**
   - Если потеряете, придётся создавать новый

10. Запишите важную информацию:
    - **Key ID**: отображается на экране (например: `ABC1234DEF`)
    - **Team ID**: в правом верхнем углу страницы (например: `XYZ9876543`)

### Шаг 2: Сохраните ключ в безопасное место

```bash
# Переименуйте и сохраните ключ
mv ~/Downloads/AuthKey_ABC1234DEF.p8 /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/AuthKey_APNs_iOS.p8

# Проверьте
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/AuthKey_APNs_iOS.p8
```

### Шаг 3: Загрузка APNs Key в Firebase

1. Откройте Firebase Console → ваш проект
2. Нажмите на ⚙️ (Settings) → **Project settings**
3. Перейдите на вкладку **Cloud Messaging**
4. Прокрутите до секции **Apple app configuration**
5. Найдите подсекцию **APNs Authentication Key**
6. Нажмите **Upload**

7. В диалоге:
   - **APNs Authentication Key**: Выберите файл `.p8` из `_may_messenger_secrets/`
   - **Key ID**: Введите Key ID из шага 1 (например: `ABC1234DEF`)
   - **Team ID**: Введите Team ID из шага 1 (например: `XYZ9876543`)

8. Нажмите **Upload**

9. Должно появиться сообщение: "APNs certificate uploaded successfully"

### Шаг 4: Проверка настройки

1. В Firebase Console → Cloud Messaging
2. В секции **Apple app configuration** должно быть:
   - ✅ APNs Authentication Key: Key ID: ABC1234DEF
   - Team ID: XYZ9876543

---

## Часть 4: Включение Cloud Messaging API

### Для обеих платформ (Android и iOS)

1. В Firebase Console → Project Settings → Cloud Messaging
2. В секции **Cloud Messaging API**:
   - Если API отключен, нажмите **Enable**
   - Должно быть: ✅ **Cloud Messaging API (V1)**: Enabled

3. Также проверьте:
   - ✅ **Firebase Cloud Messaging API**: Enabled

---

## Часть 5: Проверка настройки

### Финальный чек-лист

Проверьте наличие всех файлов:

```bash
# Android
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/google-services.json

# iOS
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/GoogleService-Info.plist

# APNs Key
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/AuthKey_APNs_iOS.p8
```

### Структура _may_messenger_secrets

После выполнения всех шагов папка должна содержать:

```
_may_messenger_secrets/
├── firebase_service_account.json       (уже существует)
├── google-services.json                (новый - Android)
├── GoogleService-Info.plist            (новый - iOS)
└── AuthKey_APNs_iOS.p8                 (новый - iOS Push)
```

---

## Часть 6: Тестирование

### Тест 1: Запуск приложения

```bash
cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app

# iOS
flutter run -d "iPhone 15 Pro"

# Android
flutter run -d <android_device_id>
```

### Тест 2: Проверка логов Firebase

При запуске приложения в консоли должны появиться логи:

```
[Firebase] initialized successfully
[FCM] Initial token: eyJhbGciOiJSUzI1NiIsInR5cCI...
```

### Тест 3: Проверка в Firebase Console

1. Откройте Firebase Console → **Engagement** → **Cloud Messaging**
2. Попробуйте отправить тестовое уведомление:
   - **Notification title**: Тест
   - **Notification text**: Проверка push-уведомлений
   - **Target**: Select app → iOS или Android
   - Нажмите **Send test message**
   - Введите FCM token из логов приложения
   - Нажмите **Test**

3. Уведомление должно прийти на устройство

---

## Устранение неполадок

### Проблема: google-services.json не найден при сборке Android

```bash
# Проверьте расположение файла
ls -l /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json

# Если файла нет, скопируйте снова
cp /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/google-services.json \
   /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/

# Пересоберите проект
flutter clean
flutter pub get
flutter build apk
```

### Проблема: Firebase не инициализируется на iOS

1. Убедитесь, что `GoogleService-Info.plist` добавлен в Xcode проект:
   ```bash
   open ios/Runner.xcworkspace
   ```
   - Файл должен быть виден в Project Navigator

2. Если файла нет в Xcode:
   - Удалите файл из файловой системы
   - Скопируйте заново
   - Добавьте через Xcode (Add Files to "Runner"...)

3. Очистите и пересоберите:
   ```bash
   flutter clean
   cd ios
   pod deintegrate
   pod install
   cd ..
   flutter run
   ```

### Проблема: Push уведомления не приходят на iOS

1. **Проверьте APNs ключ в Firebase**:
   - Firebase Console → Cloud Messaging → Apple app configuration
   - Должен быть загружен .p8 ключ

2. **Проверьте entitlements в Xcode**:
   - Откройте `ios/Runner.xcworkspace`
   - Runner → Signing & Capabilities
   - Должен быть раздел **Push Notifications**
   - Если нет, нажмите **+ Capability** → **Push Notifications**

3. **Тестируйте на реальном устройстве**:
   - Симулятор iOS НЕ поддерживает push уведомления
   - Используйте реальный iPhone

4. **Проверьте Bundle ID**:
   ```bash
   # В Xcode: Runner → General → Bundle Identifier
   # Должно быть: com.maymessenger.mobileApp
   
   # В GoogleService-Info.plist:
   grep BUNDLE_ID ios/Runner/GoogleService-Info.plist
   # Должно совпадать
   ```

### Проблема: "Default FirebaseApp is not configured"

Это означает, что Firebase не может найти конфигурационный файл.

**Для Android**:
- Проверьте `android/app/google-services.json`
- Пересоберите: `flutter clean && flutter pub get`

**Для iOS**:
- Откройте Xcode и убедитесь, что `GoogleService-Info.plist` в проекте
- Если файл серый (не в проекте), удалите и добавьте снова
- Файл должен быть в **Copy Bundle Resources** (Target → Build Phases)

---

## Резюме команд

```bash
# Копирование конфигурационных файлов

# Android
cp ~/Downloads/google-services.json \
   /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json
cp ~/Downloads/google-services.json \
   /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/google-services.json

# iOS
cp ~/Downloads/GoogleService-Info.plist \
   /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist
cp ~/Downloads/GoogleService-Info.plist \
   /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/GoogleService-Info.plist

# APNs Key
mv ~/Downloads/AuthKey_*.p8 \
   /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/AuthKey_APNs_iOS.p8

# Открытие Xcode для добавления GoogleService-Info.plist
cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app
open ios/Runner.xcworkspace

# После добавления файлов - подготовка проекта
flutter clean
flutter pub get
flutter pub run flutter_launcher_icons
cd ios && pod install && cd ..

# Запуск
flutter run
```

---

## Контакты и поддержка

Если возникли проблемы:
- Проверьте логи: `flutter run --verbose`
- Документация Firebase: https://firebase.google.com/docs
- Flutter Firebase: https://firebase.flutter.dev/

**Файлы документации проекта:**
- `IOS_DEPLOYMENT_GUIDE.md` - развёртывание iOS
- `SETUP_FLUTTER_AND_FIREBASE.md` - установка инструментов
- `FIREBASE_CONFIG_GUIDE.md` - этот файл
