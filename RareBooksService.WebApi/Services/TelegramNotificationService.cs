using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.EntityFrameworkCore;
using Newtonsoft.Json;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Telegram;
using RareBooksService.Data;
using System.Text;

namespace RareBooksService.WebApi.Services
{
    public interface ITelegramNotificationService
    {
        Task<bool> SendNotificationAsync(string chatId, string message, CancellationToken cancellationToken = default);
        Task<bool> SendBookNotificationAsync(string chatId, RegularBaseBook book, List<string> matchedKeywords, CancellationToken cancellationToken = default);
        Task<TelegramUser?> GetUserInfoAsync(string chatId, CancellationToken cancellationToken = default);
        Task<bool> ValidateTokenAsync(CancellationToken cancellationToken = default);
        string GetBotUsername();
        
        // Интерактивное управление ботом
        Task<bool> SendMessageWithKeyboardAsync(string chatId, string message, TelegramInlineKeyboardMarkup keyboard = null, CancellationToken cancellationToken = default);
        Task<bool> EditMessageAsync(string chatId, int messageId, string newText, TelegramInlineKeyboardMarkup keyboard = null, CancellationToken cancellationToken = default);
        Task<bool> AnswerCallbackQueryAsync(string callbackQueryId, string text = null, bool showAlert = false, CancellationToken cancellationToken = default);
        Task<bool> SetWebhookAsync(string webhookUrl, CancellationToken cancellationToken = default);
        Task<bool> DeleteWebhookAsync(CancellationToken cancellationToken = default);
        
        // Управление состояниями пользователей
        Task<TelegramUserState> GetUserStateAsync(string telegramId, CancellationToken cancellationToken = default);
        Task SetUserStateAsync(string telegramId, string state, string stateData = null, CancellationToken cancellationToken = default);
        Task ClearUserStateAsync(string telegramId, CancellationToken cancellationToken = default);
        
        // Работа с настройками уведомлений через бота
        Task<ApplicationUser> FindUserByTelegramIdAsync(string telegramId, CancellationToken cancellationToken = default);
        Task<List<UserNotificationPreference>> GetUserNotificationPreferencesAsync(string userId, CancellationToken cancellationToken = default);
    }

    public class TelegramNotificationService : ITelegramNotificationService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<TelegramNotificationService> _logger;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly string _botToken;
        private readonly string _baseUrl;
        private readonly string _botUsername = "RareBooksReminderBot";

        public TelegramNotificationService(
            HttpClient httpClient, 
            IConfiguration configuration, 
            ILogger<TelegramNotificationService> logger,
            IServiceScopeFactory scopeFactory)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
            
            _botToken = configuration["TelegramBot:Token"] ?? "";
            _baseUrl = $"https://api.telegram.org/bot{_botToken}";
            
            // ДИАГНОСТИЧЕСКОЕ ЛОГИРОВАНИЕ
            _logger.LogInformation("[TELEGRAM-INIT] Bot Token читается из конфигурации");
            _logger.LogInformation("[TELEGRAM-INIT] Token length: {TokenLength}", _botToken?.Length ?? 0);
            _logger.LogInformation("[TELEGRAM-INIT] Token preview: {TokenPreview}", 
                string.IsNullOrEmpty(_botToken) ? "EMPTY" : $"{_botToken.Substring(0, Math.Min(10, _botToken.Length))}***");
            _logger.LogInformation("[TELEGRAM-INIT] Base URL: {BaseUrl}", _baseUrl);
            _logger.LogInformation("[TELEGRAM-INIT] HttpClient BaseAddress: {HttpClientBaseAddress}", _httpClient.BaseAddress);
            _logger.LogInformation("[TELEGRAM-INIT] All Telegram config keys: {ConfigKeys}", 
                string.Join(", ", configuration.AsEnumerable().Where(x => x.Key.Contains("Telegram")).Select(x => x.Key)));
            
            // Теперь будем использовать полные URL вместо BaseAddress
        }

        public string GetBotUsername() => _botUsername;

        public async Task<bool> ValidateTokenAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                var url = $"{_baseUrl}/getMe";
                var response = await _httpClient.GetAsync(url, cancellationToken);
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync(cancellationToken);
                    var result = JsonConvert.DeserializeObject<TelegramApiResponse<TelegramUser>>(content);
                    return result?.Ok == true;
                }
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при валидации токена Telegram бота");
                return false;
            }
        }

        public async Task<TelegramUser?> GetUserInfoAsync(string chatId, CancellationToken cancellationToken = default)
        {
            try
            {
                var url = $"{_baseUrl}/getChat?chat_id={chatId}";
                var response = await _httpClient.GetAsync(url, cancellationToken);
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync(cancellationToken);
                    var result = JsonConvert.DeserializeObject<TelegramApiResponse<TelegramUser>>(content);
                    return result?.Ok == true ? result.Result : null;
                }
                
                _logger.LogWarning("Не удалось получить информацию о пользователе {ChatId}. Status: {StatusCode}", 
                    chatId, response.StatusCode);
                return null;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении информации о пользователе {ChatId}", chatId);
                return null;
            }
        }

        public async Task<bool> SendNotificationAsync(string chatId, string message, CancellationToken cancellationToken = default)
        {
            try
            {
                // ДИАГНОСТИЧЕСКОЕ ЛОГИРОВАНИЕ
                _logger.LogInformation("[TELEGRAM-SEND] === НАЧАЛО ОТПРАВКИ СООБЩЕНИЯ ===");
                _logger.LogInformation("[TELEGRAM-SEND] Отправка сообщения в чат {ChatId}, длина: {MessageLength} символов", 
                    chatId, message?.Length ?? 0);
                _logger.LogInformation("[TELEGRAM-SEND] Token настроен: {HasToken}, длина: {TokenLength}", 
                    !string.IsNullOrEmpty(_botToken), _botToken?.Length ?? 0);
                _logger.LogInformation("[TELEGRAM-SEND] Base URL: {BaseUrl}", _baseUrl);
                
                // Проверяем токен
                if (string.IsNullOrEmpty(_botToken))
                {
                    _logger.LogError("[TELEGRAM-SEND] КРИТИЧЕСКАЯ ОШИБКА: токен бота не настроен!");
                    return false;
                }
                
                // Проверяем длину сообщения
                if (string.IsNullOrEmpty(message))
                {
                    _logger.LogWarning("[TELEGRAM-SEND] Попытка отправить пустое сообщение в чат {ChatId}", chatId);
                    return false;
                }
                
                if (message.Length > 4096)
                {
                    _logger.LogError("[TELEGRAM-SEND] Сообщение слишком длинное: {Length} символов (максимум 4096)", message.Length);
                    return false;
                }
                
                // Логируем первые 200 символов сообщения для диагностики
                var messagePreview = message.Length > 200 ? message.Substring(0, 200) + "..." : message;
                _logger.LogInformation("[TELEGRAM-SEND] Превью сообщения: {MessagePreview}", messagePreview);
                
                var payload = new
                {
                    chat_id = chatId,
                    text = message,
                    parse_mode = "HTML",
                    disable_web_page_preview = true
                };

                var json = JsonConvert.SerializeObject(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var url = $"{_baseUrl}/sendMessage";
                _logger.LogInformation("[TELEGRAM-SEND] Отправляем POST запрос на {Url}", url);
                _logger.LogInformation("[TELEGRAM-SEND] Content-Type: {ContentType}", content.Headers.ContentType);
                _logger.LogInformation("[TELEGRAM-SEND] JSON payload размер: {PayloadSize} символов", json.Length);
                
                try 
                {
                    var response = await _httpClient.PostAsync(url, content, cancellationToken);
                    _logger.LogInformation("[TELEGRAM-SEND] Получен ответ от Telegram API: {StatusCode}", response.StatusCode);
                    
                    if (response.IsSuccessStatusCode)
                    {
                        var successContent = await response.Content.ReadAsStringAsync(cancellationToken);
                        _logger.LogInformation("[TELEGRAM-SEND] ✅ УСПЕХ! Уведомление отправлено в чат {ChatId}. Ответ: {Response}", 
                            chatId, successContent);
                        return true;
                    }
                    
                    var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                    _logger.LogError("[TELEGRAM-SEND] ❌ ОШИБКА! Не удалось отправить уведомление в чат {ChatId}. Status: {StatusCode}, Response: {Response}", 
                        chatId, response.StatusCode, errorContent);

                    // Попробуем расшифровать JSON-ответ
                    try
                    {
                        var errorObj = JsonConvert.DeserializeObject<dynamic>(errorContent);
                        string errorCode = errorObj?.error_code?.ToString();
                        string description = errorObj?.description?.ToString();

                        _logger.LogError("[TELEGRAM-SEND] Детализированная ошибка: код {ErrorCode}, описание: {ErrorDescription}",
                            errorCode, description);
                            
                        // Если ошибка связана с HTML-парсингом, попробуем отправить без HTML
                        if (description?.Contains("can't parse entities") == true || 
                            description?.Contains("Bad Request") == true)
                        {
                            _logger.LogWarning("[TELEGRAM-SEND] Проблема с HTML-парсингом. Пробуем отправить без HTML форматирования");
                            return await SendPlainTextMessageAsync(chatId, StripHtmlTags(message), cancellationToken);
                        }
                    }
                    catch (Exception jsonEx)
                    {
                        _logger.LogWarning("[TELEGRAM-SEND] Не удалось расшифровать ошибку JSON: {Error}", jsonEx.Message);
                    }
                }
                catch (HttpRequestException httpEx)
                {
                    _logger.LogError(httpEx, "[TELEGRAM-SEND] HTTP ошибка при обращении к Telegram API");
                }
                catch (TaskCanceledException timeoutEx)
                {
                    _logger.LogError(timeoutEx, "[TELEGRAM-SEND] Таймаут при обращении к Telegram API");
                }

                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[TELEGRAM-SEND] КРИТИЧЕСКАЯ ОШИБКА при отправке уведомления в чат {ChatId}", chatId);
                return false;
            }
        }
        
        // Вспомогательный метод для отправки простого текста без HTML
        private async Task<bool> SendPlainTextMessageAsync(string chatId, string message, CancellationToken cancellationToken)
        {
            try
            {
                _logger.LogInformation("[TELEGRAM-SEND] Отправляем сообщение без HTML-форматирования");
                
                var payload = new
                {
                    chat_id = chatId,
                    text = message,
                    disable_web_page_preview = true
                };

                var json = JsonConvert.SerializeObject(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");
                var url = $"{_baseUrl}/sendMessage";
                
                var response = await _httpClient.PostAsync(url, content, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("[TELEGRAM-SEND] ✅ Сообщение без HTML успешно отправлено");
                    return true;
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                    _logger.LogError("[TELEGRAM-SEND] ❌ Не удалось отправить даже простое сообщение: {Error}", errorContent);
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[TELEGRAM-SEND] Ошибка при отправке простого сообщения");
                return false;
            }
        }
        
        // Метод для очистки HTML-тегов
        private string StripHtmlTags(string input)
        {
            if (string.IsNullOrEmpty(input)) return input;
            
            // Удаляем HTML-теги с помощью regex
            return System.Text.RegularExpressions.Regex.Replace(input, "<.*?>", string.Empty)
                .Replace("&quot;", "\"")
                .Replace("&amp;", "&")
                .Replace("&lt;", "<")
                .Replace("&gt;", ">")
                .Replace("&nbsp;", " ");
        }

        public async Task<bool> SendBookNotificationAsync(string chatId, RegularBaseBook book, List<string> matchedKeywords, CancellationToken cancellationToken = default)
        {
            try
            {
                var message = FormatBookNotification(book, matchedKeywords);
                return await SendNotificationAsync(chatId, message, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке уведомления о книге {BookId} в чат {ChatId}", book.Id, chatId);
                return false;
            }
        }

        private string FormatBookNotification(RegularBaseBook book, List<string> matchedKeywords)
        {
            var sb = new StringBuilder();
            
            sb.AppendLine("📚 <b>Найдена интересная книга!</b>");
            sb.AppendLine();
            sb.AppendLine($"<b>Название:</b> {EscapeHtml(book.Title)}");
            
            /*if (!string.IsNullOrEmpty(book.Description))
            {
                var description = book.Description.Length > 200 
                    ? book.Description.Substring(0, 200) + "..." 
                    : book.Description;
                sb.AppendLine($"<b>Описание:</b> {EscapeHtml(description)}");
            }*/

            sb.AppendLine($"<b>Текущая цена:</b> {book.Price:F0} ₽");
            
            /*if (book.FinalPrice.HasValue && book.FinalPrice > 0)
            {
                sb.AppendLine($"<b>Финальная цена:</b> {book.FinalPrice.Value:F0} ₽");
            }*/

            if (book.YearPublished.HasValue && book.YearPublished > 0)
            {
                sb.AppendLine($"<b>Год издания:</b> {book.YearPublished}");
            }

            /*if (!string.IsNullOrEmpty(book.City))
            {
                sb.AppendLine($"<b>Город:</b> {EscapeHtml(book.City)}");
            }*/

            sb.AppendLine($"<b>Дата окончания торгов:</b> {book.EndDate:dd.MM.yyyy HH:mm}");

            if (matchedKeywords?.Any() == true)
            {
                sb.AppendLine($"<b>Совпадения:</b> {EscapeHtml(string.Join(", ", matchedKeywords))}");
            }

            sb.AppendLine();
            sb.AppendLine($"🔗 <a href=\"https://meshok.net/item/{book.Id}\">Перейти к лоту</a>");

            return sb.ToString();
        }

        private string EscapeHtml(string text)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            return text
                .Replace("&", "&amp;")
                .Replace("<", "&lt;")
                .Replace(">", "&gt;")
                .Replace("\"", "&quot;");
        }

        // Интерактивное управление ботом

        public async Task<bool> SendMessageWithKeyboardAsync(string chatId, string message, TelegramInlineKeyboardMarkup keyboard = null, CancellationToken cancellationToken = default)
        {
            try
            {
                var payload = new
                {
                    chat_id = chatId,
                    text = message,
                    parse_mode = "HTML",
                    disable_web_page_preview = true,
                    reply_markup = keyboard
                };

                var json = JsonConvert.SerializeObject(payload, new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore
                });
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var url = $"{_baseUrl}/sendMessage";
                var response = await _httpClient.PostAsync(url, content, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Сообщение с клавиатурой отправлено в чат {ChatId}", chatId);
                    return true;
                }
                
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning("Не удалось отправить сообщение в чат {ChatId}. Status: {StatusCode}, Response: {Response}", 
                    chatId, response.StatusCode, errorContent);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке сообщения в чат {ChatId}", chatId);
                return false;
            }
        }

        public async Task<bool> EditMessageAsync(string chatId, int messageId, string newText, TelegramInlineKeyboardMarkup keyboard = null, CancellationToken cancellationToken = default)
        {
            try
            {
                var payload = new
                {
                    chat_id = chatId,
                    message_id = messageId,
                    text = newText,
                    parse_mode = "HTML",
                    disable_web_page_preview = true,
                    reply_markup = keyboard
                };

                var json = JsonConvert.SerializeObject(payload, new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore
                });
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var url = $"{_baseUrl}/editMessageText";
                var response = await _httpClient.PostAsync(url, content, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Сообщение отредактировано в чате {ChatId}", chatId);
                    return true;
                }
                
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning("Не удалось отредактировать сообщение в чате {ChatId}. Status: {StatusCode}, Response: {Response}", 
                    chatId, response.StatusCode, errorContent);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при редактировании сообщения в чате {ChatId}", chatId);
                return false;
            }
        }

        public async Task<bool> AnswerCallbackQueryAsync(string callbackQueryId, string text = null, bool showAlert = false, CancellationToken cancellationToken = default)
        {
            try
            {
                var payload = new
                {
                    callback_query_id = callbackQueryId,
                    text = text,
                    show_alert = showAlert
                };

                var json = JsonConvert.SerializeObject(payload, new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore
                });
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/answerCallbackQuery", content, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Ответ на callback query отправлен: {CallbackQueryId}", callbackQueryId);
                    return true;
                }
                
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при ответе на callback query {CallbackQueryId}", callbackQueryId);
                return false;
            }
        }

        public async Task<bool> SetWebhookAsync(string webhookUrl, CancellationToken cancellationToken = default)
        {
            try
            {
                var payload = new
                {
                    url = webhookUrl,
                    allowed_updates = new[] { "message", "callback_query" }
                };

                var json = JsonConvert.SerializeObject(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/setWebhook", content, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Webhook установлен: {WebhookUrl}", webhookUrl);
                    return true;
                }
                
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning("Не удалось установить webhook. Response: {Response}", errorContent);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при установке webhook");
                return false;
            }
        }

        public async Task<bool> DeleteWebhookAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                var response = await _httpClient.PostAsync("/deleteWebhook", null, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Webhook удален");
                    return true;
                }
                
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении webhook");
                return false;
            }
        }

        // Управление состояниями пользователей

        public async Task<TelegramUserState> GetUserStateAsync(string telegramId, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            return await context.TelegramUserStates
                .FirstOrDefaultAsync(s => s.TelegramId == telegramId, cancellationToken);
        }

        public async Task SetUserStateAsync(string telegramId, string state, string stateData = null, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var existingState = await context.TelegramUserStates
                .FirstOrDefaultAsync(s => s.TelegramId == telegramId, cancellationToken);

            if (existingState != null)
            {
                existingState.State = state;
                existingState.StateData = stateData;
                existingState.UpdatedAt = DateTime.UtcNow;
            }
            else
            {
                context.TelegramUserStates.Add(new TelegramUserState
                {
                    TelegramId = telegramId,
                    State = state,
                    StateData = stateData
                });
            }

            await context.SaveChangesAsync(cancellationToken);
        }

        public async Task ClearUserStateAsync(string telegramId, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var existingState = await context.TelegramUserStates
                .FirstOrDefaultAsync(s => s.TelegramId == telegramId, cancellationToken);

            if (existingState != null)
            {
                context.TelegramUserStates.Remove(existingState);
                await context.SaveChangesAsync(cancellationToken);
            }
        }

        // Работа с настройками уведомлений

        public async Task<ApplicationUser> FindUserByTelegramIdAsync(string telegramId, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            return await context.Users
                .FirstOrDefaultAsync(u => u.TelegramId == telegramId, cancellationToken);
        }

        public async Task<List<UserNotificationPreference>> GetUserNotificationPreferencesAsync(string userId, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            return await context.UserNotificationPreferences
                .Where(p => p.UserId == userId)
                .OrderBy(p => p.CreatedAt)
                .ToListAsync(cancellationToken);
        }
    }

    // DTO классы для работы с Telegram API
    public class TelegramApiResponse<T>
    {
        [JsonProperty("ok")]
        public bool Ok { get; set; }

        [JsonProperty("result")]
        public T Result { get; set; }

        [JsonProperty("description")]
        public string Description { get; set; }

        [JsonProperty("error_code")]
        public int? ErrorCode { get; set; }
    }

    public class TelegramUser
    {
        [JsonProperty("id")]
        public long Id { get; set; }

        [JsonProperty("is_bot")]
        public bool IsBot { get; set; }

        [JsonProperty("first_name")]
        public string FirstName { get; set; }

        [JsonProperty("last_name")]
        public string LastName { get; set; }

        [JsonProperty("username")]
        public string Username { get; set; }

        [JsonProperty("language_code")]
        public string LanguageCode { get; set; }

        [JsonProperty("type")]
        public string Type { get; set; }
    }
}
