using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using System.Text;
using System.IO;
using RareBooksService.WebApi.Services;
using RareBooksService.Common.Models.Telegram;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using SystemFile = System.IO.File;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [AllowAnonymous] // Для удобства диагностики, можно потом добавить авторизацию
    public class TelegramDiagnosticsController : ControllerBase
    {
        private readonly IConfiguration _config;
        private readonly ILogger<TelegramDiagnosticsController> _logger;
        private readonly ITelegramNotificationService _telegramService;
        private readonly HttpClient _httpClient;
        private readonly IServiceProvider _serviceProvider;

        public TelegramDiagnosticsController(
            IConfiguration config,
            ILogger<TelegramDiagnosticsController> logger,
            ITelegramNotificationService telegramService,
            HttpClient httpClient,
            IServiceProvider serviceProvider)
        {
            _config = config;
            _logger = logger;
            _telegramService = telegramService;
            _httpClient = httpClient;
            _serviceProvider = serviceProvider;
        }

        /// <summary>
        /// Полная диагностика Telegram бота
        /// </summary>
        [HttpGet("full-check")]
        public async Task<IActionResult> FullDiagnostics()
        {
            var result = new
            {
                timestamp = DateTime.UtcNow,
                checks = new Dictionary<string, object>()
            };

            try
            {
                // 1. Проверка конфигурации
                var token = _config["TelegramBot:Token"];
                result.checks["config"] = new
                {
                    hasToken = !string.IsNullOrEmpty(token),
                    tokenLength = token?.Length ?? 0,
                    tokenMasked = string.IsNullOrEmpty(token) ? "NOT_SET" : $"{token.Substring(0, Math.Min(10, token.Length))}***",
                    configSource = "appsettings.json"
                };

                // 2. Проверка через Telegram API
                if (!string.IsNullOrEmpty(token))
                {
                    try
                    {
                        var response = await _httpClient.GetStringAsync($"https://api.telegram.org/bot{token}/getMe");
                        var botInfo = JsonSerializer.Deserialize<JsonElement>(response);
                        
                        result.checks["telegram_api"] = new
                        {
                            status = "success",
                            botInfo = botInfo.GetProperty("result"),
                            raw_response = response
                        };
                    }
                    catch (Exception ex)
                    {
                        result.checks["telegram_api"] = new
                        {
                            status = "error",
                            error = ex.Message,
                            details = ex.ToString()
                        };
                    }

                    // 3. Проверка webhook
                    try
                    {
                        var webhookResponse = await _httpClient.GetStringAsync($"https://api.telegram.org/bot{token}/getWebhookInfo");
                        var webhookInfo = JsonSerializer.Deserialize<JsonElement>(webhookResponse);
                        
                        result.checks["webhook"] = new
                        {
                            status = "success",
                            webhookInfo = webhookInfo.GetProperty("result"),
                            raw_response = webhookResponse
                        };
                    }
                    catch (Exception ex)
                    {
                        result.checks["webhook"] = new
                        {
                            status = "error",
                            error = ex.Message
                        };
                    }
                }
                else
                {
                    result.checks["telegram_api"] = new
                    {
                        status = "skipped",
                        reason = "No token configured"
                    };
                    result.checks["webhook"] = new
                    {
                        status = "skipped", 
                        reason = "No token configured"
                    };
                }

                // 4. Проверка сервисов
                result.checks["services"] = new
                {
                    telegramServiceRegistered = _telegramService != null,
                    serviceType = _telegramService?.GetType().Name ?? "null"
                };

                // 5. Проверка конфигурации из файла
                try
                {
                    var appSettingsPath = Path.Combine(Directory.GetCurrentDirectory(), "appsettings.json");
                    if (SystemFile.Exists(appSettingsPath))
                    {
                        var configContent = await SystemFile.ReadAllTextAsync(appSettingsPath);
                        var configJson = JsonSerializer.Deserialize<JsonElement>(configContent);
                        
                        var hasTelegramSection = configJson.TryGetProperty("TelegramBot", out var telegramSection);
                        string tokenFromFile = "NOT_SET";
                        
                        if (hasTelegramSection && telegramSection.TryGetProperty("Token", out var tokenProp))
                        {
                            if (tokenProp.ValueKind == JsonValueKind.String)
                            {
                                var tokenValue = tokenProp.GetString();
                                tokenFromFile = !string.IsNullOrEmpty(tokenValue) 
                                    ? $"{tokenValue.Substring(0, Math.Min(10, tokenValue.Length))}***" 
                                    : "EMPTY";
                            }
                        }
                        
                        var hasTokenInFile = hasTelegramSection && telegramSection.TryGetProperty("Token", out _);
                        
                        result.checks["config_file"] = new
                        {
                            fileExists = true,
                            hasTelegramSection = hasTelegramSection,
                            hasTokenInFile = hasTokenInFile,
                            tokenFromFile = tokenFromFile
                        };
                    }
                    else
                    {
                        result.checks["config_file"] = new
                        {
                            fileExists = false,
                            path = appSettingsPath
                        };
                    }
                }
                catch (Exception ex)
                {
                    result.checks["config_file"] = new
                    {
                        status = "error",
                        error = ex.Message
                    };
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = "Diagnostic failed",
                    message = ex.Message,
                    details = ex.ToString(),
                    partialResult = result
                });
            }
        }

        /// <summary>
        /// Тестирование отправки сообщения (требует chat_id)
        /// </summary>
        [HttpPost("test-send")]
        public async Task<IActionResult> TestSendMessage([FromBody] TestSendRequest request)
        {
            try
            {
                var token = _config["TelegramBot:Token"];
                if (string.IsNullOrEmpty(token))
                {
                    return BadRequest(new { error = "Token not configured" });
                }

                var payload = new
                {
                    chat_id = request.ChatId,
                    text = request.Message ?? "🔧 Тестовое сообщение от диагностики бота"
                };

                var jsonContent = JsonSerializer.Serialize(payload);
                var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync($"https://api.telegram.org/bot{token}/sendMessage", content);
                var responseText = await response.Content.ReadAsStringAsync();

                return Ok(new
                {
                    success = response.IsSuccessStatusCode,
                    statusCode = (int)response.StatusCode,
                    response = responseText,
                    request = payload
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = "Test send failed",
                    message = ex.Message,
                    details = ex.ToString()
                });
            }
        }

        /// <summary>
        /// Установка webhook для тестирования
        /// </summary>
        [HttpPost("setup-webhook")]
        public async Task<IActionResult> SetupWebhook([FromBody] SetupWebhookRequest request)
        {
            try
            {
                var token = _config["TelegramBot:Token"];
                if (string.IsNullOrEmpty(token))
                {
                    return BadRequest(new { error = "Token not configured" });
                }

                var webhookUrl = $"{request.BaseUrl}/api/telegram/webhook";
                
                var payload = new
                {
                    url = webhookUrl,
                    max_connections = 40,
                    allowed_updates = new[] { "message", "callback_query" }
                };

                var jsonContent = JsonSerializer.Serialize(payload);
                var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync($"https://api.telegram.org/bot{token}/setWebhook", content);
                var responseText = await response.Content.ReadAsStringAsync();

                return Ok(new
                {
                    success = response.IsSuccessStatusCode,
                    statusCode = (int)response.StatusCode,
                    response = responseText,
                    webhookUrl = webhookUrl,
                    request = payload
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = "Webhook setup failed",
                    message = ex.Message,
                    details = ex.ToString()
                });
            }
        }

        /// <summary>
        /// Удаление webhook для тестирования
        /// </summary>
        [HttpPost("delete-webhook")]
        public async Task<IActionResult> DeleteWebhook()
        {
            try
            {
                var token = _config["TelegramBot:Token"];
                if (string.IsNullOrEmpty(token))
                {
                    return BadRequest(new { error = "Token not configured" });
                }

                var response = await _httpClient.PostAsync($"https://api.telegram.org/bot{token}/deleteWebhook", 
                    new StringContent("{}", Encoding.UTF8, "application/json"));
                var responseText = await response.Content.ReadAsStringAsync();

                return Ok(new
                {
                    success = response.IsSuccessStatusCode,
                    statusCode = (int)response.StatusCode,
                    response = responseText
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = "Webhook deletion failed",
                    message = ex.Message,
                    details = ex.ToString()
                });
            }
        }

        /// <summary>
        /// Получение логов ошибок
        /// </summary>
        /*[HttpGet("logs")]
        public async Task<IActionResult> GetLogs([FromQuery] int hours = 1)
        {
            try
            {
                var logs = new List<string>();
                var sinceTime = DateTime.UtcNow.AddHours(-hours);

                // Попробуем найти файлы логов в обычных местах
                var possibleLogPaths = new[]
                {
                    Path.Combine(Directory.GetCurrentDirectory(), "logs"),
                    Path.Combine(Directory.GetCurrentDirectory(), "Logs"),
                    "/var/log/rarebooksservice",
                    "/home/www/logs",
                    "/var/www/logs"
                };

                foreach (var logDir in possibleLogPaths)
                {
                    if (Directory.Exists(logDir))
                    {
                        var logFiles = Directory.GetFiles(logDir, "*.log")
                            .Concat(Directory.GetFiles(logDir, "*.txt"))
                            .Where(f => SystemFile.GetLastWriteTime(f) > sinceTime)
                            .OrderByDescending(f => SystemFile.GetLastWriteTime(f))
                            .Take(3);

                        foreach (var file in logFiles)
                        {
                            try
                            {
                                var lines = await SystemFile.ReadAllLinesAsync(file);
                                var recentLines = lines
                                    .Where(line => line.Contains("WEBHOOK") || 
                                                  line.Contains("Telegram") || 
                                                  line.Contains("400") ||
                                                  line.Contains("ERROR"))
                                    .TakeLast(20);
                                
                                if (recentLines.Any())
                                {
                                    logs.Add($"=== {Path.GetFileName(file)} ===");
                                    logs.AddRange(recentLines);
                                    logs.Add("");
                                }
                            }
                            catch (Exception ex)
                            {
                                logs.Add($"Error reading {file}: {ex.Message}");
                            }
                        }
                    }
                }

                return Ok(new
                {
                    timestamp = DateTime.UtcNow,
                    timeRange = $"Last {hours} hours",
                    logEntries = logs,
                    totalEntries = logs.Count,
                    searchedPaths = possibleLogPaths
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = "Log reading failed",
                    message = ex.Message,
                    details = ex.ToString()
                });
            }
        }*/

        /// <summary>
        /// Тестирование уведомлений о лотах для всех пользователей (упрощенная версия)
        /// </summary>
        [HttpPost("test-notifications")]
        public async Task<IActionResult> TestNotifications([FromBody] TestNotificationsRequest request)
        {
            try
            {
                _logger.LogInformation("Запуск упрощенного тестирования уведомлений");

                using var scope = _serviceProvider.CreateScope();
                var telegramBotService = scope.ServiceProvider.GetRequiredService<ITelegramBotService>();
                var bookNotificationService = scope.ServiceProvider.GetRequiredService<IBookNotificationService>();

                // Используем унифицированный метод тестирования из TelegramBotService
                var notificationsCreated = await telegramBotService.TestNotificationsAsync(
                    request.LimitBooks,
                    request.ShowBookIds,
                    HttpContext.RequestAborted
                );

                _logger.LogInformation("Создано и отправлено {Count} уведомлений", notificationsCreated);

                // Получаем статистику для отчета
                var activePreferences = await bookNotificationService.GetActiveNotificationPreferencesAsync(HttpContext.RequestAborted);
                var telegramPreferences = activePreferences.Where(p => p.DeliveryMethod == NotificationDeliveryMethod.Telegram).ToList();

                return Ok(new
                {
                    success = true,
                    message = $"Тестирование завершено. Найдено {telegramPreferences.Count} настроек Telegram уведомлений, создано и отправлено {notificationsCreated} уведомлений",
                    activeBooks = request.LimitBooks,
                    activePreferences = telegramPreferences.Count,
                    notificationsCreated = notificationsCreated,
                    testBookIds = request.ShowBookIds ? new List<int>() : (List<int>?)null // Упрощаем для чистоты
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при тестировании уведомлений");
                return Ok(new
                {
                    success = false,
                    error = $"Ошибка тестирования: {ex.Message}",
                    details = ex.ToString()
                });
            }
        }

        /// <summary>
        /// Получение активных книг по критериям (аналогично SearchActiveLotsAsync в TelegramBotService)
        /// </summary>
        private async Task<List<int>> GetActiveBookIdsAsync(BooksDbContext booksContext, int limit = 100)
        {
            var query = booksContext.BooksInfo.AsQueryable();

            // Фильтр: только активные торги (торги еще не закончились)
            var now = DateTime.UtcNow;
            query = query.Where(b => b.EndDate > now);

            // Сортировка по дате окончания (ближайшие к завершению - первыми)
            query = query.OrderBy(b => b.EndDate);

            // Ограничиваем количество для тестирования
            var activeBookIds = await query
                .AsNoTracking()
                .Take(limit)
                .Select(b => b.Id)
                .ToListAsync();

            _logger.LogInformation("Найдено {Count} активных лотов из {Limit} запрошенных", activeBookIds.Count, limit);

            return activeBookIds;
        }
    }

    public class TestNotificationsRequest
    {
        /// <summary>
        /// Максимальное количество активных лотов для тестирования (по умолчанию 100)
        /// </summary>
        public int LimitBooks { get; set; } = 100;

        /// <summary>
        /// Показывать ли ID книг в ответе (для отладки)
        /// </summary>
        public bool ShowBookIds { get; set; } = false;
    }
}
