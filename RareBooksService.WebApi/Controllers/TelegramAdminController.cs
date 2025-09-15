using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using RareBooksService.WebApi.Services;
using RareBooksService.Common.Models.Telegram;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/admin/telegram")]
    [Authorize(Roles = "Admin")] // Только для администраторов
    public class TelegramAdminController : ControllerBase
    {
        private readonly ITelegramNotificationService _telegramService;
        private readonly IConfiguration _configuration;
        private readonly ILogger<TelegramAdminController> _logger;

        public TelegramAdminController(
            ITelegramNotificationService telegramService,
            IConfiguration configuration,
            ILogger<TelegramAdminController> logger)
        {
            _telegramService = telegramService ?? throw new ArgumentNullException(nameof(telegramService));
            _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Получить информацию о состоянии бота
        /// </summary>
        [HttpGet("info")]
        public async Task<IActionResult> GetBotInfo()
        {
            try
            {
                var isValid = await _telegramService.ValidateTokenAsync();
                var botUsername = _telegramService.GetBotUsername();

                return Ok(new
                {
                    isValid,
                    botUsername,
                    token = _configuration["TelegramBot:Token"]?.Substring(0, 10) + "...", // Показываем только начало токена
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении информации о боте");
                return StatusCode(500, new { error = "Ошибка при получении информации о боте" });
            }
        }

        /// <summary>
        /// Настроить webhook для бота
        /// </summary>
        [HttpPost("webhook/setup")]
        public async Task<IActionResult> SetupWebhook([FromBody] SetupWebhookRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.BaseUrl))
                {
                    return BadRequest(new { error = "BaseUrl обязателен" });
                }

                // Формируем URL webhook
                var webhookUrl = request.BaseUrl.TrimEnd('/') + "/api/telegram/webhook";
                
                var success = await _telegramService.SetWebhookAsync(webhookUrl);
                
                if (success)
                {
                    _logger.LogInformation("Webhook успешно настроен: {WebhookUrl}", webhookUrl);
                    return Ok(new 
                    { 
                        success = true, 
                        webhookUrl = webhookUrl,
                        message = "Webhook успешно настроен" 
                    });
                }
                else
                {
                    return BadRequest(new { success = false, error = "Не удалось настроить webhook" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при настройке webhook");
                return StatusCode(500, new { error = "Внутренняя ошибка сервера" });
            }
        }

        /// <summary>
        /// Удалить webhook
        /// </summary>
        [HttpDelete("webhook")]
        public async Task<IActionResult> RemoveWebhook()
        {
            try
            {
                var success = await _telegramService.DeleteWebhookAsync();
                
                if (success)
                {
                    _logger.LogInformation("Webhook успешно удален");
                    return Ok(new { success = true, message = "Webhook удален" });
                }
                else
                {
                    return BadRequest(new { success = false, error = "Не удалось удалить webhook" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении webhook");
                return StatusCode(500, new { error = "Внутренняя ошибка сервера" });
            }
        }

        /// <summary>
        /// Отправить тестовое сообщение
        /// </summary>
        [HttpPost("test-message")]
        public async Task<IActionResult> SendTestMessage([FromBody] SendTestMessageRequest request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.ChatId) || string.IsNullOrWhiteSpace(request.Message))
                {
                    return BadRequest(new { error = "ChatId и Message обязательны" });
                }

                var success = await _telegramService.SendNotificationAsync(request.ChatId, request.Message);
                
                if (success)
                {
                    return Ok(new { success = true, message = "Тестовое сообщение отправлено" });
                }
                else
                {
                    return BadRequest(new { success = false, error = "Не удалось отправить сообщение" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке тестового сообщения");
                return StatusCode(500, new { error = "Внутренняя ошибка сервера" });
            }
        }

        /// <summary>
        /// Получить статистику по уведомлениям
        /// </summary>
        [HttpGet("statistics")]
        public async Task<IActionResult> GetNotificationStatistics()
        {
            try
            {
                // Здесь можно добавить статистику по отправленным уведомлениям
                // Пока возвращаем заглушку
                return Ok(new
                {
                    totalNotifications = 0,
                    successfulDeliveries = 0,
                    failedDeliveries = 0,
                    activeUsers = 0,
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении статистики");
                return StatusCode(500, new { error = "Внутренняя ошибка сервера" });
            }
        }
    }

    /// <summary>
    /// DTO для отправки тестового сообщения
    /// </summary>
    public class SendTestMessageRequest
    {
        public string ChatId { get; set; }
        public string Message { get; set; }
    }
}

