# Скрипт для развертывания исправления нормализации номеров телефонов

Write-Host "=== Развертывание обновления нормализации номеров ===" -ForegroundColor Green
Write-Host ""

# Проверка Docker
Write-Host "1. Проверка Docker..." -ForegroundColor Yellow
$dockerRunning = docker ps 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ОШИБКА: Docker Desktop не запущен!" -ForegroundColor Red
    Write-Host "   Запустите Docker Desktop и повторите попытку." -ForegroundColor Red
    exit 1
}
Write-Host "   ✓ Docker работает" -ForegroundColor Green
Write-Host ""

# Сборка backend
Write-Host "2. Сборка backend..." -ForegroundColor Yellow
docker compose build maymessenger_backend
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ОШИБКА: Не удалось собрать backend!" -ForegroundColor Red
    exit 1
}
Write-Host "   ✓ Backend собран" -ForegroundColor Green
Write-Host ""

# Остановка backend для миграции
Write-Host "3. Остановка backend для миграции..." -ForegroundColor Yellow
docker compose stop maymessenger_backend
Write-Host "   ✓ Backend остановлен" -ForegroundColor Green
Write-Host ""

# Применение SQL миграции
Write-Host "4. Применение SQL миграции..." -ForegroundColor Yellow
Write-Host "   Копирование SQL скрипта в контейнер..." -ForegroundColor Gray
docker cp _may_messenger_backend\migrations\update_phone_hashes.sql rarebooks-postgres-1:/tmp/update_phone_hashes.sql

Write-Host "   Выполнение миграции..." -ForegroundColor Gray
docker compose exec -T postgres psql -U postgres -d maymessenger -f /tmp/update_phone_hashes.sql
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ПРЕДУПРЕЖДЕНИЕ: Возможная ошибка при выполнении миграции" -ForegroundColor Yellow
    Write-Host "   Проверьте вывод выше" -ForegroundColor Yellow
} else {
    Write-Host "   ✓ Миграция применена" -ForegroundColor Green
}
Write-Host ""

# Запуск обновленного backend
Write-Host "5. Запуск обновленного backend..." -ForegroundColor Yellow
docker compose up -d maymessenger_backend
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ОШИБКА: Не удалось запустить backend!" -ForegroundColor Red
    exit 1
}
Write-Host "   ✓ Backend запущен" -ForegroundColor Green
Write-Host ""

# Проверка здоровья backend
Write-Host "6. Ожидание готовности backend..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
$healthCheck = curl -k https://messenger.rare-books.ru/health 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Backend работает" -ForegroundColor Green
} else {
    Write-Host "   ПРЕДУПРЕЖДЕНИЕ: Backend не отвечает на health check" -ForegroundColor Yellow
}
Write-Host ""

# Установка мобильного приложения
Write-Host "7. Установка мобильного приложения..." -ForegroundColor Yellow
$apkPath = "_may_messenger_mobile_app\build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    Write-Host "   Найден APK: $apkPath" -ForegroundColor Gray
    $devices = adb devices 2>&1 | Select-String -Pattern "device$"
    if ($devices) {
        Write-Host "   Установка APK на устройство..." -ForegroundColor Gray
        adb install -r $apkPath
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✓ APK установлен" -ForegroundColor Green
        } else {
            Write-Host "   ОШИБКА: Не удалось установить APK" -ForegroundColor Red
        }
    } else {
        Write-Host "   ПРЕДУПРЕЖДЕНИЕ: Устройства не обнаружены" -ForegroundColor Yellow
        Write-Host "   Установите APK вручную: $apkPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ОШИБКА: APK не найден по пути $apkPath" -ForegroundColor Red
}
Write-Host ""

Write-Host "=== Развертывание завершено ===" -ForegroundColor Green
Write-Host ""
Write-Host "Следующие шаги:" -ForegroundColor Cyan
Write-Host "1. Если APK не установлен автоматически, установите его вручную" -ForegroundColor White
Write-Host "2. Полностью закройте и перезапустите May Messenger на всех устройствах" -ForegroundColor White
Write-Host "3. Проверьте, что контакты теперь находятся корректно" -ForegroundColor White
Write-Host ""
Write-Host "Для тестирования:" -ForegroundColor Cyan
Write-Host "- Зарегистрируйте пользователя с номером +79094924190" -ForegroundColor White
Write-Host "- Добавьте этот номер в телефонную книгу в любом формате:" -ForegroundColor White
Write-Host "  '8 (909) 492-41-90' или '+7-909-492-41-90' и т.д." -ForegroundColor White
Write-Host "- Перейдите в 'Новый чат' - контакт должен появиться" -ForegroundColor White
