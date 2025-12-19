# ========================================
# Депеша - Автоматическая сборка APK
# ========================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Депеша - Сборка APK для установки" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Проверка google-services.json
Write-Host "[CHECK] Проверка google-services.json..." -ForegroundColor Yellow

$googleServicesPath = "android\app\google-services.json"
$secretsPath = "secrets\google-services.json"

if (-not (Test-Path $googleServicesPath)) {
    Write-Host "[WARNING] google-services.json не найден в android\app\" -ForegroundColor Red
    
    if (Test-Path $secretsPath) {
        Write-Host "[INFO] Копирование из secrets\..." -ForegroundColor Yellow
        Copy-Item $secretsPath $googleServicesPath
        Write-Host "[SUCCESS] Файл скопирован!" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] google-services.json не найден!" -ForegroundColor Red
        Write-Host "Поместите файл в:" -ForegroundColor White
        Write-Host "  - android\app\google-services.json" -ForegroundColor Cyan
        Write-Host "  или" -ForegroundColor White
        Write-Host "  - secrets\google-services.json" -ForegroundColor Cyan
        exit 1
    }
} else {
    Write-Host "[OK] google-services.json найден" -ForegroundColor Green
}

# Выбор типа сборки
Write-Host "`nВыберите тип сборки:" -ForegroundColor Yellow
Write-Host "  1 - Debug APK (для тестирования, быстрая сборка ~3-5 мин)" -ForegroundColor White
Write-Host "  2 - Release APK (для production, минификация ~5-10 мин)" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Введите номер (1 или 2)"

if ($choice -eq "2") {
    $buildType = "Release"
    $gradleTask = "assembleRelease"
    $outputFolder = "release"
    $apkName = "app-release.apk"
    
    # Проверка keystore для Release
    if (-not (Test-Path "android\app\depesha-release-key.keystore")) {
        Write-Host "`n[WARNING] Release keystore не найден!" -ForegroundColor Red
        Write-Host "Для Release сборки нужен keystore. Создать его? (y/n)" -ForegroundColor Yellow
        $createKey = Read-Host
        
        if ($createKey -eq "y") {
            Write-Host "`n[INFO] Создание keystore..." -ForegroundColor Yellow
            Write-Host "Введите пароль для keystore (запомните его!):" -ForegroundColor Yellow
            $password = Read-Host -AsSecureString
            $passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
            
            Set-Location android\app
            keytool -genkeypair -v -storetype PKCS12 `
              -keystore depesha-release-key.keystore `
              -alias depesha-key-alias `
              -keyalg RSA -keysize 2048 -validity 10000 `
              -storepass $passwordPlain `
              -keypass $passwordPlain `
              -dname "CN=Depesha, OU=Mobile, O=Depesha, L=Moscow, ST=Moscow, C=RU"
            
            # Создать gradle.properties
            $propsContent = @"

# Depesha Release Signing (НЕ КОММИТИТЬ В GIT!)
DEPESHA_RELEASE_STORE_FILE=depesha-release-key.keystore
DEPESHA_RELEASE_KEY_ALIAS=depesha-key-alias
DEPESHA_RELEASE_STORE_PASSWORD=$passwordPlain
DEPESHA_RELEASE_KEY_PASSWORD=$passwordPlain
"@
            Add-Content "../gradle.properties" $propsContent
            
            Set-Location ..\..
            Write-Host "[SUCCESS] Keystore создан!" -ForegroundColor Green
        } else {
            Write-Host "[INFO] Переключаюсь на Debug сборку..." -ForegroundColor Yellow
            $buildType = "Debug"
            $gradleTask = "assembleDebug"
            $outputFolder = "debug"
            $apkName = "app-debug.apk"
        }
    }
} else {
    $buildType = "Debug"
    $gradleTask = "assembleDebug"
    $outputFolder = "debug"
    $apkName = "app-debug.apk"
}

Write-Host "`n[STEP] Сборка $buildType APK..." -ForegroundColor Green

# Перейти в android директорию
Set-Location android

# Очистка
Write-Host "[INFO] Очистка предыдущей сборки..." -ForegroundColor Yellow
.\gradlew clean | Out-Null

# Сборка
Write-Host "[INFO] Сборка APK (это может занять несколько минут)...`n" -ForegroundColor Yellow
$buildStart = Get-Date
.\gradlew $gradleTask
$buildEnd = Get-Date
$buildTime = ($buildEnd - $buildStart).TotalSeconds

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "         СБОРКА ЗАВЕРШЕНА!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $apkPath = "app\build\outputs\apk\$outputFolder\$apkName"
    
    if (Test-Path $apkPath) {
        $fullPath = Resolve-Path $apkPath
        $size = (Get-Item $apkPath).Length / 1MB
        
        Write-Host "✅ APK создан успешно!" -ForegroundColor Green
        Write-Host "📂 Путь: $fullPath" -ForegroundColor Cyan
        Write-Host "📦 Размер: $([Math]::Round($size, 2)) MB" -ForegroundColor Cyan
        Write-Host "⏱️  Время сборки: $([Math]::Round($buildTime, 1)) секунд`n" -ForegroundColor Cyan
        
        Write-Host "📱 Установка на телефон:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Вариант 1 - Копирование файла:" -ForegroundColor White
        Write-Host "  1. Скопируйте APK на телефон (USB / облако / мессенджер)" -ForegroundColor Gray
        Write-Host "  2. Откройте файл на телефоне" -ForegroundColor Gray
        Write-Host "  3. Разрешите установку из неизвестных источников" -ForegroundColor Gray
        Write-Host "  4. Нажмите 'Установить'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Вариант 2 - Через USB (adb):" -ForegroundColor White
        Write-Host "  adb install `"$fullPath`"`n" -ForegroundColor Cyan
        
        # Проверить подключенные устройства
        $devices = adb devices | Select-String "device$"
        if ($devices) {
            Write-Host "📱 Найдено устройств: $($devices.Count)" -ForegroundColor Green
            Write-Host ""
            Write-Host "Установить сейчас? (y/n)" -ForegroundColor Yellow
            $install = Read-Host
            
            if ($install -eq "y") {
                Write-Host "[INFO] Удаление старой версии..." -ForegroundColor Yellow
                adb uninstall com.depesha 2>$null
                
                Write-Host "[INFO] Установка APK..." -ForegroundColor Yellow
                adb install "$fullPath"
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "`n✅ Приложение установлено на устройство!" -ForegroundColor Green
                } else {
                    Write-Host "`n❌ Ошибка установки" -ForegroundColor Red
                }
            }
        }
        
        # Открыть папку с APK
        Write-Host "`n[INFO] Открываю папку с APK..." -ForegroundColor Yellow
        $folder = Split-Path $fullPath
        Start-Process explorer $folder
    } else {
        Write-Host "❌ APK файл не найден по пути: $apkPath" -ForegroundColor Red
    }
} else {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "         ОШИБКА СБОРКИ!" -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    Write-Host "Проверьте ошибки выше и попробуйте:" -ForegroundColor Yellow
    Write-Host "  cd android" -ForegroundColor Cyan
    Write-Host "  .\gradlew $gradleTask --stacktrace" -ForegroundColor Cyan
    exit 1
}

Set-Location ..
Write-Host "`n✅ Готово!" -ForegroundColor Green

