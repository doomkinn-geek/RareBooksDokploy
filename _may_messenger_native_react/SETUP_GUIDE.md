# Депеша - Руководство по настройке и запуску

## ✅ Что уже готово

- ✅ Приложение переименовано в "Депеша"
- ✅ Фон чата настроен (assets/chat_background.png)
- ✅ Полнофункциональные аудио сообщения
- ✅ Полнофункциональные изображения
- ✅ Error Boundaries для обработки ошибок
- ✅ SQLite для offline кэширования
- ✅ Redux Toolkit + TypeScript
- ✅ Material Design 3 UI

## 🚀 Быстрый старт (после настройки Android)

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\MayMessengerRN

# Terminal 1 - Metro
npm start

# Terminal 2 - Android app
npm run android
```

## 📋 Требуется настроить

### 1. ⚠️ Android окружение (ОБЯЗАТЕЛЬНО)

#### Установить JDK 17-20

1. Скачать: https://adoptium.net/temurin/releases/?version=17
2. Установить в `C:\Program Files\Eclipse Adoptium\jdk-17...`
3. Добавить переменные окружения:

```powershell
# PowerShell с правами администратора
[System.Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Eclipse Adoptium\jdk-17.0.x', 'Machine')

# Добавить в Path
$path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$path += ';C:\Program Files\Eclipse Adoptium\jdk-17.0.x\bin'
[System.Environment]::SetEnvironmentVariable('Path', $path, 'Machine')
```

4. Перезапустить терминалы и проверить:
```powershell
java -version
# Должно показать: openjdk version "17.x.x"
```

#### Настроить Android SDK

1. Открыть Android Studio
2. SDK Manager (Tools → SDK Manager)
3. Установить:
   - ✅ Android SDK Platform 33 (API Level 33)
   - ✅ Android SDK Build-Tools 33.0.0
   - ✅ Android Emulator
   - ✅ Android SDK Platform-Tools

4. Настроить ANDROID_HOME:

```powershell
# PowerShell с правами администратора
$androidHome = "$env:LOCALAPPDATA\Android\Sdk"
[System.Environment]::SetEnvironmentVariable('ANDROID_HOME', $androidHome, 'Machine')

# Добавить в Path
$path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$path += ";$androidHome\platform-tools;$androidHome\tools;$androidHome\tools\bin"
[System.Environment]::SetEnvironmentVariable('Path', $path, 'Machine')
```

5. Перезапустить терминалы и проверить:
```powershell
$env:ANDROID_HOME
adb version
```

#### Создать Android эмулятор

1. Android Studio → Device Manager (справа)
2. Create Device → Pixel 6 или Pixel 7
3. System Image → Release Name: Tiramisu (API Level 33) → Download
4. Finish

5. Запустить эмулятор:
   - Через Android Studio: нажать ▶️ на эмуляторе
   - Через командную строку:
   ```powershell
   emulator -list-avds
   emulator -avd Pixel_6_API_33
   ```

### 2. 🔔 Firebase Cloud Messaging (Опционально)

#### Создать Firebase проект

1. https://console.firebase.google.com/
2. Add project → "Depesha"
3. Add Android app → Package: `com.depesha`
4. Download `google-services.json`
5. Разместить: `MayMessengerRN/android/app/google-services.json`

#### Обновить android/app/build.gradle

Добавить в конец файла:
```gradle
apply plugin: 'com.google.gms.google-services'
```

#### Обновить android/build.gradle

В `buildscript { dependencies {` добавить:
```gradle
classpath 'com.google.gms:google-services:4.4.0'
```

### 3. 🎨 Настроить иконку приложения

Иконка находится в `assets/_icon_big.png`. Для автоматической генерации:

```powershell
# Установить генератор иконок
npm install -g @bam.tech/react-native-make

# Генерировать иконки из assets/_icon_big.png
npx react-native set-icon --path ./assets/_icon_big.png --platform android
```

Или вручную:
1. Создать иконки разных размеров: 48x48, 72x72, 96x96, 144x144, 192x192
2. Разместить в:
   - `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (48x48)
   - `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (72x72)
   - `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (96x96)
   - `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (144x144)
   - `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (192x192)

## 🔧 Настройка API

### Изменить URL бэкенда (если нужно)

Файл: `src/utils/constants.ts`

```typescript
export const API_CONFIG = {
  BASE_URL: 'https://messenger.rare-books.ru',
  API_URL: 'https://messenger.rare-books.ru/api',
  HUB_URL: 'https://messenger.rare-books.ru/hubs/chat',
};

// Для локальной разработки на Android эмуляторе:
// export const API_CONFIG = {
//   BASE_URL: 'http://10.0.2.2:5279',
//   API_URL: 'http://10.0.2.2:5279/api',
//   HUB_URL: 'http://10.0.2.2:5279/hubs/chat',
// };
```

**Важно:** Android эмулятор использует `10.0.2.2` вместо `localhost`

## 🧪 Проверка перед запуском

```powershell
# 1. Проверить TypeScript
npx tsc --noEmit
# Должно быть: Exit code 0, no errors

# 2. Проверить окружение
npx react-native doctor
# Должно показать ✓ для:
# - Node.js
# - npm
# - JDK
# - Android Studio
# - ANDROID_HOME
# - Android SDK

# 3. Проверить эмулятор
adb devices
# Должен показать подключенное устройство
```

## 🎮 Запуск приложения

### Вариант 1: Через npm scripts

```powershell
# Terminal 1: Запустить Metro bundler
npm start

# Terminal 2: Запустить на Android
npm run android
```

### Вариант 2: Через React Native CLI

```powershell
# Запустить эмулятор
emulator -avd Pixel_6_API_33

# Подождать пока загрузится (30-60 сек)

# Запустить приложение
npx react-native run-android
```

### Первый запуск может занять 5-10 минут!

- Gradle скачивает зависимости
- Компилируется нативный код
- Устанавливается APK на эмулятор

## 🐛 Troubleshooting

### Ошибка: "SDK location not found"

```powershell
# Создать android/local.properties
echo "sdk.dir=$env:LOCALAPPDATA\Android\Sdk" | Out-File -Encoding utf8 android/local.properties
```

### Ошибка: "Unable to load script"

```powershell
# Очистить кэш Metro
npm start -- --reset-cache
```

### Ошибка: "Execution failed for task ':app:mergeDebugResources'"

```powershell
# Очистить build
cd android
./gradlew clean
cd ..
```

### Ошибка: "INSTALL_FAILED_UPDATE_INCOMPATIBLE"

```powershell
# Удалить старую версию с эмулятора
adb uninstall com.depesha
```

### Горячая перезагрузка не работает

В эмуляторе: `Ctrl+M` → Enable Hot Reloading

## 📦 Структура компонентов

### Новые компоненты

- `AudioPlayer.tsx` - Проигрывание аудио
- `AudioRecorderFull.tsx` - Запись аудио
- `ImagePickerButton.tsx` - Выбор изображений  
- `ErrorBoundary.tsx` - Обработка ошибок

### Обновленные экраны

- `ChatScreen.tsx` - Добавлен фон чата
- `App.tsx` - Обернут в ErrorBoundary

### Новые сервисы

- `sqliteService.ts` - SQLite кэширование

## 🎯 Что можно тестировать

### ✅ Готово к тестированию:

1. **Аутентификация**
   - Регистрация нового пользователя
   - Вход существующего пользователя

2. **Чаты**
   - Просмотр списка чатов
   - Создание нового чата (по User ID)
   - Preview последнего сообщения
   - Счетчик непрочитанных

3. **Сообщения**
   - Отправка текстовых сообщений
   - Оптимистичные обновления UI
   - Real-time получение через SignalR
   - Форматирование времени

4. **UI/UX**
   - Красивый фон чата
   - Material Design 3
   - Плавные анимации
   - Error handling

### 🚧 Требует дальнейшей работы:

- Аудио сообщения (компонент готов, нужна интеграция в ChatScreen)
- Изображения (компонент готов, нужна интеграция в ChatScreen)
- Push-уведомления (нужен google-services.json)
- Offline sync (SQLite готов, нужна интеграция)

## 📝 Следующие шаги

1. **Настроить Android окружение** - JDK + SDK + Эмулятор
2. **Запустить приложение** - проверить базовую функциональность
3. **Интегрировать аудио/изображения** в ChatScreen
4. **Настроить Firebase** для push-уведомлений
5. **Активировать SQLite** кэширование в providers

## 📚 Полезные команды

```powershell
# Список устройств
adb devices

# Логи приложения
adb logcat | Select-String "ReactNative"

# Перезапустить приложение
adb shell am force-stop com.depesha
npx react-native run-android

# Открыть Dev Menu в эмуляторе
# Ctrl+M (Windows) или Cmd+M (Mac)

# Reload приложения
# R R (дважды R в терминале Metro)
```

## 🆘 Помощь

- React Native Docs: https://reactnative.dev/
- Troubleshooting: https://reactnative.dev/docs/troubleshooting
- React Native Issues: https://github.com/facebook/react-native/issues

---

**Версия:** 1.0.0  
**Дата:** 19 декабря 2025  
**Название:** Депеша (Depesha)

