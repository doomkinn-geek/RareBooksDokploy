using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using RareBooksService.WebApi.Services;
using System;
using System.IO;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SubscriptionController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IYandexPaymentService _paymentService;
        private readonly ISubscriptionService _subscriptionService;

        public SubscriptionController(
            UserManager<ApplicationUser> userManager,
            IYandexPaymentService paymentService,
            ISubscriptionService subscriptionService)
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
            // Model binding request:
            //   {
            //      "subscriptionPlanId": ...,
            //      "autoRenew": true/false
            //   }

            if (request == null || request.SubscriptionPlanId <= 0)
                return BadRequest("Не указан план подписки");

            var user = await _userManager.GetUserAsync(User);
            if (user == null) return Unauthorized("Пользователь не найден");

            // Получаем план
            var plan = await _subscriptionService.GetPlanByIdAsync(request.SubscriptionPlanId);
            if (plan == null)
                return BadRequest("Невалидный или неактивный план подписки");

            // Создаём запись Subscription в БД
            var newSubscription = await _subscriptionService.CreateSubscriptionAsync(user, plan, request.AutoRenew);

            // Создаём платёж в ЮKassa
            var (paymentId, redirectUrl) = await _paymentService.CreatePaymentAsync(user, plan, request.AutoRenew);

            // Запишем PaymentId в нашу Subscription
            newSubscription.PaymentId = paymentId;
            await _subscriptionService.ActivateSubscriptionAsync(null); // только если нужно сбросить старую, но НЕ активируем!
            // Сохраним paymentId:
            // (Можно добавить метод в сервис подписок, но для примера тут)
            newSubscription.PaymentId = paymentId;
            await (/*_db.SaveChangesAsync() или subscriptionService что-то вроде UpdateSubscriptionAsync(...)*/Task.CompletedTask);

            // Возвращаем redirectUrl
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
