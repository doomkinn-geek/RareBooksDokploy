# 📦 Депеша - Руководство по созданию APK

## ❓ Что делает npm start?

**npm start** запускает **Metro Bundler** - это **НЕ сборка APK!**

Metro Bundler:
- ✅ Запускает dev-сервер на http://localhost:8081
- ✅ Компилирует JavaScript код в реальном времени
- ✅ Включает hot reload для разработки
- ❌ **НЕ создает APK файл**

---

## 🎯 Как создать APK для установки на телефон

### Вариант 1: Debug APK (для тестирования)

#### PowerShell команды:

```powershell
# 1. Перейти в папку проекта
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react

# 2. Перейти в папку android
cd android

# 3. Собрать Debug APK
.\gradlew assembleDebug

# APK будет создан в:
# android\app\build\outputs\apk\debug\app-debug.apk
```

**Время сборки:** 3-5 минут

#### Местоположение APK:
```
_may_messenger_native_react\
└── android\
    └── app\
        └── build\
            └── outputs\
                └── apk\
                    └── debug\
                        └── app-debug.apk  ← ВОТ ОН!
```

#### Установка на телефон:

**Способ 1: Через USB**
```powershell
adb install android\app\build\outputs\apk\debug\app-debug.apk
```

**Способ 2: Копирование файла**
1. Скопируйте `app-debug.apk` на телефон (USB / облако / мессенджер)
2. Откройте файл на телефоне
3. Разрешите установку из неизвестных источников
4. Нажмите "Установить"

---

### Вариант 2: Release APK (для production)

#### ⚠️ Требуется подпись (keystore)

**Шаг 1: Создать keystore (один раз)**

```powershell
cd android\app

keytool -genkeypair -v -storetype PKCS12 `
  -keystore depesha-release-key.keystore `
  -alias depesha-key-alias `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -dname "CN=Depesha, OU=Mobile, O=YourCompany, L=City, ST=State, C=RU"
```

**Введите пароль и запомните его!**

Файл будет создан: `android\app\depesha-release-key.keystore`

**Шаг 2: Настроить gradle**

Создайте файл `android\gradle.properties` (если нет):

```properties
# Добавить в конец файла:
DEPESHA_RELEASE_STORE_FILE=depesha-release-key.keystore
DEPESHA_RELEASE_KEY_ALIAS=depesha-key-alias
DEPESHA_RELEASE_STORE_PASSWORD=ВАШ_ПАРОЛЬ
DEPESHA_RELEASE_KEY_PASSWORD=ВАШ_ПАРОЛЬ
```

**⚠️ НЕ КОММИТИТЬ В GIT!** Добавьте в `.gitignore`:
```gitignore
# Keystore files
*.keystore
gradle.properties
```

**Шаг 3: Обновить build.gradle**

Файл: `android\app\build.gradle`

Добавьте после блока `android {`:

```gradle
android {
    // ... существующие настройки ...
    
    signingConfigs {
        debug {
            storeFile file('debug.keystore')
            storePassword 'android'
            keyAlias 'androiddebugkey'
            keyPassword 'android'
        }
        release {
            if (project.hasProperty('DEPESHA_RELEASE_STORE_FILE')) {
                storeFile file(DEPESHA_RELEASE_STORE_FILE)
                storePassword DEPESHA_RELEASE_STORE_PASSWORD
                keyAlias DEPESHA_RELEASE_KEY_ALIAS
                keyPassword DEPESHA_RELEASE_KEY_PASSWORD
            }
        }
    }
    
    buildTypes {
        debug {
            signingConfig signingConfigs.debug
        }
        release {
            // Включаем минификацию для production
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            signingConfig signingConfigs.release
        }
    }
}
```

**Шаг 4: Собрать Release APK**

```powershell
cd D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react\android

# Очистка предыдущей сборки
.\gradlew clean

# Сборка Release APK
.\gradlew assembleRelease

# APK будет в:
# android\app\build\outputs\apk\release\app-release.apk
```

**Время сборки:** 5-10 минут (первая сборка)

---

### Вариант 3: Bundle для Google Play

Для публикации в Google Play Store нужен **AAB** (Android App Bundle):

```powershell
cd android

# Собрать Bundle
.\gradlew bundleRelease

# Bundle будет в:
# android\app\build\outputs\bundle\release\app-release.aab
```

---

## 🚀 Автоматизированный скрипт сборки APK

Создайте файл `build-apk.ps1`:

```powershell
# ========================================
# Депеша - Автоматическая сборка APK
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Депеша - Сборка APK для установки" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Выбор типа сборки
Write-Host "Выберите тип сборки:" -ForegroundColor Yellow
Write-Host "  1 - Debug APK (для тестирования, быстрая сборка)"
Write-Host "  2 - Release APK (для production, минификация)"
Write-Host ""
$choice = Read-Host "Введите номер (1 или 2)"

if ($choice -eq "2") {
    $buildType = "Release"
    $gradleTask = "assembleRelease"
} else {
    $buildType = "Debug"
    $gradleTask = "assembleDebug"
}

Write-Host "`n[STEP] Сборка $buildType APK..." -ForegroundColor Green

# Перейти в android директорию
Set-Location android

# Очистка
Write-Host "[INFO] Очистка предыдущей сборки..." -ForegroundColor Yellow
.\gradlew clean

# Сборка
Write-Host "[INFO] Сборка APK (это может занять 3-5 минут)..." -ForegroundColor Yellow
.\gradlew $gradleTask

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "         СБОРКА ЗАВЕРШЕНА!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    if ($buildType -eq "Debug") {
        $apkPath = "app\build\outputs\apk\debug\app-debug.apk"
    } else {
        $apkPath = "app\build\outputs\apk\release\app-release.apk"
    }
    
    if (Test-Path $apkPath) {
        $fullPath = Resolve-Path $apkPath
        $size = (Get-Item $apkPath).Length / 1MB
        
        Write-Host "APK создан успешно!" -ForegroundColor Green
        Write-Host "Путь: $fullPath" -ForegroundColor Cyan
        Write-Host "Размер: $([Math]::Round($size, 2)) MB`n" -ForegroundColor Cyan
        
        Write-Host "Для установки на телефон:" -ForegroundColor Yellow
        Write-Host "  1. Скопируйте APK на телефон" -ForegroundColor White
        Write-Host "  2. Откройте файл на телефоне" -ForegroundColor White
        Write-Host "  3. Разрешите установку из неизвестных источников" -ForegroundColor White
        Write-Host "  4. Нажмите 'Установить'" -ForegroundColor White
        Write-Host "`nИли через USB:" -ForegroundColor Yellow
        Write-Host "  adb install `"$fullPath`"`n" -ForegroundColor White
        
        # Открыть папку с APK
        $folder = Split-Path $fullPath
        explorer $folder
    }
} else {
    Write-Host "`n[ERROR] Сборка завершилась с ошибкой!" -ForegroundColor Red
    exit 1
}

Set-Location ..
```

**Использование:**
```powershell
.\build-apk.ps1
```

---

## 📝 Сравнение типов сборки

| Параметр | Debug APK | Release APK |
|----------|-----------|-------------|
| **Скорость сборки** | 3-5 мин | 5-10 мин |
| **Размер файла** | ~50-80 MB | ~25-40 MB |
| **Минификация** | ❌ Нет | ✅ Да |
| **Подпись** | Debug key | Release key |
| **Для чего** | Тестирование | Production |
| **Play Store** | ❌ Нельзя | ✅ Можно |

---

## 🔧 Настройка google-services.json

Вы разместили файл в `secrets\`, но нужно скопировать в `android\app\`:

```powershell
# Скопировать из secrets
Copy-Item "_may_messenger_native_react\secrets\google-services.json" `
          "_may_messenger_native_react\android\app\google-services.json"

# Проверить
ls _may_messenger_native_react\android\app\google-services.json
```

**Структура должна быть:**
```
_may_messenger_native_react\
├── secrets\
│   └── google-services.json  ← Ваш файл (backup)
└── android\
    └── app\
        ├── build.gradle
        └── google-services.json  ← НУЖНО СКОПИРОВАТЬ СЮДА!
```

---

## ❓ Troubleshooting

### "Task :app:assembleDebug FAILED"

**Проблема:** Gradle ошибка сборки

**Решение:**
```powershell
cd android
.\gradlew clean
.\gradlew assembleDebug --stacktrace
```

### "Execution failed for task ':app:processDebugResources'"

**Проблема:** Проблема с ресурсами или google-services.json

**Решение:**
1. Проверьте наличие `android\app\google-services.json`
2. Проверьте валидность JSON
3. Пересоберите: `.\gradlew clean assembleDebug`

### APK не устанавливается на телефон

**Проблема:** "App not installed" или "Package conflicts"

**Решение:**
```powershell
# Удалить старую версию
adb uninstall com.depesha

# Установить новую
adb install android\app\build\outputs\apk\debug\app-debug.apk
```

### "INSTALL_PARSE_FAILED_NO_CERTIFICATES"

**Проблема:** APK не подписан

**Решение:** Используйте `assembleDebug` (автоматически подписывается) или настройте Release подпись

---

## 📦 Распространение APK

### Для тестировщиков

1. Соберите Debug APK
2. Загрузите на облако (Google Drive, Dropbox)
3. Отправьте ссылку тестировщикам
4. Инструкция: "Скачать → Открыть → Разрешить установку → Установить"

### Для пользователей (Beta)

1. Соберите Release APK с подписью
2. Опционально: загрузите в Google Play (Internal Testing)
3. Или распространяйте через свой сайт

### Google Play Store (Production)

1. Создайте Release Bundle: `.\gradlew bundleRelease`
2. Зарегистрируйтесь в Google Play Console
3. Создайте приложение
4. Загрузите AAB файл
5. Заполните метаданные (описание, скриншоты)
6. Отправьте на ревью

---

## 🎯 Быстрые команды

```powershell
# Debug APK (быстро)
cd android && .\gradlew assembleDebug

# Release APK (production)
cd android && .\gradlew assembleRelease

# Bundle для Play Store
cd android && .\gradlew bundleRelease

# Очистка
cd android && .\gradlew clean

# Установка на телефон через USB
adb install android\app\build\outputs\apk\debug\app-debug.apk

# Удаление с телефона
adb uninstall com.depesha
```

---

## ✅ Чеклист перед сборкой

- [ ] `google-services.json` в `android/app/`
- [ ] `package.json` содержит правильное название
- [ ] `app.json` обновлен
- [ ] Android SDK установлен
- [ ] Для Release: keystore создан и настроен
- [ ] Интернет доступен (для загрузки зависимостей)

---

**Дата:** 19 декабря 2025  
**Проект:** Депеша  
**Версия:** 1.0

**Удачной сборки APK! 📦🚀**

