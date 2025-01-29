using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using RareBooksService.WebApi.Services;
using System;
using System.IO;
using System.Security.Claims;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SubscriptionController : BaseController
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IYandexKassaPaymentService _paymentService;
        private readonly ISubscriptionService _subscriptionService;

        public SubscriptionController(
            UserManager<ApplicationUser> userManager,
            IYandexKassaPaymentService paymentService,
            ISubscriptionService subscriptionService) : base(userManager) 
        {
            _userManager = userManager;
            _paymentService = paymentService;
            _subscriptionService = subscriptionService;
        }

        /// <summary>
        /// Получить список доступных планов
        /// </summary>
        [HttpGet("plans")]
        [AllowAnonymous] // Если хотите отдавать список планов без авторизации
        public async Task<IActionResult> GetPlans()
        {
            var plans = await _subscriptionService.GetActiveSubscriptionPlansAsync();
            return Ok(plans);
        }

        /// <summary>
        /// Создаёт оплату. Пользователь выбирает какой-то planId и autoRenew, 
        /// мы создаём Subscription (пока не активную) и создаём платёж в ЮKassa.
        /// </summary>
        [HttpPost("create-payment")]
        public async Task<IActionResult> CreatePayment([FromBody] CreatePaymentRequest request)
        {
            if (request == null || request.SubscriptionPlanId <= 0)
                return BadRequest("Не указан план подписки");

            // 1) Считываем userId из ClaimTypes.NameIdentifier
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized("Не удалось определить идентификатор пользователя из JWT");

            // 2) Ищем пользователя в бД
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return Unauthorized("Пользователь в базе не найден");

            // 3) Получаем план
            var plan = await _subscriptionService.GetPlanByIdAsync(request.SubscriptionPlanId);
            if (plan == null)
                return BadRequest("Невалидный или неактивный план подписки");

            // 4) Создаём запись Subscription в БД
            var newSubscription = await _subscriptionService.CreateSubscriptionAsync(user, plan, request.AutoRenew);

            // 5) Создаём платёж в ЮKassa
            var (paymentId, redirectUrl) = await _paymentService.CreatePaymentAsync(user, plan, request.AutoRenew);

            // 6) Запишем PaymentId в нашу Subscription
            newSubscription.PaymentId = paymentId;
            await _subscriptionService.UpdateSubscriptionAsync(newSubscription);

            // 7) Возвращаем redirectUrl
            return Ok(new { RedirectUrl = redirectUrl });
        }


        /// <summary>
        /// Webhook endpoint, куда ЮKassa будет отправлять уведомления об оплате.
        /// </summary>
        [HttpPost("webhook")]
        [AllowAnonymous] // ЮKassa не авторизуется вашим токеном
        public async Task<IActionResult> Webhook()
        {
            var (paymentId, isSucceeded) = await _paymentService.ProcessWebhookAsync(HttpContext.Request);

            if (!string.IsNullOrEmpty(paymentId) && isSucceeded)
            {
                // Активация подписки:
                await _subscriptionService.ActivateSubscriptionAsync(paymentId);
            }

            return Ok(); // 200
        }

        // Дополнительный метод: Получить подписки пользователя
        [HttpGet("my-subscriptions")]
        public async Task<IActionResult> GetMySubscriptions()
        {
            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized();

            var subs = await _subscriptionService.GetUserSubscriptionsAsync(user.Id);
            return Ok(subs);
        }
    }

    /// <summary>
    /// DTO для запроса на создание платежа
    /// </summary>
    public class CreatePaymentRequest
    {
        public int SubscriptionPlanId { get; set; }
        public bool AutoRenew { get; set; }
    }
}
