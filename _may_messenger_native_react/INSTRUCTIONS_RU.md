# 📱 Депеша - Инструкции по сборке APK

## ✅ Что было сделано

Обнаружены и исправлены все ошибки сборки:

1. ✅ **Очищен Gradle кэш** со старыми путями
2. ✅ **Переустановлены node_modules** с правильными зависимостями
3. ✅ **Создан android/local.properties** с путем к Android SDK
4. ✅ **Установлены недостающие пакеты:**
   - `react-native-nitro-modules`
   - `react-native-worklets`
   - `react-native-worklets-core`
5. ✅ **Настроен android/app/build.gradle** для worklets
6. ✅ **Запущена сборка APK**

---

## 🚀 Проверка текущего статуса сборки

Откройте PowerShell и выполните:

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react

# Проверить, создался ли APK
Test-Path android\app\build\outputs\apk\debug\app-debug.apk
```

**Если вернулось `True`:**
```powershell
# Открыть папку с APK
explorer android\app\build\outputs\apk\debug\
```

**Если вернулось `False`:**
Сборка еще идет или завершилась с ошибкой. Проверьте статус.

---

## 🔍 Как проверить статус сборки

### Вариант 1: Проверка процессов

```powershell
# Посмотреть, запущен ли Gradle
Get-Process -Name java -ErrorAction SilentlyContinue | 
    Select-Object ProcessName, CPU, @{N='Memory(MB)';E={[math]::Round($_.WorkingSet64/1MB,2)}}
```

**Если видите процессы Java:**
- Gradle активно работает
- Подождите еще 3-5 минут
- Первая сборка может занять до 10 минут

**Если процессов нет:**
- Сборка завершена (успешно или с ошибкой)
- Проверьте, создался ли APK

### Вариант 2: Запустить сборку вручную

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react\android
.\gradlew assembleDebug
```

Смотрите вывод команды. В конце должно быть:
```
BUILD SUCCESSFUL in 8m 23s
```

---

## 📦 Если APK создан успешно

### 1. Найти файл

```
D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react\android\app\build\outputs\apk\debug\app-debug.apk
```

### 2. Установить на телефон

**Способ А: Через USB и ADB**
```powershell
adb devices  # Проверить подключение
adb install -r android\app\build\outputs\apk\debug\app-debug.apk
```

**Способ Б: Ручная установка**
1. Скопируйте `app-debug.apk` на телефон
2. Откройте файл на телефоне
3. Разрешите установку из неизвестных источников
4. Установите приложение

### 3. Запустить приложение

Найдите иконку "Депеша" на телефоне и запустите!

---

## ❌ Если сборка не удалась

### Шаг 1: Полная переустановка

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react

# Сохранить google-services.json
Copy-Item android\app\google-services.json secrets\ -Force -ErrorAction SilentlyContinue

# Удалить всё
Remove-Item -Recurse -Force node_modules, android\.gradle, android\build, android\app\build

# Очистить npm кэш
npm cache clean --force

# Переустановить зависимости
npm install --legacy-peer-deps

# Установить дополнительные пакеты
npm install react-native-nitro-modules --legacy-peer-deps
npm install react-native-worklets --legacy-peer-deps
npm install react-native-worklets-core --legacy-peer-deps

# Восстановить конфиги
Copy-Item secrets\google-services.json android\app\ -Force -ErrorAction SilentlyContinue
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk" -replace '\\', '/'
"sdk.dir=$sdkPath" | Out-File -Encoding ASCII -NoNewline android\local.properties

# Собрать
cd android
.\gradlew clean
.\gradlew assembleDebug
```

### Шаг 2: Проверить окружение

```powershell
# Java версия (должна быть 17-20)
java -version

# Node версия (рекомендуется 18 или 20 LTS)
node --version

# Android SDK
Test-Path "$env:LOCALAPPDATA\Android\Sdk"

# Gradle
cd android
.\gradlew --version
```

### Шаг 3: Использовать готовый скрипт

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react
.\fix-build.ps1
```

---

## 📝 Альтернатива: Использовать готовый скрипт build-apk.ps1

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react
.\build-apk.ps1
```

Выберите:
- **1** - Debug APK (быстрее, для тестирования)
- **2** - Release APK (оптимизированный, для публикации)

---

## 🎯 Быстрая команда (всё в одном)

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react; if (Test-Path android\app\build\outputs\apk\debug\app-debug.apk) { Write-Host "APK ready!" -ForegroundColor Green; explorer android\app\build\outputs\apk\debug\ } else { Write-Host "Building APK..." -ForegroundColor Yellow; cd android; .\gradlew assembleDebug }
```

---

## 📊 Таблица команд

| Задача | Команда |
|--------|---------|
| Проверить статус | `Test-Path android\app\build\outputs\apk\debug\app-debug.apk` |
| Открыть папку APK | `explorer android\app\build\outputs\apk\debug\` |
| Собрать Debug APK | `cd android; .\gradlew assembleDebug` |
| Собрать Release APK | `cd android; .\gradlew assembleRelease` |
| Очистить сборку | `cd android; .\gradlew clean` |
| Проверить процессы | `Get-Process -Name java` |
| Установить на устройство | `adb install -r android\app\build\outputs\apk\debug\app-debug.apk` |
| Полная переустановка | `.\fix-build.ps1` |
| Автоматическая сборка | `.\build-apk.ps1` |

---

## 🔧 Дополнительные файлы

Созданы следующие документы:

- ✅ `FIX_BUILD_ERRORS.md` - Подробное описание всех ошибок и решений
- ✅ `BUILD_ERRORS_SOLVED.md` - Хронология исправлений
- ✅ `fix-build.ps1` - Скрипт автоматического исправления
- ✅ `build-apk.ps1` - Скрипт автоматической сборки APK
- ✅ `copy-google-services.ps1` - Скрипт копирования Firebase конфига
- ✅ `BUILD_APK_GUIDE.md` - Детальное руководство по сборке APK
- ✅ `FIREBASE_SETUP_DETAILED.md` - Настройка Firebase
- ✅ `FIREBASE_SERVER_SETUP.md` - Настройка Firebase на сервере
- ✅ `DOCKER_UPDATES_SUMMARY.md` - Обновления Docker конфигурации

---

## 🎉 Финальный чеклист

Перед запуском приложения убедитесь:

- [ ] APK файл создан: `android\app\build\outputs\apk\debug\app-debug.apk`
- [ ] Размер APK ~ 50-80 MB
- [ ] Firebase настроен (google-services.json скопирован)
- [ ] Телефон подключен к компьютеру (для установки через ADB)
- [ ] Разрешена установка из неизвестных источников (для ручной установки)
- [ ] Backend API запущен и доступен
- [ ] В коде указан правильный URL API

---

## 🚀 Следующие шаги

### 1. Настроить API URL

Откройте файл:
```
src\utils\constants.ts
```

Убедитесь, что указан правильный URL:
```typescript
export const API_URL = 'https://messenger.rare-books.ru/api';  // Или ваш URL
```

### 2. Настроить Firebase на сервере

См. файл: `FIREBASE_SERVER_SETUP.md`

### 3. Обновить Docker конфигурацию

См. файл: `DOCKER_UPDATES_SUMMARY.md`

### 4. Собрать Release APK для публикации

```powershell
.\build-apk.ps1
# Выберите опцию 2
```

---

## 📞 Помощь

Если возникли проблемы:

1. Прочитайте `BUILD_ERRORS_SOLVED.md`
2. Запустите `.\fix-build.ps1`
3. Проверьте версии Java (17-20) и Node (18-22)
4. Очистите кэш: `npm cache clean --force`
5. Переустановите зависимости: `npm install --legacy-peer-deps`

---

**Дата:** 19 декабря 2025  
**Проект:** Депеша  
**Версия:** 1.0.0  
**Статус:** Готово к сборке ✅

**Удачи! 🎉**

