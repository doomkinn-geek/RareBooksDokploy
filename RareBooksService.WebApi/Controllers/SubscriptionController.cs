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

                return Ok(planDtos);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении планов подписки в методе GetPlans");
                // Отдаём статус 500 + человекочитаемое сообщение
                return StatusCode(500, "Внутренняя ошибка при получении планов подписки.");
            }
        }


        /// <summary>
        /// Создаёт оплату. Пользователь выбирает planId, autoRenew. 
        /// Создаем Subscription (не активную) + платёж в ЮKassa.
        /// </summary>
        [HttpPost("create-payment")]
        public async Task<IActionResult> CreatePayment([FromBody] CreatePaymentRequest request)
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
    }

    public class CreatePaymentRequest
    {
        public int SubscriptionPlanId { get; set; }
        public bool AutoRenew { get; set; }
    }
}
