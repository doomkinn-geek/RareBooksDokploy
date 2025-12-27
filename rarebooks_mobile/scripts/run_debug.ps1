# Скрипт для быстрого запуска отладки на подключенном Android устройстве
# Использование: .\scripts\run_debug.ps1

Write-Host "=== Запуск отладки RareBooks Mobile ===" -ForegroundColor Cyan
Write-Host ""

# Проверка Flutter
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "ОШИБКА: flutter не найден в PATH!" -ForegroundColor Red
    exit 1
}

# Проверка устройств
Write-Host "Проверка подключенных устройств..." -ForegroundColor Cyan
$devices = flutter devices --machine | ConvertFrom-Json

$androidDevices = $devices | Where-Object { $_.category -eq "mobile" -and $_.platformType -eq "android" }

if ($androidDevices.Count -eq 0) {
    Write-Host "ОШИБКА: Android устройства не найдены!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Убедитесь что:" -ForegroundColor Yellow
    Write-Host "  1. Устройство подключено через USB" -ForegroundColor Yellow
    Write-Host "  2. Включена отладка по USB" -ForegroundColor Yellow
    Write-Host "  3. Разрешена отладка на компьютере" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Выполните: flutter devices" -ForegroundColor Yellow
    exit 1
}

if ($androidDevices.Count -eq 1) {
    $device = $androidDevices[0]
    Write-Host "✓ Найдено устройство: $($device.name) ($($device.id))" -ForegroundColor Green
    Write-Host ""
    Write-Host "Запуск отладки..." -ForegroundColor Cyan
    flutter run -d $device.id --debug --verbose
} else {
    Write-Host "Найдено несколько устройств:" -ForegroundColor Yellow
    $index = 1
    foreach ($device in $androidDevices) {
        Write-Host "  $index. $($device.name) ($($device.id))" -ForegroundColor Cyan
        $index++
    }
    Write-Host ""
    $choice = Read-Host "Выберите устройство (1-$($androidDevices.Count))"
    
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $androidDevices.Count) {
        $selectedDevice = $androidDevices[[int]$choice - 1]
        Write-Host ""
        Write-Host "Запуск отладки на $($selectedDevice.name)..." -ForegroundColor Cyan
        flutter run -d $selectedDevice.id --debug --verbose
    } else {
        Write-Host "Неверный выбор!" -ForegroundColor Red
        exit 1
    }
}

