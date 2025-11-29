# Скрипт миграции изображений коллекций в Docker volume (Windows PowerShell)
# Использование: .\migrate_collection_images.ps1

param(
    [switch]$SkipBackup = $false
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Начало миграции изображений коллекций в Docker volume" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# Имена контейнеров и путей
$BackendContainer = "rarebooks_backend"
$SourcePath = "/app/wwwroot/collection_images"
$TempDir = Join-Path $env:USERPROFILE "temp_collection_images_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Проверка, что контейнер существует
$containerExists = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $BackendContainer }
if (-not $containerExists) {
    Write-Host "❌ Контейнер $BackendContainer не найден!" -ForegroundColor Red
    Write-Host "Убедитесь, что Docker контейнеры запущены." -ForegroundColor Yellow
    exit 1
}

Write-Host "Шаг 1: Проверка наличия изображений в старом контейнере..." -ForegroundColor Yellow

# Проверка существования директории
$dirExists = docker exec $BackendContainer test -d $SourcePath 2>$null
if ($LASTEXITCODE -eq 0) {
    $imageCount = (docker exec $BackendContainer find $SourcePath -type f 2>$null | Measure-Object -Line).Lines
    
    if ($imageCount -eq 0) {
        Write-Host "⚠️  В контейнере нет изображений для миграции." -ForegroundColor Yellow
        $continue = Read-Host "Продолжить с обновлением конфигурации? (y/n)"
        if ($continue -ne "y") {
            Write-Host "Миграция отменена." -ForegroundColor Yellow
            exit 0
        }
    } else {
        Write-Host "✅ Найдено изображений: $imageCount" -ForegroundColor Green
        
        if (-not $SkipBackup) {
            # Создаем временную директорию
            Write-Host "`nШаг 2: Создание временной директории для backup..." -ForegroundColor Yellow
            New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
            Write-Host "✅ Создана: $TempDir" -ForegroundColor Green
            
            # Копируем изображения из контейнера
            Write-Host "`nШаг 3: Копирование изображений из контейнера..." -ForegroundColor Yellow
            docker cp "${BackendContainer}:${SourcePath}/." "$TempDir/"
            Write-Host "✅ Изображения скопированы" -ForegroundColor Green
            
            # Показываем размер
            $backupSize = (Get-ChildItem -Path $TempDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Host "   Размер backup: $([math]::Round($backupSize, 2)) MB" -ForegroundColor Green
        }
    }
} else {
    Write-Host "⚠️  Директория с изображениями не найдена в контейнере." -ForegroundColor Yellow
    $imageCount = 0
}

Write-Host "`nШаг 4: Остановка контейнеров..." -ForegroundColor Yellow
docker-compose down
Write-Host "✅ Контейнеры остановлены" -ForegroundColor Green

Write-Host "`nШаг 5: Пересоздание контейнеров с новой конфигурацией..." -ForegroundColor Yellow
docker-compose up -d --build
Write-Host "✅ Контейнеры пересозданы" -ForegroundColor Green

# Ждем, пока контейнер backend станет здоровым
Write-Host "`nШаг 6: Ожидание готовности backend (может занять до 2 минут)..." -ForegroundColor Yellow
$counter = 0
$maxWait = 120

while ($counter -lt $maxWait) {
    try {
        $healthStatus = docker inspect --format='{{.State.Health.Status}}' $BackendContainer 2>$null
        if ($healthStatus -eq "healthy") {
            Write-Host "✅ Backend готов к работе" -ForegroundColor Green
            break
        }
    } catch {
        # Продолжаем ждать
    }
    
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 5
    $counter += 5
}

Write-Host ""

if ($counter -ge $maxWait) {
    Write-Host "❌ Backend не стал здоровым за отведенное время" -ForegroundColor Red
    Write-Host "Проверьте логи: docker logs $BackendContainer" -ForegroundColor Yellow
    if (Test-Path $TempDir) {
        Write-Host "Backup изображений сохранен в: $TempDir" -ForegroundColor Yellow
    }
    exit 1
}

# Если были изображения и не пропущен backup, копируем их обратно
if ($imageCount -gt 0 -and (Test-Path $TempDir)) {
    Write-Host "`nШаг 7: Копирование изображений в новый volume..." -ForegroundColor Yellow
    docker cp "$TempDir/." "${BackendContainer}:${SourcePath}/"
    Write-Host "✅ Изображения скопированы в volume" -ForegroundColor Green
    
    Write-Host "`nШаг 8: Установка правильных прав доступа..." -ForegroundColor Yellow
    try {
        docker exec $BackendContainer chown -R app:app $SourcePath 2>$null
    } catch {
        try {
            docker exec $BackendContainer chown -R www-data:www-data $SourcePath 2>$null
        } catch {
            Write-Host "⚠️  Не удалось установить владельца (возможно, не требуется)" -ForegroundColor Yellow
        }
    }
    
    docker exec $BackendContainer chmod -R 755 $SourcePath 2>$null
    Write-Host "✅ Права доступа установлены" -ForegroundColor Green
    
    Write-Host "`nШаг 9: Проверка миграции..." -ForegroundColor Yellow
    $newImageCount = (docker exec $BackendContainer find $SourcePath -type f 2>$null | Measure-Object -Line).Lines
    
    if ($newImageCount -eq $imageCount) {
        Write-Host "✅ Миграция успешна! Скопировано файлов: $newImageCount" -ForegroundColor Green
    } else {
        Write-Host "❌ Количество файлов не совпадает!" -ForegroundColor Red
        Write-Host "   Ожидалось: $imageCount" -ForegroundColor Yellow
        Write-Host "   Найдено: $newImageCount" -ForegroundColor Yellow
        Write-Host "   Backup сохранен в: $TempDir" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "`nШаг 10: Очистка временных файлов..." -ForegroundColor Yellow
    Write-Host "Удалить временный backup? (y/n)" -ForegroundColor Yellow
    Write-Host "Путь: $TempDir" -ForegroundColor Cyan
    $deleteBackup = Read-Host
    
    if ($deleteBackup -eq "y") {
        Remove-Item -Path $TempDir -Recurse -Force
        Write-Host "✅ Временные файлы удалены" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Backup сохранен в: $TempDir" -ForegroundColor Yellow
        Write-Host "   Не забудьте удалить его позже!" -ForegroundColor Yellow
    }
}

Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "🎉 Миграция завершена успешно!" -ForegroundColor Green
Write-Host ""

# Получаем информацию о volume
$volumeName = docker volume ls --format '{{.Name}}' | Where-Object { $_ -like "*collection_images*" }
$volumeImageCount = (docker exec $BackendContainer find $SourcePath -type f 2>$null | Measure-Object -Line).Lines
$volumeSize = docker exec $BackendContainer du -sh $SourcePath 2>$null

Write-Host "Проверка конфигурации:" -ForegroundColor Cyan
Write-Host "  • Docker volume создан: $volumeName" -ForegroundColor White
Write-Host "  • Изображений в volume: $volumeImageCount" -ForegroundColor White
if ($volumeSize) {
    Write-Host "  • Размер volume: $($volumeSize.Split()[0])" -ForegroundColor White
}
Write-Host ""

Write-Host "Дополнительные команды:" -ForegroundColor Cyan
Write-Host "  • Просмотр логов backend: docker logs -f $BackendContainer" -ForegroundColor White
Write-Host "  • Просмотр изображений: docker exec $BackendContainer ls -la $SourcePath" -ForegroundColor White
Write-Host "  • Создать backup: docker run --rm -v ${volumeName}:/source:ro -v `${PWD}:/backup alpine tar czf /backup/collection_backup.tar.gz -C /source ." -ForegroundColor White
Write-Host ""
Write-Host "✨ Теперь изображения сохранятся при обновлении кода!" -ForegroundColor Green

