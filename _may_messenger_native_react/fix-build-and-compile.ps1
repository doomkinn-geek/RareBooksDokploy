# ========================================
# Депеша - Исправление ошибок сборки APK
# ========================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Очистка кешей и пересборка APK" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

$projectPath = "D:\_SOURCES\source\RareBooksServicePublic\_may_messenger_native_react"
Set-Location $projectPath

# STEP 1: Удаление кеша .gradle
Write-Host "[STEP 1/6] Удаление кеша .gradle..." -ForegroundColor Yellow
$gradleCachePath = Join-Path $projectPath "android\.gradle"
if (Test-Path $gradleCachePath) {
    Remove-Item -Path $gradleCachePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  OK Кеш .gradle удален" -ForegroundColor Green
} else {
    Write-Host "  SKIP Кеш .gradle не найден" -ForegroundColor Gray
}

# STEP 2: Удаление build директорий
Write-Host "`n[STEP 2/6] Удаление build директорий..." -ForegroundColor Yellow
$appBuildPath = Join-Path $projectPath "android\app\build"
$buildPath = Join-Path $projectPath "android\build"

if (Test-Path $appBuildPath) {
    Remove-Item -Path $appBuildPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  OK android\app\build удален" -ForegroundColor Green
} else {
    Write-Host "  SKIP android\app\build не найден" -ForegroundColor Gray
}

if (Test-Path $buildPath) {
    Remove-Item -Path $buildPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  OK android\build удален" -ForegroundColor Green
} else {
    Write-Host "  SKIP android\build не найден" -ForegroundColor Gray
}

# STEP 3: Удаление кеша CMake из проблемного модуля
Write-Host "`n[STEP 3/6] Удаление кеша CMake из react-native-nitro-modules..." -ForegroundColor Yellow
$cmxCachePath = Join-Path $projectPath "node_modules\react-native-nitro-modules\android\.cxx"
if (Test-Path $cmxCachePath) {
    Remove-Item -Path $cmxCachePath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  OK Кеш CMake удален" -ForegroundColor Green
} else {
    Write-Host "  SKIP Кеш CMake не найден" -ForegroundColor Gray
}

# STEP 4: Переход в папку android
Write-Host "`n[STEP 4/6] Переход в папку android..." -ForegroundColor Yellow
$androidPath = Join-Path $projectPath "android"
Set-Location $androidPath
Write-Host "  OK Перешли в: $(Get-Location)" -ForegroundColor Green

# STEP 5: Выполнение gradlew clean
Write-Host "`n[STEP 5/6] Выполнение gradlew clean..." -ForegroundColor Yellow
.\gradlew clean

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Gradle clean выполнен успешно" -ForegroundColor Green
} else {
    Write-Host "  WARNING Gradle clean завершился с предупреждениями" -ForegroundColor Yellow
}

# STEP 6: Сборка Debug APK
Write-Host "`n[STEP 6/6] Сборка Debug APK..." -ForegroundColor Yellow
Write-Host "  Это может занять 5-10 минут. Пожалуйста, подождите..." -ForegroundColor Gray
Write-Host "  Используем флаг --no-daemon для стабильности сборки" -ForegroundColor Gray
Write-Host ""

.\gradlew assembleDebug --no-daemon

# Проверка результата
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "         СБОРКА ЗАВЕРШЕНА!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $apkPath = Join-Path $androidPath "app\build\outputs\apk\debug\app-debug.apk"
    
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
    } else {
        Write-Host "ВНИМАНИЕ: APK файл не найден по пути $apkPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "       СБОРКА ЗАВЕРШИЛАСЬ С ОШИБКОЙ" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    Write-Host "Проверьте вывод выше для деталей ошибки." -ForegroundColor Yellow
    Write-Host "`nЕсли ошибка повторяется, попробуйте:" -ForegroundColor Yellow
    Write-Host "  1. Переустановить node_modules: npm install" -ForegroundColor White
    Write-Host "  2. Добавить папку проекта в исключения антивируса" -ForegroundColor White
    Write-Host "  3. Проверить наличие google-services.json в android\app\" -ForegroundColor White
    exit 1
}

Set-Location $projectPath

