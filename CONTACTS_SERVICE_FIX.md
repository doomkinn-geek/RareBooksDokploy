# Исправление ошибки компиляции contacts_service

## Проблема
При компиляции мобильного приложения возникала ошибка:
```
A problem occurred configuring project ':contacts_service'.
> Namespace not specified. Specify a namespace in the module's build file
```

Пакет `contacts_service` (версия 0.6.3) устарел и не поддерживается с 2021 года. Он не совместим с современными версиями Android Gradle Plugin.

## Решение
Заменили `contacts_service` на современный пакет `flutter_contacts`.

### Изменения

#### 1. pubspec.yaml
```yaml
# Было:
contacts_service: ^0.6.3

# Стало:
flutter_contacts: ^1.1.9
```

#### 2. contacts_service.dart
- Заменили импорт с `contacts_service` на `flutter_contacts`
- Обновили API вызовы:
  - `Permission.contacts` → `FlutterContacts.requestPermission()`
  - `ContactsService.getContacts()` → `FlutterContacts.getContacts(withProperties: true)`
- Изменили структуру данных:
  - `contact.phones?.first.value` → `contact.phones.first.number`
  - `contact.displayName ?? ''` → `contact.displayName`

#### 3. new_chat_screen.dart
- Заменили импорт `permission_handler` на `flutter_contacts`
- Обновили логику запроса разрешений:
  - `Permission.contacts.isGranted` → `FlutterContacts.requestPermission()`
  - `openAppSettings()` → `FlutterContacts.openExternalPick()`

#### 4. signalr_service.dart
Файл был поврежден во время редактирования - полностью переписан с правильной структурой.

## Результат
✅ Приложение успешно компилируется
✅ APK файл создан: `build\app\outputs\flutter-apk\app-release.apk` (65.9MB)
✅ Все функции работы с контактами обновлены

## Преимущества flutter_contacts
- Активно поддерживается (последнее обновление: 2024)
- Совместим с Android Gradle Plugin 8+
- Поддерживает null-safety
- Более простой и современный API
- Лучшая производительность

## Команда для сборки
```bash
cd _may_messenger_mobile_app
flutter pub get
flutter build apk --release
```

## Тестирование
После установки APK необходимо проверить:
1. Запрос разрешений на доступ к контактам
2. Синхронизацию контактов с backend
3. Создание чатов через список контактов
4. Отображение имен из телефонной книги
