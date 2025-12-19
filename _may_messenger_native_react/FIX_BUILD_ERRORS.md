# 🔧 Исправление ошибок сборки APK

## Проблемы после переименования проекта

После переименования `MayMessengerRN` → `_may_messenger_native_react` возникли ошибки при сборке.

---

## ❌ Ошибка 1: Gradle ссылается на старый путь

```
Configuring project ':react-native-fast-image' without an existing directory is not allowed. 
The configured projectDirectory 'D:\_SOURCES\source\RareBooksServicePublic\MayMessengerRN\...' does not exist
```

### ✅ Решение

**Причина:** Gradle кэш хранит старые пути

**Исправление:**
```powershell
# 1. Удалить Gradle кэш
Remove-Item -Recurse -Force android\.gradle
Remove-Item -Recurse -Force android\app\.gradle
Remove-Item -Recurse -Force android\build

# 2. Удалить node_modules
Remove-Item -Recurse -Force node_modules

# 3. Переустановить зависимости
npm install --legacy-peer-deps
```

---

## ❌ Ошибка 2: SDK location not found

```
SDK location not found. Define a valid SDK location with an ANDROID_HOME 
environment variable or by setting the sdk.dir path in your project's 
local properties file at 'android\local.properties'.
```

### ✅ Решение

**Причина:** Отсутствует файл `android/local.properties`

**Исправление:**
```powershell
# Создать файл local.properties
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk" -replace '\\', '/'
"sdk.dir=$sdkPath" | Out-File -Encoding ASCII -NoNewline android\local.properties
```

**Результат:** Файл `android/local.properties`:
```
sdk.dir=C:/Users/USERNAME/AppData/Local/Android/Sdk
```

---

## ❌ Ошибка 3: react-native-nitro-modules not found

```
Project with path ':react-native-nitro-modules' could not be found in project 
':react-native-audio-recorder-player'.
```

### ✅ Решение

**Причина:** `react-native-audio-recorder-player@4.5.0` требует `nitro-modules`

**Исправление:**
```powershell
npm install react-native-nitro-modules --legacy-peer-deps
```

---

## ⚠️ Предупреждения (можно игнорировать)

### react-native-audio-recorder-player deprecated

```
npm warn deprecated react-native-audio-recorder-player@4.5.0: 
This package has been deprecated. Please use react-native-nitro-sound instead.
```

**Пояснение:** Пакет устарел, но продолжает работать. В будущем можно мигрировать на `react-native-nitro-sound`.

### Конфликт версий React

```
Could not resolve dependency:
peer react@"^17 || ^18" from react-native-fast-image@8.6.3
Conflicting peer dependency: react@18.3.1 vs react@19.2.0
```

**Решение:** Используем флаг `--legacy-peer-deps` при установке.

---

## 🚀 Полный скрипт исправления

Создайте файл `fix-build.ps1`:

```powershell
# ========================================
# Депеша - Исправление ошибок сборки
# ========================================

Write-Host "`nИсправление ошибок сборки..." -ForegroundColor Yellow

# 1. Очистка Gradle кэша
Write-Host "[1/6] Очистка Gradle кэша..." -ForegroundColor Cyan
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\app\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\build -ErrorAction SilentlyContinue

# 2. Удаление node_modules
Write-Host "[2/6] Удаление node_modules..." -ForegroundColor Cyan
Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue

# 3. Установка зависимостей
Write-Host "[3/6] Установка зависимостей..." -ForegroundColor Cyan
npm install --legacy-peer-deps

# 4. Создание local.properties
Write-Host "[4/6] Создание local.properties..." -ForegroundColor Cyan
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk" -replace '\\', '/'
"sdk.dir=$sdkPath" | Out-File -Encoding ASCII -NoNewline android\local.properties

# 5. Проверка google-services.json
Write-Host "[5/6] Проверка google-services.json..." -ForegroundColor Cyan
if (-not (Test-Path "android\app\google-services.json")) {
    if (Test-Path "secrets\google-services.json") {
        Write-Host "  Копирование из secrets..." -ForegroundColor Yellow
        Copy-Item "secrets\google-services.json" "android\app\google-services.json"
    } else {
        Write-Host "  [WARNING] google-services.json не найден!" -ForegroundColor Red
    }
} else {
    Write-Host "  OK" -ForegroundColor Green
}

# 6. Финальная проверка
Write-Host "[6/6] Проверка..." -ForegroundColor Cyan
if (Test-Path "android\local.properties") {
    Write-Host "  ✓ local.properties создан" -ForegroundColor Green
}
if (Test-Path "node_modules") {
    Write-Host "  ✓ node_modules установлен" -ForegroundColor Green
}

Write-Host "`n✅ Исправления применены! Теперь можно собирать APK." -ForegroundColor Green
Write-Host "Запустите: .\build-apk.ps1`n" -ForegroundColor Cyan
```

**Использование:**
```powershell
.\fix-build.ps1
```

---

## 📋 Чеклист после исправлений

Перед сборкой убедитесь:

- [ ] `android/local.properties` существует
- [ ] `node_modules/` установлены
- [ ] `node_modules/react-native-nitro-modules/` присутствует
- [ ] `android/app/google-services.json` скопирован
- [ ] Gradle кэш очищен

---

## 🎯 Быстрое решение (все в одном)

```powershell
# Перейти в папку проекта
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react

# Очистка
Remove-Item -Recurse -Force android\.gradle, android\build, node_modules -ErrorAction SilentlyContinue

# Установка
npm install --legacy-peer-deps

# Создание local.properties
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk" -replace '\\', '/'
"sdk.dir=$sdkPath" | Out-File -Encoding ASCII -NoNewline android\local.properties

# Копирование google-services.json
if (Test-Path "secrets\google-services.json") {
    Copy-Item "secrets\google-services.json" "android\app\google-services.json" -Force
}

# Сборка APK
.\build-apk.ps1
```

---

## 🐛 Другие возможные ошибки

### "Execution failed for task ':app:processDebugResources'"

**Причина:** Отсутствует или поврежден `google-services.json`

**Решение:**
```powershell
Copy-Item "secrets\google-services.json" "android\app\google-services.json" -Force
cd android
.\gradlew clean
.\gradlew assembleDebug
```

### "Unsupported class file major version 65"

**Причина:** Неправильная версия Java (нужна JDK 17-20)

**Решение:** Установите JDK 17 с https://adoptium.net/

### "Could not determine the dependencies of task ':app:compileDebugJavaWithJavac'"

**Причина:** Gradle кэш поврежден

**Решение:**
```powershell
cd android
Remove-Item -Recurse -Force .gradle, build
.\gradlew clean --refresh-dependencies
.\gradlew assembleDebug
```

---

## ✅ Проверка готовности

```powershell
# 1. Проверка Java
java -version
# Должно быть: openjdk version "17.x.x" или "20.x.x"

# 2. Проверка Android SDK
$env:ANDROID_HOME
# Должно быть: C:\Users\...\AppData\Local\Android\Sdk

# 3. Проверка local.properties
Get-Content android\local.properties
# Должно быть: sdk.dir=C:/Users/.../Android/Sdk

# 4. Проверка google-services.json
Test-Path android\app\google-services.json
# Должно быть: True

# 5. Проверка nitro-modules
Test-Path node_modules\react-native-nitro-modules
# Должно быть: True
```

---

## 📞 Если ничего не помогло

### Полная переустановка

```powershell
# 1. Сохранить google-services.json
Copy-Item android\app\google-services.json secrets\ -Force

# 2. Удалить всё
Remove-Item -Recurse -Force node_modules, android\.gradle, android\build, android\app\build

# 3. Очистить npm кэш
npm cache clean --force

# 4. Переустановить всё
npm install --legacy-peer-deps

# 5. Восстановить конфигурацию
Copy-Item secrets\google-services.json android\app\
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk" -replace '\\', '/'
"sdk.dir=$sdkPath" | Out-File -Encoding ASCII -NoNewline android\local.properties

# 6. Собрать
cd android
.\gradlew clean
.\gradlew assembleDebug
```

---

**Дата:** 19 декабря 2025  
**Проект:** Депеша  
**Версия:** 1.0

**Ошибки исправлены! 🔧✅**

