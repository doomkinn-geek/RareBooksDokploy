# Скрипт оптимизированной сборки Docker Compose для Windows
# Запуск: .\build-optimized.ps1

$ErrorActionPreference = "Stop"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🚀 Оптимизированная сборка Docker Compose" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Включаем BuildKit
$env:DOCKER_BUILDKIT = "1"
$env:COMPOSE_DOCKER_CLI_BUILD = "1"
$env:BUILDKIT_PROGRESS = "plain"

Write-Host "✓ BuildKit включен" -ForegroundColor Green

# Проверяем BuildKit
try {
    $buildxVersion = docker buildx version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ BuildKit: $($buildxVersion.Split("`n")[0])" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  BuildKit не найден. Производительность может быть ниже." -ForegroundColor Yellow
}

Write-Host "✓ Параллельная сборка: включена" -ForegroundColor Green
Write-Host "✓ Кеширование слоев: включено" -ForegroundColor Green
Write-Host ""

# Показываем текущие образы (если есть)
try {
    $images = docker images | Select-String "rarebooks"
    if ($images) {
        Write-Host "📊 Текущие образы:" -ForegroundColor Yellow
        docker images | Select-Object -First 1
        $images | Select-Object -First 5
        Write-Host ""
    }
} catch {
    # Игнорируем, если нет образов
}

# Засекаем время
$startTime = Get-Date

# Сборка
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📦 Начинаем сборку образов..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

docker compose build --parallel

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Ошибка при сборке!" -ForegroundColor Red
    exit 1
}

# Вычисляем время
$endTime = Get-Date
$duration = $endTime - $startTime
$minutes = [math]::Floor($duration.TotalMinutes)
$seconds = $duration.Seconds

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ Сборка завершена успешно!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "⏱️  Время сборки: ${minutes}м ${seconds}с" -ForegroundColor Yellow
Write-Host ""

# Показываем размеры образов
Write-Host "📊 Размеры образов:" -ForegroundColor Yellow
docker images | Select-Object -First 1
docker images | Select-String "rarebooks" | Select-Object -First 5
Write-Host ""

Write-Host "🚀 Следующие шаги:" -ForegroundColor Cyan
Write-Host "   1. Запустить контейнеры:" -ForegroundColor White
Write-Host "      docker compose up -d" -ForegroundColor Gray
Write-Host ""
Write-Host "   2. Проверить статус:" -ForegroundColor White
Write-Host "      docker compose ps" -ForegroundColor Gray
Write-Host ""
Write-Host "   3. Посмотреть логи:" -ForegroundColor White
Write-Host "      docker compose logs -f" -ForegroundColor Gray
Write-Host ""

