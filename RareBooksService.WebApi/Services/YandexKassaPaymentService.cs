using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using System.Net;
using Yandex.Checkout.V3;

namespace RareBooksService.WebApi.Services
{
    public interface IYandexKassaPaymentService
    {
        /// <summary>
        /// Создаёт платёж в ЮKassa для указанного пользователя и выбранного плана.
        /// Возвращает сущность Payment или данные о RedirectUrl и PaymentId.
        /// </summary>
        Task<(string PaymentId, string ConfirmationUrl)> CreatePaymentAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew);

        /// <summary>
        /// Обработка входящего уведомления (webhook) от ЮKassa.
        /// Возвращает Id платежа (payment.Id) и флаг успеха.
        /// </summary>
        Task<(string PaymentId, bool IsPaymentSucceeded)> ProcessWebhookAsync(HttpRequest request);
    }

    public class YandexKassaPaymentService : IYandexKassaPaymentService
    {
        private readonly string _shopId;
        private readonly string _secretKey;
        private readonly string _returnUrl;
        private readonly Client _client; // Синхронный, можем сделать asyncClient

        public YandexKassaPaymentService(IOptions<YandexKassaSettings> options)
        {
            var settings = options.Value;
            _shopId = settings.ShopId;
            _secretKey = settings.SecretKey;
            _returnUrl = settings.ReturnUrl;

            // создаём клиент
            _client = new Client(_shopId, _secretKey);
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
        }

        public async Task<(string PaymentId, string ConfirmationUrl)> CreatePaymentAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew)
        {
            // Используем асинхронный клиент
            var asyncClient = _client.MakeAsync();

            var newPayment = new NewPayment
            {
                Amount = new Amount
                {
                    Value = plan.Price,   // Цена из плана
                    Currency = "RUB"
                },
                Confirmation = new Confirmation
                {
                    Type = ConfirmationType.Redirect,
                    ReturnUrl = _returnUrl // Вернёт после оплаты
                },
                Capture = true, // Сразу захватываем платеж
                Description = $"Оплата подписки: {plan.Name}. Пользователь {user.Email}",
                Metadata = new Dictionary<string, string>
                {
                    { "userId", user.Id },
                    { "planId", plan.Id.ToString() },
                    { "autoRenew", autoRenew.ToString() }
                }
            };

            var payment = await asyncClient.CreatePaymentAsync(newPayment);
            return (payment.Id, payment.Confirmation.ConfirmationUrl);
        }

        public async Task<(string PaymentId, bool IsPaymentSucceeded)> ProcessWebhookAsync(HttpRequest request)
        {
            // Внимание! По документации:
            //   var notification = Client.ParseMessage(HttpMethod, ContentType, InputStream)
            // Но вы используете ASP.NET Core: нужно «прокрутить» тело запроса:
            request.Body.Position = 0;
            var notification = Client.ParseMessage(
                request.Method,
                request.ContentType,
                request.Body
            );

            if (notification is PaymentSucceededNotification succeeded)
            {
                var payment = succeeded.Object;
                return (payment.Id, true);
            }
            else if (notification is PaymentWaitingForCaptureNotification waitingForCapture)
            {
                var payment = waitingForCapture.Object;
                // Если нужно — можем вызвать Capture
                // ...
                return (payment.Id, false); // waiting, ещё не paid
            }
            // Можно добавить другие случаи (PaymentCanceledNotification, etc.)

            return (null, false);
        }
    }

}
