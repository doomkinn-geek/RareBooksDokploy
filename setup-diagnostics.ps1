#!/usr/bin/env pwsh

# PowerShell скрипт для диагностики проблем с Initial Setup
# Использование: ./setup-diagnostics.ps1

param(
    [switch]$RestartServices = $false,
    [switch]$ForceSetupMode = $false,
    [string]$BaseUrl = "http://localhost"
)

Write-Host "🔧 Диагностика системы инициализации RareBooksService" -ForegroundColor Green
Write-Host "=" * 60

# Функция для проверки HTTP endpoint
function Test-Endpoint {
    param(
        [string]$Url,
        [string]$Method = "GET",
        [object]$Body = $null
    )
    
    try {
        $headers = @{ 'Content-Type' = 'application/json' }
        $params = @{
            Uri = $Url
            Method = $Method
            Headers = $headers
            UseBasicParsing = $true
            TimeoutSec = 30
        }
        
        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json)
        }
        
        $response = Invoke-WebRequest @params
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Content = $response.Content
            Error = $null
        }
    } catch {
        return @{
            Success = $false
            StatusCode = $_.Exception.Response.StatusCode.value__
            Content = $_.Exception.Message
            Error = $_.Exception
        }
    }
}

# 1. Проверка статуса Docker контейнеров
Write-Host "📦 Проверка статуса Docker контейнеров..." -ForegroundColor Yellow
try {
    $containers = docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    Write-Host $containers
} catch {
    Write-Host "❌ Ошибка при проверке Docker контейнеров: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# 2. Тест endpoint'а /api/test/setup-status
Write-Host "🔍 Тестирование Test API..." -ForegroundColor Yellow
$testResult = Test-Endpoint -Url "$BaseUrl/api/test/setup-status"

if ($testResult.Success) {
    Write-Host "✅ Test API работает" -ForegroundColor Green
    $testData = $testResult.Content | ConvertFrom-Json
    Write-Host "   Время сервера: $($testData.timestamp)"
    Write-Host "   Требуется setup: $($testData.isSetupNeeded)"
    
    if ($testData.isSetupNeeded) {
        Write-Host "⚠️  Система требует инициализации" -ForegroundColor Orange
    } else {
        Write-Host "ℹ️  Система уже настроена" -ForegroundColor Blue
    }
} else {
    Write-Host "❌ Test API недоступен" -ForegroundColor Red
    Write-Host "   Статус: $($testResult.StatusCode)"
    Write-Host "   Ошибка: $($testResult.Content)"
}

Write-Host ""

# 3. Тест endpoint'а /api/setup (GET)
Write-Host "🔍 Тестирование Setup API (GET)..." -ForegroundColor Yellow
$setupGetResult = Test-Endpoint -Url "$BaseUrl/api/setup"

if ($setupGetResult.Success) {
    Write-Host "✅ Setup API (GET) работает" -ForegroundColor Green
    if ($setupGetResult.Content -like "*<html>*") {
        Write-Host "   Возвращает HTML страницу инициализации" -ForegroundColor Green
    } else {
        Write-Host "   Возвращает JSON ответ (система уже настроена)" -ForegroundColor Blue
    }
} else {
    Write-Host "❌ Setup API (GET) недоступен" -ForegroundColor Red
    Write-Host "   Статус: $($setupGetResult.StatusCode)"
    Write-Host "   Ошибка: $($setupGetResult.Content)"
}

Write-Host ""

# 4. Тест endpoint'а /api/setup/initialize (POST)
Write-Host "🔍 Тестирование Setup API (POST)..." -ForegroundColor Yellow
$testPayload = @{
    adminEmail = "test@example.com"
    adminPassword = "testpass123"
    booksConnectionString = "test"
    usersConnectionString = "test"
    jwtKey = "test"
    jwtIssuer = "test"
    jwtAudience = "test"
}

$setupPostResult = Test-Endpoint -Url "$BaseUrl/api/setup/initialize" -Method "POST" -Body $testPayload

if ($setupPostResult.Success) {
    Write-Host "✅ Setup API (POST) отвечает" -ForegroundColor Green
    try {
        $responseData = $setupPostResult.Content | ConvertFrom-Json
        Write-Host "   Сообщение: $($responseData.message)"
    } catch {
        Write-Host "   Ответ: $($setupPostResult.Content.Substring(0, [Math]::Min(100, $setupPostResult.Content.Length)))"
    }
} else {
    Write-Host "❌ Setup API (POST) недоступен" -ForegroundColor Red
    Write-Host "   Статус: $($setupPostResult.StatusCode)"
    
    if ($setupPostResult.Content -like "*<html>*") {
        Write-Host "   🚨 Получен HTML вместо JSON - это указывает на проблему с nginx или middleware" -ForegroundColor Red
        Write-Host "      Возможные причины:" -ForegroundColor Yellow
        Write-Host "      - nginx блокирует POST запросы" -ForegroundColor Yellow
        Write-Host "      - middleware не пропускает запрос" -ForegroundColor Yellow
        Write-Host "      - неправильная конфигурация docker-compose" -ForegroundColor Yellow
    } else {
        Write-Host "   Ошибка: $($setupPostResult.Content)"
    }
}

Write-Host ""

# 5. Проверка файлов конфигурации
Write-Host "📂 Проверка файлов конфигурации..." -ForegroundColor Yellow

$configFiles = @(
    "nginx/nginx_dev.conf",
    "nginx/nginx_prod.conf", 
    "docker-compose.yml",
    "RareBooksService.WebApi/appsettings.json"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "✅ $file - существует" -ForegroundColor Green
    } else {
        Write-Host "❌ $file - отсутствует" -ForegroundColor Red
    }
}

Write-Host ""

# 6. Рекомендации
Write-Host "🎯 Рекомендации по устранению проблем:" -ForegroundColor Cyan

if ($testResult.Success -and $setupGetResult.Success -and !$setupPostResult.Success) {
    Write-Host "1. Проблема с POST запросами к /api/setup/initialize" -ForegroundColor Yellow
    Write-Host "   Решение: Перезапустите nginx и проверьте конфигурацию" -ForegroundColor White
    Write-Host "   Команда: docker-compose restart nginx" -ForegroundColor Gray
}

if (!$testResult.Success) {
    Write-Host "1. Проблема с backend сервером" -ForegroundColor Yellow
    Write-Host "   Решение: Перезапустите backend контейнер" -ForegroundColor White
    Write-Host "   Команда: docker-compose restart backend" -ForegroundColor Gray
}

if ($ForceSetupMode) {
    Write-Host "🔧 Принудительное включение режима setup..." -ForegroundColor Yellow
    Write-Host "   Удаляем appsettings.json чтобы система считала себя не настроенной..."
    $appsettingsPath = "RareBooksService.WebApi/appsettings.json"
    if (Test-Path $appsettingsPath) {
        Remove-Item $appsettingsPath -Backup
        Write-Host "✅ appsettings.json временно перемещен" -ForegroundColor Green
    }
}

if ($RestartServices) {
    Write-Host "🔄 Перезапуск сервисов..." -ForegroundColor Yellow
    try {
        docker-compose restart nginx backend
        Write-Host "✅ Сервисы перезапущены" -ForegroundColor Green
        Start-Sleep -Seconds 5
        Write-Host "Повторная проверка через 5 секунд..."
        
        # Повторный тест
        $retestResult = Test-Endpoint -Url "$BaseUrl/api/test/setup-status"
        if ($retestResult.Success) {
            Write-Host "✅ Сервисы восстановлены" -ForegroundColor Green
        } else {
            Write-Host "❌ Проблема не решена" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ Ошибка при перезапуске: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "💡 Дополнительные команды для диагностики:" -ForegroundColor Cyan
Write-Host "   ./setup-diagnostics.ps1 -RestartServices    # Перезапустить сервисы"
Write-Host "   ./setup-diagnostics.ps1 -ForceSetupMode     # Принудительно включить режим setup"
Write-Host "   docker-compose logs nginx                   # Логи nginx"
Write-Host "   docker-compose logs backend                 # Логи backend"

Write-Host ""
Write-Host "🏁 Диагностика завершена!" -ForegroundColor Green
