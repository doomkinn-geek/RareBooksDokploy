using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using System.Text;
using RareBooksService.WebApi.Services;

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

        public TelegramDiagnosticsController(
            IConfiguration config,
            ILogger<TelegramDiagnosticsController> logger,
            ITelegramNotificationService telegramService,
            HttpClient httpClient)
        {
            _config = config;
            _logger = logger;
            _telegramService = telegramService;
            _httpClient = httpClient;
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
                    if (File.Exists(appSettingsPath))
                    {
                        var configContent = await File.ReadAllTextAsync(appSettingsPath);
                        var configJson = JsonSerializer.Deserialize<JsonElement>(configContent);
                        
                        var hasTelegramSection = configJson.TryGetProperty("TelegramBot", out var telegramSection);
                        var hasTokenInFile = hasTelegramSection && telegramSection.TryGetProperty("Token", out var tokenProp);
                        
                        result.checks["config_file"] = new
                        {
                            fileExists = true,
                            hasTelegramSection = hasTelegramSection,
                            hasTokenInFile = hasTokenInFile,
                            tokenFromFile = hasTokenInFile ? $"{tokenProp.GetString()?.Substring(0, Math.Min(10, tokenProp.GetString()?.Length ?? 0))}***" : "NOT_SET"
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
        [HttpGet("logs")]
        public async Task<IActionResult> GetLogs([FromQuery] int hours = 1)
        {
            try
            {
                // Здесь можно добавить логику чтения логов из файла или базы данных
                // Пока возвращаем заглушку
                return Ok(new
                {
                    message = "Log reading not implemented yet",
                    suggestion = "Check application logs manually or implement custom log reader",
                    timeRange = $"Last {hours} hours"
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    error = "Log reading failed",
                    message = ex.Message
                });
            }
        }
    }

    public class TestSendRequest
    {
        public string ChatId { get; set; } = string.Empty;
        public string? Message { get; set; }
    }

    public class SetupWebhookRequest
    {
        public string BaseUrl { get; set; } = string.Empty;
    }
}
