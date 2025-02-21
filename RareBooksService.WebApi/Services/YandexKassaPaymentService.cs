using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Settings;
using System.Net;
using System.Text.Json;
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
        Task<(string? paymentId, bool isSucceeded)> ProcessWebhookAsync(HttpRequest request);
    }

    public class YandexKassaPaymentService : IYandexKassaPaymentService
    {
        private readonly string _shopId;
        private readonly string _secretKey;
        private readonly string _returnUrl;
        private readonly Client _client; // Синхронный, можем сделать asyncClient
        private readonly ILogger<YandexKassaPaymentService> _logger;

        public YandexKassaPaymentService(IOptions<YandexKassaSettings> options, ILogger<YandexKassaPaymentService> logger)
        {
            var settings = options.Value;
            _shopId = settings.ShopId;
            _secretKey = settings.SecretKey;
            _returnUrl = settings.ReturnUrl;

            // создаём клиент
            _client = new Client(_shopId, _secretKey);
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            _logger = logger;
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

        /*public async Task<(string PaymentId, bool IsPaymentSucceeded)> ProcessWebhookAsync(HttpRequest request)
        {
            // Включаем буферизацию, чтобы была возможность заново прочитать поток
            request.EnableBuffering();

            Notification notification = null;
            try
            {
                // Создаём MemoryStream и копируем туда тело запроса
                using var memoryStream = new MemoryStream();
                await request.Body.CopyToAsync(memoryStream);

                // «Перематываем» на начало
                memoryStream.Position = 0;

                // Вызываем парсинг
                notification = Client.ParseMessage(
                    request.Method,
                    request.ContentType,
                    memoryStream
                );
            }
            catch (Exception ex)
            {
                // Если данные были некорректны — просто возвращаем признак ошибки
                // Либо можно залогировать ex
                return (null, false);
            }
            finally
            {
                // Возвращаем Position к нулю, чтобы тело запроса можно было прочесть снова, если потребуется
                request.Body.Position = 0;
            }

            // Если мы тут — значит notification успешно распарсился
            if (notification is PaymentSucceededNotification succeeded)
            {
                var payment = succeeded.Object;
                return (payment.Id, true);
            }
            else if (notification is PaymentWaitingForCaptureNotification waitingForCapture)
            {
                var payment = waitingForCapture.Object;
                // ...
                return (payment.Id, false);
            }
            else if (notification is PaymentCanceledNotification canceled)
            {
                // Если нужно обрабатывать отмену
                var payment = canceled.Object;
                return (payment.Id, false);
            }

            // На всякий случай: если пришел неизвестный тип нотификации — возвращаем (null, false)
            return (null, false);
        }*/

        public async Task<(string? paymentId, bool isSucceeded)> ProcessWebhookAsync(HttpRequest request)
        {
            try
            {
                // 1. Считать тело запроса
                request.Body.Position = 0; // на всякий случай
                using var reader = new StreamReader(request.Body);
                var body = await reader.ReadToEndAsync();

                _logger.LogInformation("Webhook received: {Body}", body);

                // 2. (Опционально) Проверить IP-адрес, если хотите фильтровать запросы
                var remoteIp = request.HttpContext.Connection.RemoteIpAddress;
                if (!IsIpFromYooKassa(remoteIp))
                {
                    _logger.LogWarning("Webhook from unknown IP {IP}. Potentially not from YandexKassa.", remoteIp);
                    // Решайте сами: либо возвращать ошибку, либо продолжить
                    // return (null, false);
                }

                // 3. Разобрать JSON
                // Структура:
                // {
                //   "event": "payment.succeeded",
                //   "type": "notification",
                //   "object": { ... информация о платеже ... }
                // }
                using var doc = JsonDocument.Parse(body);
                var root = doc.RootElement;
                if (!root.TryGetProperty("event", out var eventProp))
                {
                    _logger.LogError("No 'event' property in webhook JSON");
                    return (null, false);
                }
                var eventName = eventProp.GetString();

                if (!root.TryGetProperty("object", out var objectProp))
                {
                    _logger.LogError("No 'object' property in webhook JSON");
                    return (null, false);
                }

                // Для платежей "object.id" = paymentId
                if (!objectProp.TryGetProperty("id", out var idProp))
                {
                    _logger.LogError("No 'object.id' property in webhook JSON");
                    return (null, false);
                }
                var paymentId = idProp.GetString();

                // 4. Логика в зависимости от события
                //    (Можно смотреть ещё на status в objectProp)
                if (eventName == "payment.succeeded")
                {
                    // Можно считать PaymentStatus= "succeeded"
                    // Возвращаем флажок isSucceeded = true
                    _logger.LogInformation("Payment {PaymentId} succeeded", paymentId);
                    return (paymentId, true);
                }
                else if (eventName == "payment.canceled")
                {
                    _logger.LogInformation("Payment {PaymentId} canceled", paymentId);
                    // Можете здесь же вызвать свой код, который отменяет подписку
                    return (paymentId, false);
                }
                else if (eventName == "payment.waiting_for_capture")
                {
                    // Если вы используете флоу с capture, нужно вызвать метод capture
                    // PaymentId можно сохранить, потом отдельным методом.
                    _logger.LogInformation("Payment {PaymentId} waiting for capture", paymentId);
                    // Возвращать (paymentId, false) или как-то иначе.
                    // Можете вручную вызвать API capture, если нужно.
                    return (paymentId, false);
                }
                else
                {
                    _logger.LogInformation("Ignored event {EventName} for payment {PaymentId}", eventName, paymentId);
                    return (paymentId, false);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing webhook");
                return (null, false);
            }
        }

        private bool IsIpFromYooKassa(IPAddress? ip)
        {
            if (ip == null) return false;

            // Документация: https://yookassa.ru/developers/using-api/webhooks
            // Список подсетей ЮKassa:
            // 185.71.76.0/27
            // 185.71.77.0/27
            // 77.75.153.0/25
            // 77.75.156.11
            // 77.75.156.35
            // 77.75.154.128/25
            // 2a02:5180::/32
            // Реализовать полноценную проверку IP → вхождение в подсети.
            // Либо используем готовую библиотеку для проверки вхождения IP в CIDR.
            // Ниже – условный пример (неполнокорректный), он требует доработки.

            string[] ykassaRanges = {
                "185.71.76.0/27",
                "185.71.77.0/27",
                "77.75.153.0/25",
                "77.75.156.11/32",
                "77.75.156.35/32",
                "77.75.154.128/25",
                "2a02:5180::/32" // IPv6
            };

            // Тут нужно написать код, который проверяет, входит ли ip в один из указанных диапазонов.
            // Если нет, возвращаем false.
            // Для примера – упрощённый подход без реальных проверок:
            // return true; 
            // С реальным кодом проверки подсетей можно посмотреть библиотеки типа "IPNetwork" etc.

            return true; // Пока пропускаем все (но логируем).
        }

    }

}
