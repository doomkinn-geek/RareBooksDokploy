# ========================================
# Скрипт диагностики Telegram бота
# https://rare-books.ru
# ========================================

param(
    [string]$BaseUrl = "https://rare-books.ru",
    [string]$ChatId = "",
    [switch]$Verbose
)

Write-Host "🔍 Диагностика Telegram бота для $BaseUrl" -ForegroundColor Cyan
Write-Host "⏰ Время: $(Get-Date)" -ForegroundColor Gray
Write-Host ""

# Функция для красивого вывода JSON
function Show-JsonResult {
    param($Result, $Title)
    Write-Host "📊 $Title" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────" -ForegroundColor Gray
    if ($Result) {
        $Result | ConvertTo-Json -Depth 10 | Write-Host
    } else {
        Write-Host "❌ Нет данных" -ForegroundColor Red
    }
    Write-Host ""
}

# Функция для проверки HTTP статуса
function Test-HttpEndpoint {
    param($Url, $Description)
    try {
        $response = Invoke-WebRequest -Uri $Url -Method GET -UseBasicParsing
        Write-Host "✅ $Description - OK (Status: $($response.StatusCode))" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ $Description - FAIL ($($_.Exception.Message))" -ForegroundColor Red
        return $false
    }
}

Write-Host "🌐 1. ПРОВЕРКА ДОСТУПНОСТИ СЕРВЕРА" -ForegroundColor Magenta
Write-Host "════════════════════════════════════════" -ForegroundColor Gray

# Основные эндпоинты
$endpoints = @{
    "Главная страница" = "$BaseUrl"
    "API статус" = "$BaseUrl/api/telegram/status"
    "Диагностика бота" = "$BaseUrl/api/telegramdiagnostics/full-check"
}

foreach ($endpoint in $endpoints.GetEnumerator()) {
    Test-HttpEndpoint -Url $endpoint.Value -Description $endpoint.Key
}

Write-Host ""
Write-Host "🔍 2. ПОЛНАЯ ДИАГНОСТИКА БОТА" -ForegroundColor Magenta
Write-Host "════════════════════════════════════════" -ForegroundColor Gray

try {
    $diagnostics = Invoke-RestMethod -Uri "$BaseUrl/api/telegramdiagnostics/full-check" -Method GET
    Show-JsonResult -Result $diagnostics -Title "Результат диагностики"
    
    # Анализ результатов
    Write-Host "📋 АНАЛИЗ РЕЗУЛЬТАТОВ:" -ForegroundColor Cyan
    
    if ($diagnostics.checks.config.hasToken) {
        Write-Host "✅ Токен настроен" -ForegroundColor Green
    } else {
        Write-Host "❌ Токен НЕ настроен!" -ForegroundColor Red
    }
    
    if ($diagnostics.checks.telegram_api.status -eq "success") {
        Write-Host "✅ Бот доступен в Telegram API" -ForegroundColor Green
        Write-Host "   Имя бота: $($diagnostics.checks.telegram_api.botInfo.first_name)" -ForegroundColor Gray
        Write-Host "   Username: @$($diagnostics.checks.telegram_api.botInfo.username)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Ошибка при обращении к Telegram API!" -ForegroundColor Red
        if ($diagnostics.checks.telegram_api.error) {
            Write-Host "   Ошибка: $($diagnostics.checks.telegram_api.error)" -ForegroundColor Red
        }
    }
    
    if ($diagnostics.checks.webhook.status -eq "success") {
        $webhook = $diagnostics.checks.webhook.webhookInfo
        if ($webhook.url) {
            Write-Host "✅ Webhook настроен: $($webhook.url)" -ForegroundColor Green
            if ($webhook.has_custom_certificate) {
                Write-Host "   Использует пользовательский сертификат" -ForegroundColor Gray
            }
            if ($webhook.pending_update_count -gt 0) {
                Write-Host "⚠️  Ожидает обновлений: $($webhook.pending_update_count)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  Webhook НЕ настроен" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ Ошибка при проверке webhook!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Ошибка при выполнении диагностики:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "🔧 3. ПРОВЕРКА СТАТУСА БОТА" -ForegroundColor Magenta
Write-Host "════════════════════════════════════════" -ForegroundColor Gray

try {
    $status = Invoke-RestMethod -Uri "$BaseUrl/api/telegram/status" -Method GET
    Show-JsonResult -Result $status -Title "Статус бота"
    
    if ($status.isValid) {
        Write-Host "✅ Бот корректно настроен" -ForegroundColor Green
    } else {
        Write-Host "❌ Бот НЕ настроен или токен неверный!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Ошибка при проверке статуса:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "⚙️  4. УПРАВЛЕНИЕ WEBHOOK" -ForegroundColor Magenta
Write-Host "════════════════════════════════════════" -ForegroundColor Gray

Write-Host "Команды для настройки webhook:" -ForegroundColor Gray
Write-Host "• Установить webhook:" -ForegroundColor Gray
Write-Host "  Invoke-RestMethod -Uri '$BaseUrl/api/telegramdiagnostics/setup-webhook' -Method POST -Body (@{baseUrl='$BaseUrl'} | ConvertTo-Json) -ContentType 'application/json'" -ForegroundColor DarkGray
Write-Host ""
Write-Host "• Удалить webhook:" -ForegroundColor Gray
Write-Host "  Invoke-RestMethod -Uri '$BaseUrl/api/telegramdiagnostics/delete-webhook' -Method POST -Body '{}' -ContentType 'application/json'" -ForegroundColor DarkGray

if ($ChatId) {
    Write-Host ""
    Write-Host "💬 5. ТЕСТИРОВАНИЕ ОТПРАВКИ СООБЩЕНИЯ" -ForegroundColor Magenta
    Write-Host "════════════════════════════════════════" -ForegroundColor Gray
    
    try {
        $testMessage = @{
            chatId = $ChatId
            message = "🔧 Тестовое сообщение диагностики - $(Get-Date)"
        }
        
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/telegramdiagnostics/test-send" -Method POST -Body ($testMessage | ConvertTo-Json) -ContentType 'application/json'
        
        if ($result.success) {
            Write-Host "✅ Сообщение отправлено успешно!" -ForegroundColor Green
        } else {
            Write-Host "❌ Ошибка отправки сообщения!" -ForegroundColor Red
            Show-JsonResult -Result $result -Title "Результат отправки"
        }
    } catch {
        Write-Host "❌ Ошибка при тестировании отправки:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📝 РЕКОМЕНДАЦИИ:" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray

Write-Host "1. Если токен не настроен:" -ForegroundColor Yellow
Write-Host "   • Зайдите в админ-панель: $BaseUrl/admin" -ForegroundColor Gray
Write-Host "   • Установите токен в разделе 'Настройки'" -ForegroundColor Gray
Write-Host "   • Перезапустите сервер" -ForegroundColor Gray

Write-Host ""
Write-Host "2. Если бот не отвечает:" -ForegroundColor Yellow
Write-Host "   • Проверьте настройку webhook" -ForegroundColor Gray
Write-Host "   • Убедитесь, что сервер доступен из интернета" -ForegroundColor Gray
Write-Host "   • Проверьте логи сервера на ошибки" -ForegroundColor Gray

Write-Host ""
Write-Host "3. Для получения Chat ID:" -ForegroundColor Yellow
Write-Host "   • Отправьте сообщение боту @RareBooksReminderBot" -ForegroundColor Gray
Write-Host "   • Откройте: https://api.telegram.org/bot<TOKEN>/getUpdates" -ForegroundColor Gray
Write-Host "   • Найдите your_chat_id в ответе" -ForegroundColor Gray

Write-Host ""
Write-Host "🎯 Диагностика завершена!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Gray
