# Руководство по установке Flutter и настройке Firebase для iOS/Android

## Часть 1: Установка необходимых инструментов

### Шаг 1: Установка Homebrew (если не установлен)

```bash
# Установка Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# После установки добавьте Homebrew в PATH (для M1/M2 Mac)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Для Intel Mac:
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"

# Проверка установки
brew --version
```

### Шаг 2: Установка Flutter SDK

```bash
# Установка Flutter через Homebrew
brew install --cask flutter

# Или скачайте вручную:
# 1. Перейдите на https://docs.flutter.dev/get-started/install/macos
# 2. Скачайте Flutter SDK для macOS
# 3. Распакуйте в ~/development/flutter
# 4. Добавьте в PATH:

mkdir -p ~/development
cd ~/development
# Скачайте и распакуйте Flutter SDK сюда

# Добавьте Flutter в PATH
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

# Проверка установки
flutter --version

# Запустите Flutter doctor для проверки окружения
flutter doctor -v
```

### Шаг 3: Установка CocoaPods (для iOS)

```bash
# Установка CocoaPods через Homebrew (рекомендуется)
brew install cocoapods

# Или через RubyGems:
sudo gem install cocoapods

# Проверка установки
pod --version

# Инициализация репозитория CocoaPods (может занять время)
pod setup
```

### Шаг 4: Настройка Xcode Command Line Tools

```bash
# Установка Command Line Tools (если не установлены)
xcode-select --install

# Проверка пути
xcode-select -p

# Если путь неверный, установите:
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Принятие лицензии Xcode
sudo xcodebuild -license accept
```

### Шаг 5: Проверка окружения Flutter

```bash
# Полная проверка
flutter doctor -v

# Ожидаемый результат:
# ✓ Flutter (Channel stable, 3.x.x)
# ✓ Xcode - develop for iOS and macOS
# ✓ Chrome - develop for the web
# ✓ Android Studio (опционально)
# ✓ VS Code (опционально)
# ✓ Connected device (если устройство подключено)
```

### Шаг 6: Настройка Flutter для iOS

```bash
# Установка iOS симуляторов (если нужно)
xcodebuild -downloadPlatform iOS

# Запуск симулятора для проверки
open -a Simulator
```

---

## Часть 2: Настройка Firebase для iOS и Android

### Шаг 1: Вход в Firebase Console

1. Откройте [Firebase Console](https://console.firebase.google.com)
2. Войдите с Google аккаунтом
3. Если проекта нет, создайте новый:
   - Нажмите **Add project**
   - Название: `MayMessenger` (или ваше)
   - Включите Google Analytics (рекомендуется)

### Шаг 2: Добавление Android приложения

#### 2.1. Регистрация Android приложения

1. В Firebase Console выберите проект
2. Нажмите **Add app** → выберите **Android**
3. Заполните:
   - **Android package name**: `com.depesha`
   - **App nickname**: Депеша Android (опционально)
   - **Debug signing certificate SHA-1**: (опционально, для Google Sign-In)
4. Нажмите **Register app**

#### 2.2. Скачивание google-services.json

1. Скачайте файл `google-services.json`
2. Скопируйте в **две папки**:

```bash
# Скопируйте в папку приложения
cp ~/Downloads/google-services.json /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json

# Сохраните резервную копию в secrets
cp ~/Downloads/google-services.json /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/google-services.json
```

3. Проверьте, что файл содержит правильный package name:

```bash
cat /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/android/app/google-services.json | grep package_name
```

Должно быть: `"package_name": "com.depesha"`

### Шаг 3: Добавление iOS приложения

#### 3.1. Регистрация iOS приложения

1. В Firebase Console выберите проект
2. Нажмите **Add app** → выберите **iOS**
3. Заполните:
   - **iOS bundle ID**: `com.maymessenger.mobileApp`
   - **App nickname**: Депеша iOS (опционально)
   - **App Store ID**: (оставьте пустым, добавите позже)
4. Нажмите **Register app**

#### 3.2. Скачивание GoogleService-Info.plist

1. Скачайте файл `GoogleService-Info.plist`
2. Скопируйте в **две папки**:

```bash
# Скопируйте в папку приложения
cp ~/Downloads/GoogleService-Info.plist /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist

# Сохраните резервную копию в secrets
cp ~/Downloads/GoogleService-Info.plist /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/GoogleService-Info.plist
```

3. **ВАЖНО**: Добавьте файл в Xcode проект:

```bash
# Откройте проект в Xcode
cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app
open ios/Runner.xcworkspace
```

В Xcode:
- Правый клик на папке **Runner** (в левой панели)
- **Add Files to "Runner"...**
- Выберите `GoogleService-Info.plist`
- ✅ **Copy items if needed**
- ✅ **Runner** в секции "Add to targets"
- Нажмите **Add**

### Шаг 4: Настройка Firebase Cloud Messaging (FCM)

#### 4.1. Для Android

FCM для Android настроен автоматически через `google-services.json`. Дополнительных действий не требуется.

#### 4.2. Для iOS - Создание APNs Key

1. Откройте [Apple Developer Portal](https://developer.apple.com/account/)
2. **Certificates, Identifiers & Profiles** → **Keys** → **+**
3. Заполните:
   - **Key Name**: Depesha APNs Key
   - ✅ **Apple Push Notifications service (APNs)**
4. Нажмите **Continue** → **Register**
5. **ВАЖНО**: Скачайте `.p8` файл - он скачивается только один раз!
6. Запишите:
   - **Key ID** (например: `ABC1234DEF`)
   - **Team ID** (например: `XYZ9876543`)

```bash
# Сохраните ключ в безопасное место
cp ~/Downloads/AuthKey_ABC1234DEF.p8 /Users/janaplett/RareBooksDokploy/_may_messenger_secrets/AuthKey_APNs.p8
```

#### 4.3. Загрузка APNs Key в Firebase

1. В Firebase Console перейдите в **Project Settings** (⚙️)
2. Выберите вкладку **Cloud Messaging**
3. В секции **Apple app configuration**:
   - Нажмите **Upload** в секции **APNs Authentication Key**
   - Выберите `.p8` файл
   - Введите **Key ID**
   - Введите **Team ID**
   - Нажмите **Upload**

### Шаг 5: Включение Firebase Cloud Messaging

1. В Firebase Console → **Build** → **Cloud Messaging**
2. Убедитесь, что **Cloud Messaging API (Legacy)** включен
3. Также включите **Firebase Cloud Messaging API (V1)**

---

## Часть 3: Подготовка проекта Flutter

### Шаг 1: Установка зависимостей Flutter

```bash
cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app

# Получение зависимостей
flutter pub get

# Генерация иконок приложения
flutter pub run flutter_launcher_icons
```

### Шаг 2: Установка iOS зависимостей (CocoaPods)

```bash
# Переход в папку iOS
cd ios

# Установка pods
pod install

# Если возникают ошибки, попробуйте:
pod repo update
pod deintegrate
pod install --repo-update

# Возврат в корень проекта
cd ..
```

### Шаг 3: Проверка Firebase конфигурации

#### Для Android:
```bash
# Проверка google-services.json
ls -l android/app/google-services.json

# Проверка package name
grep package_name android/app/google-services.json
```

#### Для iOS:
```bash
# Проверка GoogleService-Info.plist
ls -l ios/Runner/GoogleService-Info.plist

# Проверка bundle ID
grep BUNDLE_ID ios/Runner/GoogleService-Info.plist
```

---

## Часть 4: Тестирование

### Тест 1: Запуск на симуляторе iOS

```bash
# Запуск симулятора
open -a Simulator

# Список доступных симуляторов
flutter devices

# Запуск приложения
flutter run -d "iPhone 15 Pro"
```

### Тест 2: Запуск на реальном iPhone

```bash
# Подключите iPhone через USB
# На iPhone: Настройки → Конфиденциальность и безопасность → Режим разработчика → ВКЛ

# Список устройств
flutter devices

# Запуск на устройстве
flutter run -d <device_id>
```

### Тест 3: Проверка Firebase подключения

После запуска приложения проверьте логи:

```bash
flutter run --verbose

# Должны быть логи:
# [Firebase] initialized successfully
# [FCM] Initial token: <token>
```

В Firebase Console:
1. **Build** → **Cloud Messaging** → **Device Registration**
2. Должно появиться зарегистрированное устройство

---

## Часть 5: Сборка Release версий

### Android Release Build

```bash
# Сборка APK
flutter build apk --release

# Сборка App Bundle (для Google Play)
flutter build appbundle --release

# Файлы будут в:
# build/app/outputs/flutter-apk/app-release.apk
# build/app/outputs/bundle/release/app-release.aab
```

### iOS Release Build

```bash
# Сборка IPA
flutter build ipa --release

# Файл будет в:
# build/ios/ipa/mobile_app.ipa
```

---

## Контрольный список

### Инструменты установлены:
- [ ] Homebrew
- [ ] Flutter SDK
- [ ] CocoaPods
- [ ] Xcode Command Line Tools

### Firebase настроен:
- [ ] Проект создан в Firebase Console
- [ ] Android приложение добавлено
- [ ] google-services.json скачан и скопирован в android/app/
- [ ] iOS приложение добавлено
- [ ] GoogleService-Info.plist скачан и добавлен в Xcode
- [ ] APNs Key создан в Apple Developer Portal
- [ ] APNs Key загружен в Firebase Console
- [ ] Cloud Messaging API включен

### Проект настроен:
- [ ] flutter pub get выполнен успешно
- [ ] Иконки сгенерированы
- [ ] iOS pods установлены (pod install)
- [ ] GoogleService-Info.plist добавлен в Xcode проект
- [ ] Приложение запускается на симуляторе
- [ ] Firebase инициализируется без ошибок
- [ ] FCM token получен

---

## Команды для быстрого старта

После установки всех инструментов и настройки Firebase:

```bash
#!/bin/bash
# Быстрая настройка проекта

cd /Users/janaplett/RareBooksDokploy/_may_messenger_mobile_app

# 1. Установка зависимостей
flutter clean
flutter pub get

# 2. Генерация иконок
flutter pub run flutter_launcher_icons

# 3. iOS pods
cd ios
pod deintegrate
pod install --repo-update
cd ..

# 4. Проверка окружения
flutter doctor -v

# 5. Запуск на симуляторе
flutter run -d "iPhone 15 Pro"
```

---

## Устранение неполадок

### Проблема: Flutter не найден после установки

```bash
# Проверьте PATH
echo $PATH

# Добавьте Flutter в PATH
export PATH="$PATH:$HOME/development/flutter/bin"

# Или для Homebrew установки:
export PATH="$PATH:/opt/homebrew/bin/flutter"

# Добавьте в ~/.zshrc для постоянного эффекта
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

### Проблема: pod install не работает

```bash
# Обновите Ruby (если нужно)
brew install ruby

# Переустановите CocoaPods
sudo gem uninstall cocoapods
brew install cocoapods

# Очистите кеш
pod cache clean --all
pod repo remove trunk
pod setup
```

### Проблема: Firebase не инициализируется на iOS

1. Убедитесь, что `GoogleService-Info.plist` добавлен в Xcode:
   - Откройте `Runner.xcworkspace`
   - Проверьте, что файл виден в левой панели под папкой Runner
   - Если нет, добавьте его вручную

2. Проверьте Bundle ID:
   ```bash
   # В GoogleService-Info.plist должно быть:
   grep BUNDLE_ID ios/Runner/GoogleService-Info.plist
   # Результат: <string>com.maymessenger.mobileApp</string>
   ```

3. Очистите и пересоберите:
   ```bash
   flutter clean
   cd ios
   pod deintegrate
   pod install
   cd ..
   flutter run
   ```

### Проблема: Push уведомления не работают на iOS

1. Проверьте, что APNs ключ загружен в Firebase
2. Убедитесь, что в Xcode включены Push Notifications:
   - Runner → Signing & Capabilities
   - Должен быть раздел **Push Notifications**
3. Тестируйте только на реальном устройстве (симулятор не поддерживает push)
4. Убедитесь, что разрешения запрошены в приложении

---

## Дополнительные ресурсы

- [Flutter Installation Guide](https://docs.flutter.dev/get-started/install/macos)
- [Firebase Flutter Setup](https://firebase.google.com/docs/flutter/setup)
- [Apple Developer Portal](https://developer.apple.com/account/)
- [CocoaPods Documentation](https://guides.cocoapods.org/)
