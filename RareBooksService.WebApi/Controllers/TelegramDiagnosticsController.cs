using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using System.Text.Json;
using System.Text;
using System.IO;
using RareBooksService.WebApi.Services;
using RareBooksService.Common.Models.Telegram;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
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
        /// Тестирование системы уведомлений с реальными активными лотами
        /// </summary>
        [HttpPost("test-notifications")]
        public async Task<IActionResult> TestNotifications([FromBody] TestNotificationsRequest request)
        {
            try
            {
                _logger.LogInformation("Начинаем тестирование системы уведомлений...");

                using var scope = _serviceProvider.CreateScope();
                var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();
                var booksContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                var bookNotificationService = scope.ServiceProvider.GetRequiredService<IBookNotificationService>();

                // Получаем все активные настройки уведомлений
                var activePreferences = await usersContext.UserNotificationPreferences
                    .Include(np => np.User)
                    .Where(np => np.IsEnabled && !string.IsNullOrEmpty(np.User.TelegramId))
                    .ToListAsync();

                if (!activePreferences.Any())
                {
                    return Ok(new 
                    { 
                        success = false, 
                        message = "Нет пользователей с активными настройками уведомлений и Telegram ID",
                        details = new 
                        {
                            totalActivePreferences = 0,
                            usersWithTelegram = 0,
                            activeLotsFound = 0,
                            notificationsCreated = 0
                        }
                    });
                }

                _logger.LogInformation("Найдено {Count} активных настроек уведомлений", activePreferences.Count);

                // Получаем все активные лоты
                var now = DateTime.UtcNow;
                var activeLots = await booksContext.BooksInfo
                    .Include(b => b.Category)
                    .Where(b => b.EndDate > now)
                    .AsNoTracking()
                    .ToListAsync();

                if (!activeLots.Any())
                {
                    return Ok(new 
                    { 
                        success = false, 
                        message = "Нет активных лотов на торгах",
                        details = new 
                        {
                            totalActivePreferences = activePreferences.Count,
                            usersWithTelegram = activePreferences.Count,
                            activeLotsFound = 0,
                            notificationsCreated = 0
                        }
                    });
                }

                _logger.LogInformation("Найдено {Count} активных лотов", activeLots.Count);

                // Собираем все подходящие лоты для всех пользователей
                var matchingBookIds = new HashSet<int>();
                var matchedCounts = new Dictionary<string, int>();

                foreach (var preference in activePreferences)
                {
                    var userMatchingBooks = FilterBooksByPreferences(activeLots, preference);
                    var userMatchingIds = userMatchingBooks.Select(b => b.Id).ToList();
                    
                    matchedCounts[preference.User.Email ?? preference.User.Id] = userMatchingIds.Count;
                    
                    foreach (var bookId in userMatchingIds)
                    {
                        matchingBookIds.Add(bookId);
                    }
                    
                    _logger.LogInformation("Пользователь {UserEmail}: найдено {Count} подходящих лотов", 
                        preference.User.Email ?? preference.User.Id, userMatchingIds.Count);
                }

                if (!matchingBookIds.Any())
                {
                    return Ok(new 
                    { 
                        success = false, 
                        message = "Нет активных лотов, соответствующих критериям пользователей",
                        details = new 
                        {
                            totalActivePreferences = activePreferences.Count,
                            usersWithTelegram = activePreferences.Count,
                            activeLotsFound = activeLots.Count,
                            notificationsCreated = 0,
                            userMatches = matchedCounts
                        }
                    });
                }

                _logger.LogInformation("Всего найдено {Count} уникальных подходящих лотов", matchingBookIds.Count);

                // Ограничиваем количество лотов для тестирования (чтобы не спамить)
                var testBookIds = matchingBookIds.Take(request?.MaxBooks ?? 10).ToList();
                
                // Отправляем уведомления
                var notificationsCreated = await bookNotificationService.ProcessNotificationsForNewBooksAsync(testBookIds);

                _logger.LogInformation("Создано {Count} уведомлений для {BookCount} книг", notificationsCreated, testBookIds.Count);

                return Ok(new 
                { 
                    success = true, 
                    message = $"Тестирование завершено. Создано {notificationsCreated} уведомлений для {testBookIds.Count} книг",
                    details = new 
                    {
                        totalActivePreferences = activePreferences.Count,
                        usersWithTelegram = activePreferences.Count,
                        activeLotsFound = activeLots.Count,
                        uniqueMatchingLots = matchingBookIds.Count,
                        processedBooks = testBookIds.Count,
                        notificationsCreated = notificationsCreated,
                        userMatches = matchedCounts,
                        processedBookIds = testBookIds
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при тестировании системы уведомлений");
                return StatusCode(500, new 
                { 
                    success = false, 
                    error = "Ошибка тестирования системы уведомлений", 
                    message = ex.Message 
                });
            }
        }

        /// <summary>
        /// Фильтрует книги по критериям пользователя (аналогично команде /lots)
        /// </summary>
        private List<RegularBaseBook> FilterBooksByPreferences(List<RegularBaseBook> books, UserNotificationPreference preferences)
        {
            var result = books.AsEnumerable();

            // Фильтр по ключевым словам
            var keywords = preferences.GetKeywordsList();
            if (keywords.Any())
            {
                result = result.Where(book =>
                {
                    var title = book.NormalizedTitle?.ToLower() ?? book.Title?.ToLower() ?? "";
                    var description = book.NormalizedDescription?.ToLower() ?? book.Description?.ToLower() ?? "";
                    var tags = book.Tags != null ? string.Join(" ", book.Tags).ToLower() : "";

                    return keywords.Any(keyword => 
                        title.Contains(keyword) || 
                        description.Contains(keyword) || 
                        tags.Contains(keyword));
                });
            }

            // Фильтр по категориям
            var categoryIds = preferences.GetCategoryIdsList();
            if (categoryIds.Any())
            {
                result = result.Where(book => categoryIds.Contains(book.CategoryId));
            }

            // Фильтр по цене
            if (preferences.MinPrice > 0)
            {
                result = result.Where(book => (decimal)book.Price >= preferences.MinPrice);
            }
            if (preferences.MaxPrice > 0)
            {
                result = result.Where(book => (decimal)book.Price <= preferences.MaxPrice);
            }

            // Фильтр по году издания
            if (preferences.MinYear > 0)
            {
                result = result.Where(book => book.YearPublished >= preferences.MinYear);
            }
            if (preferences.MaxYear > 0)
            {
                result = result.Where(book => book.YearPublished <= preferences.MaxYear);
            }

            // Фильтр по городам
            var cities = preferences.GetCitiesList();
            if (cities.Any())
            {
                result = result.Where(book =>
                {
                    var bookCity = book.City?.ToLower() ?? "";
                    return cities.Any(city => bookCity.Contains(city));
                });
            }

            return result.ToList();
        }
    }

    /// <summary>
    /// Модель запроса для тестирования уведомлений
    /// </summary>
    public class TestNotificationsRequest
    {
        /// <summary>
        /// Максимальное количество книг для тестирования (по умолчанию 10)
        /// </summary>
        public int? MaxBooks { get; set; } = 10;

        /// <summary>
        /// Только для определенного пользователя (по email)
        /// </summary>
        public string? UserEmail { get; set; }
    }
}
