# ========================================
# Депеша - Исправление ошибок сборки
# ========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "   Депеша - Исправление ошибок сборки" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

# 1. Очистка Gradle кэша
Write-Host "[1/6] Очистка Gradle кэша..." -ForegroundColor Cyan
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\app\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force android\build -ErrorAction SilentlyContinue
Write-Host "      ✓ Gradle кэш очищен" -ForegroundColor Green

# 2. Удаление node_modules
Write-Host "[2/6] Удаление node_modules..." -ForegroundColor Cyan
Remove-Item -Recurse -Force node_modules -ErrorAction SilentlyContinue
Write-Host "      ✓ node_modules удален" -ForegroundColor Green

# 3. Установка зависимостей
Write-Host "[3/6] Установка зависимостей..." -ForegroundColor Cyan
npm install --legacy-peer-deps
if ($LASTEXITCODE -ne 0) {
    Write-Host "      ✗ Ошибка установки зависимостей" -ForegroundColor Red
    exit 1
}
Write-Host "      ✓ Зависимости установлены" -ForegroundColor Green

# 4. Создание local.properties
Write-Host "[4/6] Создание local.properties..." -ForegroundColor Cyan
$sdkPath = "$env:LOCALAPPDATA\Android\Sdk" -replace '\\', '/'
if (-not (Test-Path "$env:LOCALAPPDATA\Android\Sdk")) {
    Write-Host "      ✗ Android SDK не найден по пути: $env:LOCALAPPDATA\Android\Sdk" -ForegroundColor Red
    Write-Host "      Установите Android Studio и SDK" -ForegroundColor Yellow
    exit 1
}
"sdk.dir=$sdkPath" | Out-File -Encoding ASCII -NoNewline android\local.properties
Write-Host "      ✓ local.properties создан" -ForegroundColor Green

# 5. Проверка google-services.json
Write-Host "[5/6] Проверка google-services.json..." -ForegroundColor Cyan
if (-not (Test-Path "android\app\google-services.json")) {
    if (Test-Path "secrets\google-services.json") {
        Write-Host "      Копирование из secrets..." -ForegroundColor Yellow
        Copy-Item "secrets\google-services.json" "android\app\google-services.json" -Force
        Write-Host "      ✓ google-services.json скопирован" -ForegroundColor Green
    } else {
        Write-Host "      ⚠ google-services.json не найден!" -ForegroundColor Red
        Write-Host "      Поместите файл в папку secrets/" -ForegroundColor Yellow
        Write-Host "      Или используйте: .\copy-google-services.ps1" -ForegroundColor Yellow
    }
} else {
    Write-Host "      ✓ google-services.json уже существует" -ForegroundColor Green
}

# 6. Финальная проверка
Write-Host "[6/6] Финальная проверка..." -ForegroundColor Cyan

$allOk = $true

if (Test-Path "android\local.properties") {
    Write-Host "      ✓ local.properties создан" -ForegroundColor Green
} else {
    Write-Host "      ✗ local.properties отсутствует" -ForegroundColor Red
    $allOk = $false
}

if (Test-Path "node_modules") {
    Write-Host "      ✓ node_modules установлен" -ForegroundColor Green
} else {
    Write-Host "      ✗ node_modules отсутствует" -ForegroundColor Red
    $allOk = $false
}

if (Test-Path "node_modules\react-native-nitro-modules") {
    Write-Host "      ✓ react-native-nitro-modules установлен" -ForegroundColor Green
} else {
    Write-Host "      ✗ react-native-nitro-modules отсутствует" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

if ($allOk) {
    Write-Host "✅ Все исправления применены успешно!" -ForegroundColor Green
    Write-Host "Теперь можно собирать APK:" -ForegroundColor Cyan
    Write-Host "  .\build-apk.ps1" -ForegroundColor Yellow
} else {
    Write-Host "⚠ Некоторые проверки не прошли!" -ForegroundColor Red
    Write-Host "Проверьте ошибки выше и попробуйте снова" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

