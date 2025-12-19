# ========================================
# Копирование google-services.json
# ========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Копирование google-services.json" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$secretsPath = "secrets\google-services.json"
$targetPath = "android\app\google-services.json"

# Проверка существования исходного файла
if (-not (Test-Path $secretsPath)) {
    Write-Host "[ERROR] Файл не найден: $secretsPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Поместите google-services.json в папку secrets\" -ForegroundColor Yellow
    Write-Host "Скачать можно с Firebase Console:" -ForegroundColor Yellow
    Write-Host "  https://console.firebase.google.com/" -ForegroundColor Cyan
    Write-Host "  → Выбрать проект → Project settings → Your apps → Download" -ForegroundColor Gray
    exit 1
}

# Создать директорию если нужно
$targetDir = Split-Path $targetPath
if (-not (Test-Path $targetDir)) {
    Write-Host "[INFO] Создание директории $targetDir..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

# Копирование
Write-Host "[INFO] Копирование файла..." -ForegroundColor Yellow
Copy-Item $secretsPath $targetPath -Force

# Проверка
if (Test-Path $targetPath) {
    $fileSize = (Get-Item $targetPath).Length / 1KB
    Write-Host "`n[SUCCESS] Файл скопирован!" -ForegroundColor Green
    Write-Host "Из: $secretsPath" -ForegroundColor Cyan
    Write-Host "В:  $targetPath" -ForegroundColor Cyan
    Write-Host "Размер: $([Math]::Round($fileSize, 2)) KB`n" -ForegroundColor Cyan
    
    # Проверка валидности JSON
    try {
        $json = Get-Content $targetPath -Raw | ConvertFrom-Json
        if ($json.project_info.project_id) {
            Write-Host "[OK] JSON валиден" -ForegroundColor Green
            Write-Host "Project ID: $($json.project_info.project_id)" -ForegroundColor Cyan
            
            # Проверка package name
            if ($json.client[0].client_info.android_client_info.package_name -ne "com.depesha") {
                Write-Host "`n[WARNING] Package name не совпадает!" -ForegroundColor Yellow
                Write-Host "Ожидается: com.depesha" -ForegroundColor White
                Write-Host "В файле:   $($json.client[0].client_info.android_client_info.package_name)" -ForegroundColor White
                Write-Host ""
                Write-Host "Убедитесь что в Firebase Console добавлен Android app с package name: com.depesha" -ForegroundColor Yellow
            } else {
                Write-Host "[OK] Package name корректен: com.depesha" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "`n[WARNING] Не удалось проверить JSON" -ForegroundColor Yellow
        Write-Host "Ошибка: $_" -ForegroundColor Gray
    }
    
    Write-Host "`n✅ Готово! Теперь можно собирать APK." -ForegroundColor Green
} else {
    Write-Host "`n[ERROR] Не удалось скопировать файл!" -ForegroundColor Red
    exit 1
}

