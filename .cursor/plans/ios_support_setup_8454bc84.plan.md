---
name: iOS Support Setup
overview: Настройка поддержки iOS для Flutter-мессенджера Депеша, включая конфигурационные файлы, разрешения, Firebase, и инструкции по публикации в App Store.
todos:
  - id: create-podfile
    content: Создать ios/Podfile с настройками CocoaPods
    status: completed
  - id: update-infoplist
    content: Обновить Info.plist с разрешениями для контактов, фото, камеры
    status: completed
  - id: create-entitlements
    content: Создать Runner.entitlements и RunnerDebug.entitlements
    status: completed
  - id: update-pbxproj
    content: Обновить project.pbxproj для подключения entitlements
    status: completed
  - id: update-appdelegate
    content: Обновить AppDelegate.swift для Firebase и push-уведомлений
    status: completed
  - id: update-pubspec-icons
    content: Включить генерацию iOS иконок в pubspec.yaml
    status: completed
  - id: create-deployment-guide
    content: Создать подробную инструкцию IOS_DEPLOYMENT_GUIDE.md
    status: completed
---

# План настройки iOS для приложения Депеша

## Обзор

Проект уже имеет базовую структуру iOS, но требуется доработка для полноценной работы. Необходимо создать `Podfile`, обновить `Info.plist` с недостающими разрешениями, добавить entitlements для Push Notifications и Keychain, настроить Firebase для iOS.

## 1. Создание Podfile

Создать [`_may_messenger_mobile_app/ios/Podfile`](_may_messenger_mobile_app/ios/Podfile) с настройками для всех зависимостей:

```ruby
platform :ios, '13.0'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

## 2. Обновление Info.plist с разрешениями

Добавить в [`_may_messenger_mobile_app/ios/Runner/Info.plist`](_may_messenger_mobile_app/ios/Runner/Info.plist):

| Ключ | Описание |

|------|----------|

| `NSContactsUsageDescription` | Для доступа к контактам |

| `NSPhotoLibraryUsageDescription` | Для выбора изображений |

| `NSPhotoLibraryAddUsageDescription` | Для сохранения изображений |

| `NSSpeechRecognitionUsageDescription` | Для голосовых сообщений |

| `UIFileSharingEnabled` | Для обмена файлами |

| `LSSupportsOpeningDocumentsInPlace` | Для открытия документов |

Также обновить `CFBundleDisplayName` на "Депеша".

## 3. Создание Runner.entitlements

Создать файлы entitlements для Debug и Release конфигураций:

**Debug.entitlements:**

- `aps-environment` = development
- `keychain-access-groups` = $(AppIdentifierPrefix)com.maymessenger.mobileApp

**Release.entitlements:**

- `aps-environment` = production
- `keychain-access-groups` = $(AppIdentifierPrefix)com.maymessenger.mobileApp

Обновить `project.pbxproj` для подключения entitlements.

## 4. Обновление AppDelegate.swift

Добавить инициализацию Firebase и обработку push-уведомлений в [`_may_messenger_mobile_app/ios/Runner/AppDelegate.swift`](_may_messenger_mobile_app/ios/Runner/AppDelegate.swift):

```swift
import Firebase
import FirebaseMessaging
import UserNotifications

// Добавить Firebase.initializeApp() и UNUserNotificationCenter delegate
```

## 5. Обновление pubspec.yaml для iOS иконок

В [`_may_messenger_mobile_app/pubspec.yaml`](_may_messenger_mobile_app/pubspec.yaml) изменить:

```yaml
flutter_launcher_icons:
  android: true
  ios: true  # Было false
  image_path: "_icon_big.png"
```

## 6. Создание iOS-инструкции

Создать документ `IOS_DEPLOYMENT_GUIDE.md` с инструкциями:

- Настройка Apple Developer Account
- Создание App ID и Provisioning Profiles
- Настройка Firebase для iOS
- Сборка и публикация в TestFlight
- Публикация в App Store

---

## Необходимые файлы для создания/изменения

| Файл | Действие |

|------|----------|

| `ios/Podfile` | Создать |

| `ios/Runner/Info.plist` | Обновить |

| `ios/Runner/Runner.entitlements` | Создать |

| `ios/Runner/RunnerDebug.entitlements` | Создать |

| `ios/Runner/AppDelegate.swift` | Обновить |

| `ios/Runner.xcodeproj/project.pbxproj` | Обновить (entitlements) |

| `pubspec.yaml` | Обновить (ios icons) |

| `IOS_DEPLOYMENT_GUIDE.md` | Создать |