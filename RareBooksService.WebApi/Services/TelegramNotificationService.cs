using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using RareBooksService.Common.Models;
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
    }

    public class TelegramNotificationService : ITelegramNotificationService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<TelegramNotificationService> _logger;
        private readonly string _botToken;
        private readonly string _baseUrl;
        private readonly string _botUsername = "RareBooksReminderBot";

        public TelegramNotificationService(
            HttpClient httpClient, 
            IConfiguration configuration, 
            ILogger<TelegramNotificationService> logger)
        {
            _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            
            _botToken = configuration["TelegramBot:Token"] ?? "";
            _baseUrl = $"https://api.telegram.org/bot{_botToken}";
            
            _httpClient.BaseAddress = new Uri(_baseUrl);
        }

        public string GetBotUsername() => _botUsername;

        public async Task<bool> ValidateTokenAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                var response = await _httpClient.GetAsync("/getMe", cancellationToken);
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
                var response = await _httpClient.GetAsync($"/getChat?chat_id={chatId}", cancellationToken);
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
                var payload = new
                {
                    chat_id = chatId,
                    text = message,
                    parse_mode = "HTML",
                    disable_web_page_preview = true
                };

                var json = JsonConvert.SerializeObject(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/sendMessage", content, cancellationToken);
                
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Уведомление отправлено в чат {ChatId}", chatId);
                    return true;
                }
                
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning("Не удалось отправить уведомление в чат {ChatId}. Status: {StatusCode}, Response: {Response}", 
                    chatId, response.StatusCode, errorContent);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке уведомления в чат {ChatId}", chatId);
                return false;
            }
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
            
            if (!string.IsNullOrEmpty(book.Description))
            {
                var description = book.Description.Length > 200 
                    ? book.Description.Substring(0, 200) + "..." 
                    : book.Description;
                sb.AppendLine($"<b>Описание:</b> {EscapeHtml(description)}");
            }

            sb.AppendLine($"<b>Текущая цена:</b> {book.Price:F0} ₽");
            
            if (book.FinalPrice.HasValue && book.FinalPrice > 0)
            {
                sb.AppendLine($"<b>Финальная цена:</b> {book.FinalPrice.Value:F0} ₽");
            }

            if (book.YearPublished.HasValue && book.YearPublished > 0)
            {
                sb.AppendLine($"<b>Год издания:</b> {book.YearPublished}");
            }

            if (!string.IsNullOrEmpty(book.City))
            {
                sb.AppendLine($"<b>Город:</b> {EscapeHtml(book.City)}");
            }

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
