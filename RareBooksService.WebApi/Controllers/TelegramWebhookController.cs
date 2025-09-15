using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models.Telegram;
using RareBooksService.WebApi.Services;
using System.Text.Json;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/telegram")]
    public class TelegramWebhookController : ControllerBase
    {
        private readonly ITelegramBotService _botService;
        private readonly ILogger<TelegramWebhookController> _logger;

        public TelegramWebhookController(
            ITelegramBotService botService,
            ILogger<TelegramWebhookController> logger)
        {
            _botService = botService ?? throw new ArgumentNullException(nameof(botService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Webhook endpoint для получения обновлений от Telegram
        /// </summary>
        [HttpPost("webhook")]
        public async Task<IActionResult> Webhook([FromBody] TelegramUpdate update)
        {
            try
            {
                _logger.LogInformation("[WEBHOOK] Получено обновление от Telegram: {UpdateId}", update?.UpdateId);

                if (update == null)
                {
                    _logger.LogWarning("[WEBHOOK] Получено пустое обновление от Telegram");
                    // ВАЖНО: всегда возвращаем 200 OK для Telegram, даже при ошибках
                    return Ok(new { status = "ignored", reason = "Update is null" });
                }

                _logger.LogInformation("[WEBHOOK] Обрабатываем обновление {UpdateId}", update.UpdateId);
                await _botService.ProcessUpdateAsync(update);
                
                _logger.LogInformation("[WEBHOOK] Обновление {UpdateId} успешно обработано", update.UpdateId);
                return Ok(new { status = "success", updateId = update.UpdateId });
            }
            catch (JsonException jsonEx)
            {
                _logger.LogError(jsonEx, "[WEBHOOK] Ошибка десериализации JSON от Telegram");
                // Всегда возвращаем 200 OK для Telegram
                return Ok(new { status = "error", reason = "JSON parsing failed" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[WEBHOOK] Ошибка при обработке webhook от Telegram");
                // Всегда возвращаем 200 OK для Telegram
                return Ok(new { status = "error", reason = "Processing failed" });
            }
        }

        /// <summary>
        /// Диагностический endpoint для просмотра сырых данных от Telegram
        /// </summary>
        [HttpPost("webhook-debug")]
        public async Task<IActionResult> WebhookDebug()
        {
            try
            {
                // Читаем сырое тело запроса
                var requestBody = await new StreamReader(Request.Body).ReadToEndAsync();
                
                _logger.LogInformation("[WEBHOOK-DEBUG] Получен запрос от Telegram: {RequestBody}", requestBody);
                
                // Пытаемся десериализовать
                TelegramUpdate update = null;
                try
                {
                    update = JsonSerializer.Deserialize<TelegramUpdate>(requestBody);
                    _logger.LogInformation("[WEBHOOK-DEBUG] Десериализация успешна: UpdateId={UpdateId}", update?.UpdateId);
                }
                catch (JsonException ex)
                {
                    _logger.LogError(ex, "[WEBHOOK-DEBUG] Ошибка десериализации JSON");
                }

                return Ok(new 
                { 
                    status = "debug",
                    timestamp = DateTime.UtcNow,
                    rawBody = requestBody,
                    deserializedUpdate = update,
                    headers = Request.Headers.ToDictionary(h => h.Key, h => h.Value.ToString())
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[WEBHOOK-DEBUG] Ошибка в debug endpoint");
                return Ok(new { status = "debug-error", error = ex.Message });
            }
        }

        /// <summary>
        /// Установка URL webhook для Telegram бота
        /// </summary>
        [HttpPost("set-webhook")]
        public async Task<IActionResult> SetWebhook([FromBody] SetWebhookRequest request)
        {
            try
            {
                var telegramService = HttpContext.RequestServices.GetRequiredService<ITelegramNotificationService>();
                var success = await telegramService.SetWebhookAsync(request.WebhookUrl);
                
                if (success)
                {
                    _logger.LogInformation("Webhook успешно установлен: {WebhookUrl}", request.WebhookUrl);
                    return Ok(new { success = true, message = "Webhook установлен успешно" });
                }
                else
                {
                    return BadRequest(new { success = false, message = "Не удалось установить webhook" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при установке webhook");
                return StatusCode(500, new { success = false, message = "Внутренняя ошибка сервера" });
            }
        }

        /// <summary>
        /// Удаление webhook Telegram бота
        /// </summary>
        [HttpPost("delete-webhook")]
        public async Task<IActionResult> DeleteWebhook()
        {
            try
            {
                var telegramService = HttpContext.RequestServices.GetRequiredService<ITelegramNotificationService>();
                var success = await telegramService.DeleteWebhookAsync();
                
                if (success)
                {
                    _logger.LogInformation("Webhook успешно удален");
                    return Ok(new { success = true, message = "Webhook удален успешно" });
                }
                else
                {
                    return BadRequest(new { success = false, message = "Не удалось удалить webhook" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении webhook");
                return StatusCode(500, new { success = false, message = "Внутренняя ошибка сервера" });
            }
        }

        /// <summary>
        /// Проверка состояния бота
        /// </summary>
        [HttpGet("status")]
        public async Task<IActionResult> GetBotStatus()
        {
            try
            {
                var telegramService = HttpContext.RequestServices.GetRequiredService<ITelegramNotificationService>();
                var isValid = await telegramService.ValidateTokenAsync();
                
                return Ok(new 
                { 
                    isValid, 
                    botUsername = telegramService.GetBotUsername(),
                    timestamp = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при проверке состояния бота");
                return StatusCode(500, new { success = false, message = "Внутренняя ошибка сервера" });
            }
        }

        /// <summary>
        /// Отправка тестового сообщения через бота
        /// </summary>
        [HttpPost("test-message")]
        public async Task<IActionResult> SendTestMessage([FromBody] TestMessageRequest request)
        {
            try
            {
                var telegramService = HttpContext.RequestServices.GetRequiredService<ITelegramNotificationService>();
                var success = await telegramService.SendNotificationAsync(request.ChatId, request.Message);
                
                if (success)
                {
                    return Ok(new { success = true, message = "Тестовое сообщение отправлено" });
                }
                else
                {
                    return BadRequest(new { success = false, message = "Не удалось отправить сообщение" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке тестового сообщения");
                return StatusCode(500, new { success = false, message = "Внутренняя ошибка сервера" });
            }
        }
    }

    /// <summary>
    /// DTO для установки webhook
    /// </summary>
    public class SetWebhookRequest
    {
        public string WebhookUrl { get; set; }
    }

    /// <summary>
    /// DTO для тестового сообщения
    /// </summary>
    public class TestMessageRequest
    {
        public string ChatId { get; set; }
        public string Message { get; set; }
    }
}

