using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using RareBooksService.WebApi.Services;
using System.Security.Claims;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // <-- Не забудьте, если нужно
    public class SubscriptionController : BaseController
    {
        private readonly UsersDbContext _context; // <-- добавлено
        private readonly IYandexKassaPaymentService _paymentService;
        private readonly ISubscriptionService _subscriptionService;
        private readonly ILogger<SubscriptionController> _logger;

        public SubscriptionController(
            UserManager<ApplicationUser> userManager,
            UsersDbContext context,
            IYandexKassaPaymentService paymentService,
            ISubscriptionService subscriptionService,
            ILogger<SubscriptionController> logger) : base(userManager)
        {
            _context = context;
            _paymentService = paymentService;
            _subscriptionService = subscriptionService;
            _logger = logger;
        }

        /// <summary>
        /// Получить список доступных планов (DTO)
        /// </summary>
        [HttpGet("plans")]
        [AllowAnonymous]
        public async Task<IActionResult> GetPlans()
        {
            try
            {
                _logger.LogInformation("Получен запрос на получение списка активных планов подписки.");

                var planDtos = await _subscriptionService.GetActiveSubscriptionPlansAsync();

                // Дополнительный лог об успешно полученных планах
                _logger.LogInformation("Успешно получен список планов подписки (Count={Count}).", planDtos?.Count ?? 0);

                return Ok(planDtos ?? new List<SubscriptionPlanDto>());
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении планов подписки в методе GetPlans");
                // Возвращаем пустой список, чтобы фронтенд мог отобразить сообщение без падения
                return Ok(new List<SubscriptionPlanDto>());
            }
        }


        /// <summary>
        /// Создаёт оплату. Пользователь выбирает planId, autoRenew. 
        /// Создаем Subscription (не активную) + платёж в ЮKassa.
        /// </summary>
        [HttpPost("create-payment")]
        public async Task<IActionResult> CreatePayment([FromBody] CreatePaymentRequest request)
        {
            try
            {
                if (request == null || request.SubscriptionPlanId <= 0)
                    return BadRequest("Не указан план подписки");

                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                    return Unauthorized("Не удалось определить идентификатор пользователя");

                var user = await _userManager.FindByIdAsync(userId);
                if (user == null)
                    return Unauthorized("Пользователь в базе не найден");

                // Получаем EF-план
                var planEntity = await _context.SubscriptionPlans
                    .FirstOrDefaultAsync(p => p.Id == request.SubscriptionPlanId && p.IsActive);
                if (planEntity == null)
                    return BadRequest("Невалидный или неактивный план подписки");

                // 1) Создаём новую подписку (DTO)
                var newSubDto = await _subscriptionService.CreateSubscriptionAsync(user, planEntity, request.AutoRenew);

                // 2) Создаём платёж
                var (paymentId, redirectUrl) = await _paymentService.CreatePaymentAsync(user, planEntity, request.AutoRenew);

                // 3) Запишем PaymentId
                newSubDto.PaymentId = paymentId;
                await _subscriptionService.UpdateSubscriptionAsync(newSubDto);

                // 4) Возвращаем redirectUrl
                return Ok(new { RedirectUrl = redirectUrl });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка создания платежа CreatePayment");
                // Отдаём статус 500 + человекочитаемое сообщение
                return StatusCode(500, $"Ошибка создания платежа CreatePayment: {ex.Message}");
            }
        }

        /// <summary>
        /// Webhook от ЮKassa
        /// </summary>
        [HttpPost("webhook")]
        [AllowAnonymous]
        public async Task<IActionResult> Webhook()
        {
            var (paymentId, isSucceeded, paymentMethodId) = await _paymentService.ProcessWebhookAsync(HttpContext.Request);
            if (!string.IsNullOrEmpty(paymentId))
            {
                if (isSucceeded)
                {
                    // Успешная оплата
                    await _subscriptionService.ActivateSubscriptionAsync(paymentId, paymentMethodId);
                }
                else
                {
                    // Неуспешная (или отменённая) оплата — отменяем подписку
                    await _subscriptionService.CancelSubscriptionAsync(paymentId);
                }
            }
            return Ok(); // Подтверждаем получение
        }



        /// <summary>
        /// Вернуть DTO всех подписок текущего пользователя
        /// </summary>
        [HttpGet("my-subscriptions")]
        public async Task<IActionResult> GetMySubscriptions()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null)
                return Unauthorized();

            var subsDto = await _subscriptionService.GetUserSubscriptionsAsync(user.Id);
            return Ok(subsDto);
        }

        /// <summary>
        /// Проверить статус подписки текущего пользователя и вернуть подробную информацию
        /// </summary>
        [HttpGet("check-status")]
        public async Task<IActionResult> CheckSubscriptionStatus()
        {
            try
            {
                var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                    return Unauthorized("Не удалось определить идентификатор пользователя");

                var user = await _userManager.FindByIdAsync(userId);
                if (user == null)
                    return Unauthorized("Пользователь в базе не найден");

                // Получаем активную подписку пользователя
                var activeSubscription = await _subscriptionService.GetActiveSubscriptionForUser(userId);
                
                // Проверяем, соответствует ли флаг hasSubscription наличию активной подписки
                bool hasActiveSubscription = activeSubscription != null;
                bool flagMatchesSubscription = user.HasSubscription == hasActiveSubscription;
                
                // Если флаг не соответствует фактическому наличию подписки, исправляем
                if (!flagMatchesSubscription)
                {
                    _logger.LogWarning("Несоответствие флага HasSubscription для пользователя {UserId}: " +
                                      "HasSubscription={HasSubscription}, но активная подписка {HasActiveSubscription}", 
                                      userId, user.HasSubscription, hasActiveSubscription ? "существует" : "отсутствует");
                    
                    // Обновляем флаг пользователя
                    user.HasSubscription = hasActiveSubscription;
                    await _userManager.UpdateAsync(user);
                    
                    _logger.LogInformation("Флаг HasSubscription для пользователя {UserId} исправлен на {Value}", 
                                          userId, hasActiveSubscription);
                }
                
                // Переменная для отслеживания изменений в подписке
                bool subscriptionUpdated = false;
                
                // Проверяем, есть ли у нас активная подписка, которая требует корректировки
                if (activeSubscription != null && !activeSubscription.IsActive && activeSubscription.EndDate > DateTime.UtcNow)
                {
                    _logger.LogWarning("Найдена подписка для пользователя {UserId} с неактивным статусом, но сроком действия в будущем", userId);
                    
                    // Получаем подписку из контекста для обновления
                    var subscriptionToUpdate = await _context.Subscriptions
                        .FirstOrDefaultAsync(s => s.Id == activeSubscription.Id);
                        
                    if (subscriptionToUpdate != null)
                    {
                        // Исправляем флаг IsActive
                        subscriptionToUpdate.IsActive = true;
                        await _context.SaveChangesAsync();
                        
                        // Отмечаем, что была выполнена коррекция подписки
                        subscriptionUpdated = true;
                        
                        _logger.LogInformation("Статус подписки {SubscriptionId} скорректирован на активный", subscriptionToUpdate.Id);
                        
                        // После исправления флага, обновляем данные об активной подписке
                        activeSubscription = await _subscriptionService.GetActiveSubscriptionForUser(userId);
                    }
                }
                
                // Формируем ответ с подробной информацией
                var subscriptionStatus = new
                {
                    HasSubscription = user.HasSubscription,
                    ActiveSubscription = activeSubscription,
                    Now = DateTime.UtcNow,
                    FlagCorrected = !flagMatchesSubscription || subscriptionUpdated,
                    // Добавляем дополнительные данные для диагностики
                    DiagnosticInfo = new
                    {
                        UserId = userId,
                        HasSubscriptionFlagInUserEntity = user.HasSubscription,
                        HasActiveSubscriptionInDatabase = hasActiveSubscription,
                        SubscriptionWasUpdated = subscriptionUpdated,
                        UserFlagWasUpdated = !flagMatchesSubscription
                    }
                };
                
                return Ok(subscriptionStatus);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при проверке статуса подписки");
                return StatusCode(500, "Произошла ошибка при проверке статуса подписки");
            }
        }
    }

    public class CreatePaymentRequest
    {
        public int SubscriptionPlanId { get; set; }
        public bool AutoRenew { get; set; }
    }
}
