using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using System.IO;
using System.Threading.Tasks;
using Yandex.Checkout.V3;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SubscriptionController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly YandexKassaSettings _yandexKassaSettings;
        private readonly Client _client;

        public SubscriptionController(UserManager<ApplicationUser> userManager, IOptions<YandexKassaSettings> yandexKassaSettings)
        {
            _userManager = userManager;
            _yandexKassaSettings = yandexKassaSettings.Value;
            _client = new Client(_yandexKassaSettings.ShopId, _yandexKassaSettings.SecretKey);
        }

        [HttpPost("create-payment")]
        public async Task<IActionResult> CreatePayment()
        {
            var user = await _userManager.GetUserAsync(User);

            var asyncClient = _client.MakeAsync();

            var newPayment = new NewPayment
            {
                Amount = new Amount { Value = 1000.00m, Currency = "RUB" },
                Confirmation = new Confirmation
                {
                    Type = ConfirmationType.Redirect,
                    ReturnUrl = _yandexKassaSettings.ReturnUrl
                },
                Capture = true,
                Description = "Подписка на Rare Books Service",
                Metadata = new Dictionary<string, string>
                {
                    { "userId", user.Id }
                }
            };

            var payment = await asyncClient.CreatePaymentAsync(newPayment);

            return Ok(new { PaymentId = payment.Id, RedirectUrl = payment.Confirmation.ConfirmationUrl });
        }

        [HttpPost("webhook")]
        [AllowAnonymous]
        public async Task<IActionResult> Webhook()
        {
            var json = await new StreamReader(HttpContext.Request.Body).ReadToEndAsync();
            var notification = Client.ParseMessage(HttpContext.Request.Method, HttpContext.Request.ContentType, HttpContext.Request.Body);

            if (notification is PaymentSucceededNotification paymentSucceededNotification)
            {
                var payment = paymentSucceededNotification.Object;
                var userId = payment.Metadata["userId"]; // Используйте метаданные для получения информации о пользователе

                var user = await _userManager.FindByIdAsync(userId);
                if (user != null)
                {
                    user.HasSubscription = true;
                    await _userManager.UpdateAsync(user);
                }
            }

            return Ok();
        }
    }
}
