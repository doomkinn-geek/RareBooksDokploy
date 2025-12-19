# ========================================
# Депеша - Скрипт автоматической сборки Android
# ========================================
# Версия: 1.0
# Дата: 19 декабря 2025
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Депеша - Автоматическая сборка Android" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Цвета для вывода
function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

# Проверка местоположения
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Step "1. Проверка окружения..."

# Проверка Node.js
try {
    $nodeVersion = node --version
    Write-Info "Node.js версия: $nodeVersion"
} catch {
    Write-Error-Custom "Node.js не найден! Установите Node.js 20+ с https://nodejs.org/"
    exit 1
}

# Проверка npm
try {
    $npmVersion = npm --version
    Write-Info "npm версия: $npmVersion"
} catch {
    Write-Error-Custom "npm не найден!"
    exit 1
}

# Проверка Java
try {
    $javaVersion = java -version 2>&1 | Select-String "version"
    Write-Info "Java: $javaVersion"
} catch {
    Write-Error-Custom "Java не найден! Установите JDK 17-20."
    Write-Info "Скачать: https://adoptium.net/temurin/releases/?version=17"
    exit 1
}

# Проверка ANDROID_HOME
if (-not $env:ANDROID_HOME) {
    Write-Error-Custom "ANDROID_HOME не установлен!"
    Write-Info "Установите Android SDK и настройте переменную окружения."
    exit 1
} else {
    Write-Info "ANDROID_HOME: $env:ANDROID_HOME"
}

# Проверка adb
try {
    adb version | Out-Null
    Write-Info "ADB найден"
} catch {
    Write-Error-Custom "ADB не найден в PATH!"
    exit 1
}

Write-Step "2. Проверка package.json..."
if (-not (Test-Path "package.json")) {
    Write-Error-Custom "package.json не найден! Запустите скрипт из корня проекта."
    exit 1
}

Write-Step "3. Установка/проверка зависимостей..."
Write-Info "Выполнение npm install..."
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "npm install завершился с ошибкой!"
    exit 1
}

Write-Step "4. Проверка TypeScript..."
Write-Info "Компиляция TypeScript..."
npx tsc --noEmit
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "TypeScript компиляция завершилась с ошибками!"
    Write-Info "Проверьте ошибки выше и исправьте их перед сборкой."
    exit 1
}
Write-Success "TypeScript: OK"

Write-Step "5. Проверка устройств Android..."
$devices = adb devices | Select-String "device$"
if ($devices.Count -eq 0) {
    Write-Error-Custom "Нет подключенных Android устройств или эмуляторов!"
    Write-Info "Запустите эмулятор или подключите устройство через USB."
    Write-Info ""
    Write-Info "Запуск эмулятора:"
    Write-Info "  emulator -list-avds"
    Write-Info "  emulator -avd <AVD_NAME>"
    exit 1
} else {
    Write-Success "Найдено устройств: $($devices.Count)"
    $devices | ForEach-Object { Write-Info "  - $_" }
}

Write-Step "6. Очистка предыдущей сборки..."
Write-Info "Очистка Gradle cache..."
Push-Location android
.\gradlew clean
Pop-Location

Write-Step "7. Создание папки для изображений (если нужно)..."
$imagesPath = ".\assets\images"
if (-not (Test-Path $imagesPath)) {
    New-Item -ItemType Directory -Path $imagesPath -Force | Out-Null
    Write-Info "Создана папка: $imagesPath"
}

Write-Step "8. Сборка Android приложения..."
Write-Info "Это может занять 5-10 минут при первой сборке..."
Write-Info ""

# Запуск Metro в фоне (если не запущен)
$metroRunning = Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*metro*" }
if (-not $metroRunning) {
    Write-Info "Запуск Metro Bundler в фоне..."
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "npm start" -WindowStyle Minimized
    Start-Sleep -Seconds 5
} else {
    Write-Info "Metro Bundler уже запущен"
}

# Сборка и установка на устройство
Write-Info "Сборка Debug APK и установка на устройство..."
npx react-native run-android

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Сборка завершилась с ошибкой!"
    Write-Info ""
    Write-Info "Возможные причины:"
    Write-Info "  1. Проблемы с Gradle - попробуйте: cd android && .\gradlew clean"
    Write-Info "  2. Устройство отключилось - проверьте: adb devices"
    Write-Info "  3. Недостаточно места на диске"
    Write-Info "  4. Конфликт версий - удалите node_modules и переустановите"
    exit 1
}

Write-Step "9. Проверка установки..."
$packageName = "com.depesha"
$installed = adb shell pm list packages | Select-String $packageName
if ($installed) {
    Write-Success "Приложение успешно установлено: $packageName"
} else {
    Write-Error-Custom "Приложение не найдено на устройстве!"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "          СБОРКА ЗАВЕРШЕНА!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Success "Приложение 'Депеша' успешно собрано и установлено!"
Write-Info "Приложение должно автоматически запуститься на устройстве."
Write-Host ""
Write-Info "Полезные команды:"
Write-Info "  npm start          - Запустить Metro Bundler"
Write-Info "  npm run android    - Пересобрать и установить"
Write-Info "  adb logcat         - Просмотр логов"
Write-Info "  Ctrl+M (эмулятор)  - Открыть Dev Menu"
Write-Host ""
Write-Info "Для просмотра логов выполните:"
Write-Info "  adb logcat | Select-String 'ReactNative'"
Write-Host ""
Write-Success "Готово! 🚀"

