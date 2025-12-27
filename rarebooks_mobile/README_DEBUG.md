# Отладка RareBooks Mobile на Android

## Предварительные требования

1. **Android SDK Platform Tools** - должны быть установлены и добавлены в PATH
   - Скачать: https://developer.android.com/studio/releases/platform-tools
   - Или установить через Android Studio

2. **Flutter SDK** - должен быть установлен и добавлен в PATH
   - Проверить: `flutter doctor`

3. **VS Code с расширениями:**
   - Dart
   - Flutter

4. **Android устройство:**
   - Android 5.0 (API 21) или выше
   - Включена отладка по USB

## Настройка устройства

### 1. Включение режима разработчика

1. Откройте **Настройки** на устройстве
2. Перейдите в **О телефоне**
3. Найдите **Номер сборки** (может быть в разделе "Версия MIUI" или "Версия Android")
4. Нажмите на **Номер сборки** 7 раз подряд
5. Появится сообщение "Вы стали разработчиком!"

### 2. Включение отладки по USB

1. Откройте **Настройки** > **Для разработчиков** (или **Параметры разработчика**)
2. Включите **Отладка по USB**
3. Включите **Оставаться активным** (опционально, для предотвращения блокировки экрана)

### 3. Подключение устройства

1. Подключите устройство к компьютеру через USB
2. На устройстве появится запрос "Разрешить отладку по USB?"
3. Установите галочку **Всегда разрешать с этого компьютера**
4. Нажмите **Разрешить**

## Проверка подключения

### Windows (PowerShell)

```powershell
cd c:\rarebooks\rarebooks_mobile
.\scripts\check_device.ps1
```

### Linux/Mac (Bash)

```bash
cd ~/rarebooks/rarebooks_mobile
chmod +x scripts/check_device.sh
./scripts/check_device.sh
```

### Ручная проверка

```bash
# Проверить подключенные устройства
adb devices

# Должен появиться список вида:
# List of devices attached
# ABC123XYZ    device

# Проверить устройства через Flutter
flutter devices
```

## Запуск отладки

### Способ 1: Через VS Code (рекомендуется)

1. Откройте проект в VS Code:
   ```
   code c:\rarebooks\rarebooks_mobile
   ```

2. Нажмите **F5** или выберите **Run > Start Debugging**

3. Выберите конфигурацию **"RareBooks Mobile (Debug)"**

4. Приложение установится и запустится на устройстве

5. Отладка:
   - Установите breakpoints (красные точки) в коде
   - Используйте **F10** (Step Over), **F11** (Step Into), **F5** (Continue)
   - Просматривайте переменные в панели Debug

### Способ 2: Через командную строку

#### Windows (PowerShell)

```powershell
cd c:\rarebooks\rarebooks_mobile
.\scripts\run_debug.ps1
```

#### Linux/Mac (Bash)

```bash
cd ~/rarebooks/rarebooks_mobile
flutter run --debug
```

### Способ 3: Выбор конкретного устройства

Если подключено несколько устройств:

```bash
# Список устройств
flutter devices

# Запуск на конкретном устройстве
flutter run -d <device-id> --debug
```

## Горячая перезагрузка (Hot Reload)

Во время отладки:

- **r** - Hot Reload (быстрая перезагрузка с сохранением состояния)
- **R** - Hot Restart (полная перезагрузка приложения)
- **q** - Выход из режима отладки

Или в VS Code:
- Нажмите кнопку **Hot Reload** в панели отладки
- Или используйте сочетание клавиш (обычно **Ctrl+Shift+F5**)

## Просмотр логов

### В VS Code

Логи отображаются в панели **Debug Console** во время отладки.

### В терминале

```bash
# Просмотр логов Flutter
flutter logs

# Просмотр логов Android (adb logcat)
adb logcat | grep flutter

# Просмотр всех логов
adb logcat
```

### Фильтрация логов

```bash
# Только ошибки
adb logcat *:E

# Только Flutter логи
adb logcat | grep -i flutter

# Сохранение логов в файл
adb logcat > debug.log
```

## Отладка сетевых запросов

Для отладки API запросов можно использовать:

1. **Charles Proxy** или **Fiddler** - для перехвата HTTP/HTTPS трафика
2. **Dio Interceptors** - уже настроены в `api_service.dart`
3. **Flutter DevTools** - встроенные инструменты разработчика

### Просмотр сетевых запросов через Dio

В `api_service.dart` уже настроены interceptors, которые логируют запросы. Для включения подробного логирования добавьте:

```dart
_dio.interceptors.add(LogInterceptor(
  requestBody: true,
  responseBody: true,
  logPrint: (obj) => print('[DIO] $obj'),
));
```

## Решение проблем

### Устройство не определяется

1. Проверьте USB кабель (используйте качественный кабель)
2. Попробуйте другой USB порт
3. Перезапустите adb:
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```
4. Установите драйверы устройства (для Windows)

### "Waiting for connection from debugger"

1. Перезапустите приложение на устройстве
2. Выполните Hot Restart (R)
3. Перезапустите отладку

### Ошибки компиляции

```bash
# Очистка кэша
flutter clean

# Обновление зависимостей
flutter pub get

# Пересборка
flutter build apk --debug
```

### Проблемы с сертификатами SSL

Если возникают ошибки SSL при подключении к API:

1. Проверьте что используется правильный URL в `api_config.dart`
2. Для тестирования можно временно отключить проверку SSL (НЕ для production!)

## Полезные команды

```bash
# Установка APK на устройство
flutter install

# Удаление приложения с устройства
adb uninstall ru.rarebooks.rarebooks_mobile

# Просмотр установленных приложений
adb shell pm list packages | grep rarebooks

# Очистка данных приложения
adb shell pm clear ru.rarebooks.rarebooks_mobile

# Просмотр информации о приложении
adb shell dumpsys package ru.rarebooks.rarebooks_mobile
```

## Дополнительные инструменты

### Flutter DevTools

```bash
# Запуск DevTools
flutter pub global activate devtools
flutter pub global run devtools

# Или через VS Code: View > Command Palette > Flutter: Open DevTools
```

### Android Studio

Можно также использовать Android Studio для отладки:
1. Откройте проект в Android Studio
2. Выберите устройство в верхней панели
3. Нажмите Run (зелёная кнопка)

## Конфигурация отладки

Конфигурации отладки находятся в `.vscode/launch.json`:

- **RareBooks Mobile (Debug)** - отладка с hot reload
- **RareBooks Mobile (Profile)** - профилирование производительности
- **RareBooks Mobile (Release)** - release сборка
- **RareBooks Mobile (Debug) - Specific Device** - выбор конкретного устройства

## Полезные ссылки

- [Flutter Debugging](https://docs.flutter.dev/testing/debugging)
- [VS Code Flutter Extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)
- [Android Debug Bridge](https://developer.android.com/studio/command-line/adb)

