using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using RareBooksService.WebApi.Services;
using System.Security.Claims;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificationController : ControllerBase
    {
        private readonly UsersDbContext _context;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IBookNotificationService _notificationService;
        private readonly ITelegramNotificationService _telegramService;
        private readonly ITelegramLinkService _linkService;
        private readonly ILogger<NotificationController> _logger;

        public NotificationController(
            UsersDbContext context,
            UserManager<ApplicationUser> userManager,
            IBookNotificationService notificationService,
            ITelegramNotificationService telegramService,
            ITelegramLinkService linkService,
            ILogger<NotificationController> logger)
        {
            _context = context ?? throw new ArgumentNullException(nameof(context));
            _userManager = userManager ?? throw new ArgumentNullException(nameof(userManager));
            _notificationService = notificationService ?? throw new ArgumentNullException(nameof(notificationService));
            _telegramService = telegramService ?? throw new ArgumentNullException(nameof(telegramService));
            _linkService = linkService ?? throw new ArgumentNullException(nameof(linkService));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        /// <summary>
        /// Получить настройки уведомлений текущего пользователя
        /// </summary>
        [HttpGet("preferences")]
        public async Task<ActionResult<List<UserNotificationPreferenceDto>>> GetPreferences()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var preferences = await _context.UserNotificationPreferences
                .Where(p => p.UserId == userId)
                .Select(p => new UserNotificationPreferenceDto
                {
                    Id = p.Id,
                    IsEnabled = p.IsEnabled,
                    Keywords = p.Keywords,
                    CategoryIds = p.CategoryIds,
                    MinPrice = p.MinPrice,
                    MaxPrice = p.MaxPrice,
                    MinYear = p.MinYear,
                    MaxYear = p.MaxYear,
                    Cities = p.Cities,
                    NotificationFrequencyMinutes = p.NotificationFrequencyMinutes,
                    DeliveryMethod = p.DeliveryMethod,
                    LastNotificationSent = p.LastNotificationSent,
                    CreatedAt = p.CreatedAt,
                    UpdatedAt = p.UpdatedAt
                })
                .ToListAsync();

            return Ok(preferences);
        }

        /// <summary>
        /// Создать новые настройки уведомлений
        /// </summary>
        [HttpPost("preferences")]
        public async Task<ActionResult<UserNotificationPreferenceDto>> CreatePreference([FromBody] CreateNotificationPreferenceDto dto)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound("Пользователь не найден");

            // Проверяем способ доставки
            if (dto.DeliveryMethod == NotificationDeliveryMethod.Telegram && string.IsNullOrEmpty(user.TelegramId))
            {
                return BadRequest("Для использования Telegram уведомлений необходимо связать аккаунт с Telegram");
            }

            var preference = new UserNotificationPreference
            {
                UserId = userId,
                IsEnabled = dto.IsEnabled,
                Keywords = dto.Keywords ?? string.Empty,
                CategoryIds = dto.CategoryIds ?? string.Empty,
                MinPrice = dto.MinPrice,
                MaxPrice = dto.MaxPrice,
                MinYear = dto.MinYear,
                MaxYear = dto.MaxYear,
                Cities = dto.Cities ?? string.Empty,
                NotificationFrequencyMinutes = dto.NotificationFrequencyMinutes > 0 ? dto.NotificationFrequencyMinutes : 60,
                DeliveryMethod = dto.DeliveryMethod,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.UserNotificationPreferences.Add(preference);
            await _context.SaveChangesAsync();

            var result = new UserNotificationPreferenceDto
            {
                Id = preference.Id,
                IsEnabled = preference.IsEnabled,
                Keywords = preference.Keywords,
                CategoryIds = preference.CategoryIds,
                MinPrice = preference.MinPrice,
                MaxPrice = preference.MaxPrice,
                MinYear = preference.MinYear,
                MaxYear = preference.MaxYear,
                Cities = preference.Cities,
                NotificationFrequencyMinutes = preference.NotificationFrequencyMinutes,
                DeliveryMethod = preference.DeliveryMethod,
                LastNotificationSent = preference.LastNotificationSent,
                CreatedAt = preference.CreatedAt,
                UpdatedAt = preference.UpdatedAt
            };

            return CreatedAtAction(nameof(GetPreference), new { id = preference.Id }, result);
        }

        /// <summary>
        /// Получить конкретные настройки уведомлений
        /// </summary>
        [HttpGet("preferences/{id}")]
        public async Task<ActionResult<UserNotificationPreferenceDto>> GetPreference(int id)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var preference = await _context.UserNotificationPreferences
                .Where(p => p.Id == id && p.UserId == userId)
                .FirstOrDefaultAsync();

            if (preference == null) return NotFound();

            var result = new UserNotificationPreferenceDto
            {
                Id = preference.Id,
                IsEnabled = preference.IsEnabled,
                Keywords = preference.Keywords,
                CategoryIds = preference.CategoryIds,
                MinPrice = preference.MinPrice,
                MaxPrice = preference.MaxPrice,
                MinYear = preference.MinYear,
                MaxYear = preference.MaxYear,
                Cities = preference.Cities,
                NotificationFrequencyMinutes = preference.NotificationFrequencyMinutes,
                DeliveryMethod = preference.DeliveryMethod,
                LastNotificationSent = preference.LastNotificationSent,
                CreatedAt = preference.CreatedAt,
                UpdatedAt = preference.UpdatedAt
            };

            return Ok(result);
        }

        /// <summary>
        /// Обновить настройки уведомлений
        /// </summary>
        [HttpPut("preferences/{id}")]
        public async Task<ActionResult<UserNotificationPreferenceDto>> UpdatePreference(int id, [FromBody] UpdateNotificationPreferenceDto dto)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var preference = await _context.UserNotificationPreferences
                .Where(p => p.Id == id && p.UserId == userId)
                .FirstOrDefaultAsync();

            if (preference == null) return NotFound();

            // Проверяем способ доставки
            if (dto.DeliveryMethod == NotificationDeliveryMethod.Telegram)
            {
                var user = await _userManager.FindByIdAsync(userId);
                if (user == null || string.IsNullOrEmpty(user.TelegramId))
                {
                    return BadRequest("Для использования Telegram уведомлений необходимо связать аккаунт с Telegram");
                }
            }

            preference.IsEnabled = dto.IsEnabled;
            preference.Keywords = dto.Keywords ?? string.Empty;
            preference.CategoryIds = dto.CategoryIds ?? string.Empty;
            preference.MinPrice = dto.MinPrice;
            preference.MaxPrice = dto.MaxPrice;
            preference.MinYear = dto.MinYear;
            preference.MaxYear = dto.MaxYear;
            preference.Cities = dto.Cities ?? string.Empty;
            preference.NotificationFrequencyMinutes = dto.NotificationFrequencyMinutes > 0 ? dto.NotificationFrequencyMinutes : 60;
            preference.DeliveryMethod = dto.DeliveryMethod;
            preference.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            var result = new UserNotificationPreferenceDto
            {
                Id = preference.Id,
                IsEnabled = preference.IsEnabled,
                Keywords = preference.Keywords,
                CategoryIds = preference.CategoryIds,
                MinPrice = preference.MinPrice,
                MaxPrice = preference.MaxPrice,
                MinYear = preference.MinYear,
                MaxYear = preference.MaxYear,
                Cities = preference.Cities,
                NotificationFrequencyMinutes = preference.NotificationFrequencyMinutes,
                DeliveryMethod = preference.DeliveryMethod,
                LastNotificationSent = preference.LastNotificationSent,
                CreatedAt = preference.CreatedAt,
                UpdatedAt = preference.UpdatedAt
            };

            return Ok(result);
        }

        /// <summary>
        /// Удалить настройки уведомлений
        /// </summary>
        [HttpDelete("preferences/{id}")]
        public async Task<ActionResult> DeletePreference(int id)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var preference = await _context.UserNotificationPreferences
                .Where(p => p.Id == id && p.UserId == userId)
                .FirstOrDefaultAsync();

            if (preference == null) return NotFound();

            _context.UserNotificationPreferences.Remove(preference);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        /// <summary>
        /// Получить историю уведомлений пользователя
        /// </summary>
        [HttpGet("history")]
        public async Task<ActionResult<PagedResult<BookNotificationDto>>> GetNotificationHistory(
            [FromQuery] int page = 1, 
            [FromQuery] int pageSize = 20)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            pageSize = Math.Min(pageSize, 100); // Максимум 100 записей за раз
            var skip = (page - 1) * pageSize;

            var query = _context.BookNotifications
                .Where(n => n.UserId == userId)
                .OrderByDescending(n => n.CreatedAt);

            var totalCount = await query.CountAsync();
            var notifications = await query
                .Skip(skip)
                .Take(pageSize)
                .Select(n => new BookNotificationDto
                {
                    Id = n.Id,
                    BookId = n.BookId,
                    BookTitle = n.BookTitle,
                    BookDescription = n.BookDescription,
                    BookPrice = n.BookPrice,
                    BookFinalPrice = n.BookFinalPrice,
                    BookCity = n.BookCity,
                    BookBeginDate = n.BookBeginDate,
                    BookEndDate = n.BookEndDate,
                    BookStatus = n.BookStatus,
                    DeliveryMethod = n.DeliveryMethod,
                    Status = n.Status,
                    Subject = n.Subject,
                    MatchedKeywords = n.MatchedKeywords,
                    CreatedAt = n.CreatedAt,
                    SentAt = n.SentAt,
                    DeliveredAt = n.DeliveredAt,
                    ReadAt = n.ReadAt,
                    ErrorMessage = n.ErrorMessage,
                    AttemptsCount = n.AttemptsCount
                })
                .ToListAsync();

            var result = new PagedResult<BookNotificationDto>
            {
                Items = notifications,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize,
                TotalPages = (int)Math.Ceiling((double)totalCount / pageSize)
            };

            return Ok(result);
        }

        /// <summary>
        /// Сгенерировать токен для привязки Telegram аккаунта
        /// </summary>
        [HttpPost("telegram/generate-link-token")]
        public async Task<ActionResult<GenerateLinkTokenResponseDto>> GenerateLinkToken()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound("Пользователь не найден");

            // Проверяем, не привязан ли уже Telegram
            if (!string.IsNullOrEmpty(user.TelegramId))
            {
                return BadRequest(new { message = "Telegram аккаунт уже привязан к этому пользователю" });
            }

            try
            {
                var token = await _linkService.GenerateLinkTokenAsync(userId);
                
                return Ok(new GenerateLinkTokenResponseDto
                {
                    Token = token,
                    ExpiresAt = DateTime.UtcNow.AddHours(24),
                    Instructions = new[]
                    {
                        "1. Откройте Telegram и найдите бота @RareBooksReminderBot",
                        "2. Отправьте команду: /start",
                        "3. Отправьте команду: /link " + token,
                        "4. Следуйте инструкциям бота"
                    }
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при генерации токена привязки для пользователя {UserId}", userId);
                return StatusCode(500, new { message = "Ошибка при генерации токена" });
            }
        }

        /// <summary>
        /// Связать аккаунт с Telegram (старый метод для совместимости)
        /// </summary>
        [HttpPost("telegram/connect")]
        public async Task<ActionResult> ConnectTelegram([FromBody] ConnectTelegramDto dto)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound("Пользователь не найден");

            // Проверяем, что Telegram ID не используется другим пользователем
            var existingUser = await _userManager.Users
                .FirstOrDefaultAsync(u => u.TelegramId == dto.TelegramId && u.Id != userId);
            
            if (existingUser != null)
            {
                return BadRequest("Этот Telegram аккаунт уже связан с другим пользователем");
            }

            // Проверяем корректность Telegram ID через API
            var telegramUser = await _telegramService.GetUserInfoAsync(dto.TelegramId);
            if (telegramUser == null)
            {
                return BadRequest("Не удалось найти пользователя Telegram с указанным ID");
            }

            user.TelegramId = dto.TelegramId;
            user.TelegramUsername = dto.TelegramUsername;

            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded)
            {
                return BadRequest("Ошибка при обновлении данных пользователя");
            }

            // Отправляем приветственное сообщение
            try
            {
                await _telegramService.SendNotificationAsync(dto.TelegramId, 
                    "🎉 Ваш аккаунт успешно связан с системой уведомлений о редких книгах!\n\n" +
                    "Теперь вы будете получать уведомления о новых интересных лотах прямо в Telegram.");
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Не удалось отправить приветственное сообщение пользователю {UserId}", userId);
            }

            return Ok(new { message = "Telegram аккаунт успешно связан" });
        }

        /// <summary>
        /// Отвязать аккаунт от Telegram
        /// </summary>
        [HttpPost("telegram/disconnect")]
        public async Task<ActionResult> DisconnectTelegram()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound("Пользователь не найден");

            user.TelegramId = null;
            user.TelegramUsername = null;

            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded)
            {
                return BadRequest("Ошибка при обновлении данных пользователя");
            }

            // Отключаем все Telegram уведомления для пользователя
            var telegramPreferences = await _context.UserNotificationPreferences
                .Where(p => p.UserId == userId && p.DeliveryMethod == NotificationDeliveryMethod.Telegram)
                .ToListAsync();

            foreach (var preference in telegramPreferences)
            {
                preference.DeliveryMethod = NotificationDeliveryMethod.Email;
                preference.UpdatedAt = DateTime.UtcNow;
            }

            if (telegramPreferences.Any())
            {
                await _context.SaveChangesAsync();
            }

            return Ok(new { message = "Telegram аккаунт успешно отвязан" });
        }

        /// <summary>
        /// Получить информацию о подключении к Telegram
        /// </summary>
        [HttpGet("telegram/status")]
        public async Task<ActionResult<TelegramStatusDto>> GetTelegramStatus()
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound("Пользователь не найден");

            var result = new TelegramStatusDto
            {
                IsConnected = !string.IsNullOrEmpty(user.TelegramId),
                TelegramId = user.TelegramId,
                TelegramUsername = user.TelegramUsername,
                BotUsername = _telegramService.GetBotUsername()
            };

            return Ok(result);
        }

        /// <summary>
        /// Отправить тестовое уведомление
        /// </summary>
        [HttpPost("test")]
        public async Task<ActionResult> SendTestNotification([FromBody] SendTestNotificationDto dto)
        {
            var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userId == null) return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return NotFound("Пользователь не найден");

            string message = "🧪 Тестовое уведомление\n\n" +
                           "Это тестовое сообщение для проверки системы уведомлений о редких книгах.\n\n" +
                           $"Отправлено: {DateTime.Now:dd.MM.yyyy HH:mm}";

            bool success = false;
            string errorMessage = null;

            try
            {
                switch (dto.DeliveryMethod)
                {
                    case NotificationDeliveryMethod.Telegram:
                        if (string.IsNullOrEmpty(user.TelegramId))
                        {
                            return BadRequest("Telegram аккаунт не связан");
                        }
                        success = await _telegramService.SendNotificationAsync(user.TelegramId, message);
                        break;

                    case NotificationDeliveryMethod.Email:
                        // TODO: Реализовать отправку email
                        return BadRequest("Email уведомления пока не поддерживаются");

                    default:
                        return BadRequest("Неподдерживаемый способ доставки");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке тестового уведомления пользователю {UserId}", userId);
                errorMessage = ex.Message;
            }

            if (success)
            {
                return Ok(new { message = "Тестовое уведомление отправлено" });
            }
            else
            {
                return BadRequest(new { message = "Не удалось отправить тестовое уведомление", error = errorMessage });
            }
        }
    }

    // DTO классы
    public class GenerateLinkTokenResponseDto
    {
        public string Token { get; set; }
        public DateTime ExpiresAt { get; set; }
        public string[] Instructions { get; set; }
    }
}
