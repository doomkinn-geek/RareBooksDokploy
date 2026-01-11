# Руководство по развёртыванию iOS приложения Депеша

## Содержание
1. [Требования](#требования)
2. [Настройка Apple Developer Account](#настройка-apple-developer-account)
3. [Настройка Firebase для iOS](#настройка-firebase-для-ios)
4. [Локальная сборка и тестирование](#локальная-сборка-и-тестирование)
5. [Установка на тестовый iPhone](#установка-на-тестовый-iphone)
6. [Публикация в TestFlight](#публикация-в-testflight)
7. [Публикация в App Store](#публикация-в-app-store)
8. [Устранение неполадок](#устранение-неполадок)

---

## Требования

### Аппаратные требования
- Mac с macOS 12.0 (Monterey) или новее
- Минимум 8 ГБ оперативной памяти (рекомендуется 16 ГБ)
- 50+ ГБ свободного места на диске

### Программное обеспечение
- **Xcode 15.0** или новее (скачать из Mac App Store)
- **Flutter SDK 3.19+** 
- **CocoaPods** (менеджер зависимостей для iOS)
- **Apple Developer Account** (99$ в год для публикации)

### Установка необходимых инструментов

```bash
# Установка Homebrew (если не установлен)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Установка CocoaPods
sudo gem install cocoapods

# Или через Homebrew
brew install cocoapods

# Проверка версии Flutter
flutter --version

# Проверка Flutter doctor
flutter doctor
```

---

## Настройка Apple Developer Account

### Шаг 1: Регистрация аккаунта разработчика

1. Перейдите на [developer.apple.com](https://developer.apple.com)
2. Войдите или создайте Apple ID
3. Зарегистрируйтесь в Apple Developer Program ($99/год)
4. Дождитесь подтверждения (обычно 24-48 часов)

### Шаг 2: Создание App ID

1. Откройте [Apple Developer Portal](https://developer.apple.com/account/)
2. Перейдите в **Certificates, Identifiers & Profiles**
3. Выберите **Identifiers** → **App IDs** → **+**
4. Выберите **App** → **Continue**
5. Заполните:
   - **Description**: Депеша Messenger
   - **Bundle ID**: `com.maymessenger.mobileApp` (Explicit)
6. В разделе **Capabilities** включите:
   - ✅ Push Notifications
   - ✅ Associated Domains (опционально, для deep links)
   - ✅ Access WiFi Information
7. Нажмите **Continue** → **Register**

### Шаг 3: Создание Push Notification Key (APNs)

1. В Developer Portal перейдите в **Keys**
2. Нажмите **+** для создания нового ключа
3. Заполните:
   - **Key Name**: Depesha Push Key
   - ✅ Apple Push Notifications service (APNs)
4. Нажмите **Continue** → **Register**
5. **ВАЖНО**: Скачайте ключ (.p8 файл) - он скачивается только один раз!
6. Запишите **Key ID** и **Team ID**

### Шаг 4: Создание Provisioning Profiles

#### Development Profile (для тестирования)
1. **Profiles** → **+**
2. Выберите **iOS App Development**
3. Выберите созданный App ID
4. Выберите сертификат разработчика
5. Выберите устройства для тестирования
6. Назовите профиль: `Depesha Development`
7. Скачайте и установите двойным кликом

#### Distribution Profile (для App Store)
1. **Profiles** → **+**
2. Выберите **App Store Connect**
3. Выберите App ID
4. Выберите Distribution сертификат
5. Назовите профиль: `Depesha Distribution`
6. Скачайте профиль

---

## Настройка Firebase для iOS

### Шаг 1: Добавление iOS приложения в Firebase

1. Откройте [Firebase Console](https://console.firebase.google.com)
2. Выберите существующий проект или создайте новый
3. Нажмите **Add app** → выберите **iOS**
4. Заполните:
   - **iOS bundle ID**: `com.maymessenger.mobileApp`
   - **App nickname**: Депеша iOS
   - **App Store ID**: (оставьте пустым, добавите позже)
5. Нажмите **Register app**

### Шаг 2: Скачивание GoogleService-Info.plist

1. Скачайте файл `GoogleService-Info.plist`
2. Скопируйте его в папку:
   ```
   _may_messenger_mobile_app/ios/Runner/GoogleService-Info.plist
   ```
3. **ВАЖНО**: Откройте Xcode и добавьте файл в проект:
   - Откройте `ios/Runner.xcworkspace` в Xcode
   - Правый клик на папке **Runner** → **Add Files to "Runner"...**
   - Выберите `GoogleService-Info.plist`
   - Убедитесь, что отмечен **Copy items if needed**
   - Target: **Runner** должен быть выбран
   - Нажмите **Add**

### Шаг 3: Настройка APNs в Firebase

1. В Firebase Console перейдите в **Project Settings** → **Cloud Messaging**
2. В секции **Apple app configuration** нажмите **Upload**
3. Загрузите скачанный .p8 ключ APNs
4. Введите **Key ID** и **Team ID**
5. Нажмите **Upload**

---

## Локальная сборка и тестирование

### Шаг 1: Подготовка проекта

```bash
# Перейдите в папку проекта
cd _may_messenger_mobile_app

# Получите зависимости Flutter
flutter pub get

# Перейдите в папку iOS
cd ios

# Установите Pod зависимости
pod install

# Если возникают ошибки, попробуйте:
pod repo update
pod deintegrate
pod install --repo-update

# Вернитесь в корень проекта
cd ..
```

### Шаг 2: Генерация иконок

```bash
# Генерация иконок для iOS и Android
flutter pub run flutter_launcher_icons
```

### Шаг 3: Открытие в Xcode

```bash
# Откройте проект в Xcode
open ios/Runner.xcworkspace
```

**ВАЖНО**: Всегда открывайте `.xcworkspace`, а не `.xcodeproj`!

### Шаг 4: Настройка Signing в Xcode

1. В Xcode выберите **Runner** в левой панели
2. Перейдите на вкладку **Signing & Capabilities**
3. Выберите **Team** - ваш Apple Developer Team
4. Убедитесь, что **Bundle Identifier** = `com.maymessenger.mobileApp`
5. Xcode автоматически создаст/скачает Provisioning Profile

### Шаг 5: Сборка для симулятора

```bash
# Запуск на симуляторе iOS
flutter run -d "iPhone 15 Pro"

# Или конкретная версия
flutter run -d "iPhone 15"
```

---

## Установка на тестовый iPhone

### Способ 1: Через Xcode (рекомендуется для разработки)

1. Подключите iPhone к Mac через USB
2. На iPhone: **Настройки** → **Конфиденциальность и безопасность** → **Режим разработчика** → Включить
3. Доверьте компьютеру при появлении запроса на iPhone
4. В Xcode выберите ваш iPhone в списке устройств (вверху)
5. Нажмите **▶ (Run)** или `Cmd + R`
6. При первом запуске на iPhone:
   - **Настройки** → **Основные** → **VPN и управление устройством**
   - Нажмите на сертификат разработчика → **Доверять**

### Способ 2: Через Flutter CLI

```bash
# Показать список подключённых устройств
flutter devices

# Запуск на конкретном устройстве
flutter run -d <device_id>

# Сборка IPA для тестирования
flutter build ipa --debug
```

### Способ 3: Через Ad Hoc Distribution

1. Добавьте UDID устройства в Apple Developer Portal:
   - **Devices** → **+**
   - Введите UDID (можно узнать через Finder или `system_profiler SPUSBDataType`)
2. Пересоздайте Provisioning Profile с новым устройством
3. Соберите IPA:
   ```bash
   flutter build ipa --release --export-method ad-hoc
   ```
4. Установите через Apple Configurator 2 или AltStore

---

## Публикация в TestFlight

TestFlight позволяет распространять бета-версии до 10,000 тестировщикам.

### Шаг 1: Подготовка к публикации

1. Убедитесь, что все данные в `pubspec.yaml` корректны:
   ```yaml
   version: 0.8.1+2  # Версия и номер сборки
   ```

2. Обновите версию при необходимости:
   ```bash
   # Формат: version: <MARKETING_VERSION>+<BUILD_NUMBER>
   # BUILD_NUMBER должен увеличиваться с каждой загрузкой
   ```

### Шаг 2: Сборка Release IPA

```bash
# Полная очистка (рекомендуется перед релизом)
flutter clean
flutter pub get
cd ios && pod install && cd ..

# Сборка релизной версии
flutter build ipa --release

# IPA будет создан в:
# build/ios/ipa/mobile_app.ipa
```

### Шаг 3: Создание приложения в App Store Connect

1. Откройте [App Store Connect](https://appstoreconnect.apple.com)
2. **My Apps** → **+** → **New App**
3. Заполните:
   - **Platform**: iOS
   - **Name**: Депеша
   - **Primary Language**: Russian
   - **Bundle ID**: com.maymessenger.mobileApp
   - **SKU**: depesha-messenger-ios
   - **User Access**: Full Access
4. Нажмите **Create**

### Шаг 4: Загрузка через Xcode

1. Откройте Xcode
2. **Window** → **Organizer** (`Cmd + Shift + Option + O`)
3. Выберите архив в списке
4. Нажмите **Distribute App**
5. Выберите **App Store Connect**
6. Выберите **Upload**
7. Следуйте инструкциям, выберите сертификат
8. Дождитесь загрузки

### Альтернатива: Загрузка через Transporter

1. Скачайте **Transporter** из Mac App Store
2. Откройте приложение, войдите с Apple ID
3. Перетащите `.ipa` файл
4. Нажмите **Deliver**

### Шаг 5: Настройка TestFlight

1. В App Store Connect выберите ваше приложение
2. Перейдите в **TestFlight**
3. Дождитесь обработки сборки (10-30 минут)
4. Заполните информацию для тестирования:
   - Что тестировать
   - Контактные данные
5. Добавьте тестировщиков:
   - **Internal Testing**: до 100 членов команды
   - **External Testing**: до 10,000 пользователей
6. Отправьте приглашения

---

## Публикация в App Store

### Шаг 1: Подготовка метаданных

В App Store Connect заполните:

#### Информация о приложении
- **Название**: Депеша
- **Подзаголовок**: Безопасный мессенджер
- **Описание**: Полное описание функций (4000 символов)
- **Ключевые слова**: мессенджер, чат, общение, безопасность
- **URL поддержки**: https://your-domain.com/support
- **URL маркетинга**: https://your-domain.com
- **Политика конфиденциальности**: https://your-domain.com/privacy

#### Скриншоты (обязательно)
Минимум для каждого размера экрана:
- iPhone 6.7" (1290 × 2796 px) - iPhone 15 Pro Max
- iPhone 6.5" (1284 × 2778 px) - iPhone 14 Plus
- iPhone 5.5" (1242 × 2208 px) - iPhone 8 Plus

Рекомендуется также:
- iPad Pro 12.9" (2048 × 2732 px)

#### Иконка приложения
- 1024 × 1024 px PNG без прозрачности

### Шаг 2: Конфиденциальность данных

В разделе **App Privacy** укажите:
- Какие данные собираются
- Для чего используются
- Связаны ли с пользователем
- Используются ли для отслеживания

Для мессенджера типично:
- ✅ Contact Info (телефон, для регистрации)
- ✅ User Content (сообщения)
- ✅ Identifiers (Device ID для push)

### Шаг 3: Отправка на проверку

1. В разделе **App Store** → **iOS App** выберите сборку
2. Ответьте на вопросы:
   - Export Compliance (шифрование)
   - Content Rights
   - Advertising Identifier
3. Нажмите **Submit for Review**

### Шаг 4: Проверка Apple (App Review)

- **Срок проверки**: обычно 24-48 часов
- При отклонении исправьте замечания и отправьте повторно
- Общайтесь с рецензентами через Resolution Center

---

## Устранение неполадок

### Ошибка: "No Provisioning Profile"

```bash
# Обновите сертификаты в Xcode
Xcode → Preferences → Accounts → Download Manual Profiles
```

### Ошибка: "Module 'Firebase' not found"

```bash
cd ios
pod deintegrate
pod cache clean --all
pod install --repo-update
```

### Ошибка: "Signing requires a development team"

1. Откройте Xcode
2. Runner → Signing & Capabilities
3. Выберите Team из списка

### Ошибка сборки на M1/M2 Mac

```bash
# Откройте терминал через Rosetta для pod install
arch -x86_64 pod install

# Или добавьте в Podfile:
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

### Push уведомления не работают

1. Проверьте, что APNs ключ загружен в Firebase
2. Убедитесь, что `GoogleService-Info.plist` добавлен в Xcode
3. Проверьте Bundle ID - должен совпадать везде
4. На реальном устройстве (симулятор не поддерживает push)

### Приложение вылетает при запуске

```bash
# Проверьте логи
flutter run --verbose

# Очистите кеш
flutter clean
cd ios && pod deintegrate && pod install
flutter run
```

---

## Полезные команды

```bash
# Проверка окружения
flutter doctor -v

# Список симуляторов
xcrun simctl list devices

# Сборка для конкретной архитектуры
flutter build ios --release --no-codesign

# Архивация через xcodebuild
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive

# Экспорт IPA
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ios/ipa \
  -exportOptionsPlist ios/ExportOptions.plist
```

---

## Контрольный список перед публикацией

- [ ] Bundle ID настроен правильно
- [ ] App ID создан в Apple Developer Portal
- [ ] Push Notifications настроены (APNs ключ в Firebase)
- [ ] GoogleService-Info.plist добавлен в проект Xcode
- [ ] Иконки сгенерированы (`flutter pub run flutter_launcher_icons`)
- [ ] Скриншоты подготовлены для всех размеров экрана
- [ ] Политика конфиденциальности опубликована
- [ ] Тестирование проведено на реальном устройстве
- [ ] Push уведомления работают
- [ ] Версия и номер сборки обновлены
- [ ] Release build работает без ошибок

---

## Дополнительные ресурсы

- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
