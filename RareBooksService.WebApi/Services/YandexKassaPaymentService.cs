using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Settings;
using System.Net;
using System.Numerics;
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
        Task<(string? paymentId, bool isSucceeded, string? paymentMethodId)> ProcessWebhookAsync(HttpRequest request);
    }

    public class YandexKassaPaymentService : IYandexKassaPaymentService
    {
        private readonly IOptionsSnapshot<YandexKassaSettings> _options;
        private Client? _client; // ленивое создание клиента
        private readonly ILogger<YandexKassaPaymentService> _logger;

        public YandexKassaPaymentService(IOptionsSnapshot<YandexKassaSettings> options, ILogger<YandexKassaPaymentService> logger)
        {
            _options = options;
            _client = null;
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            _logger = logger;
        }

        public async Task<(string PaymentId, string ConfirmationUrl)> CreatePaymentAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew)
        {
            var settings = _options.Value;

            // Проверяем, что настройки заданы
            if (string.IsNullOrWhiteSpace(settings.ShopId) || string.IsNullOrWhiteSpace(settings.SecretKey) || string.IsNullOrWhiteSpace(settings.ReturnUrl))
            {
                throw new InvalidOperationException("Параметры YandexKassa (ShopId/SecretKey/ReturnUrl) не настроены.");
            }

            // Лениво создаём клиента (или пересоздаём, если настройки изменились)
            if (_client == null || _client.ShopId != settings.ShopId)
            {
                _client = new Client(settings.ShopId, settings.SecretKey);
            }

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
                    ReturnUrl = settings.ReturnUrl // Вернёт после оплаты
                },
                Capture = true, // Сразу захватываем платеж
                Description = $"Оплата подписки: {plan.Name}. Пользователь {user.Email}",
                Metadata = new Dictionary<string, string>
                {
                    { "userId", user.Id },
                    { "planId", plan.Id.ToString() },
                    { "autoRenew", autoRenew.ToString() }
                },
                // Сохранение данных для автоматической оплаты не работает
                /*PaymentMethodData = new PaymentMethod
                {
                    Type = PaymentMethodType.BankCard
                },
                SavePaymentMethod = true*/

            };

            try
            {
                var payment = await asyncClient.CreatePaymentAsync(newPayment);
                return (payment.Id, payment.Confirmation.ConfirmationUrl);
            }
            catch (YandexCheckoutException ex)
            {
                // Перехватываем конкретную ошибку и логируем
                _logger.LogError(ex, "Error from YandexKassa while creating payment.");

                // Пробрасываем дальше или возвращаем человекочитаемый текст
                // Можно выкинуть Exception, который потом в контроллере 
                // переведём в return StatusCode(500, ex.Message) или что-то подобное
                throw new InvalidOperationException("Ошибка при создании платежа: " + ex.Message, ex);
            }
        }
        public async Task<(string? paymentId, bool isSucceeded, string? paymentMethodId)> ProcessWebhookAsync(HttpRequest request)
        {
            try
            {
                request.EnableBuffering();
                request.Body.Position = 0;

                using var reader = new StreamReader(request.Body, leaveOpen: true);
                var body = await reader.ReadToEndAsync();
                _logger.LogInformation("Webhook received: {Body}", body);

                request.Body.Position = 0;

                var remoteIp = request.HttpContext.Connection.RemoteIpAddress;
                if (!IsIpFromYooKassa(remoteIp))
                {
                    _logger.LogWarning("Webhook from unknown IP {IP}. Potentially not from YandexKassa.", remoteIp);
                    // Здесь можно прервать обработку
                }

                using var doc = JsonDocument.Parse(body);
                var root = doc.RootElement;

                if (!root.TryGetProperty("event", out var eventProp))
                {
                    _logger.LogError("No 'event' property in webhook JSON");
                    return (null, false, null);
                }
                var eventName = eventProp.GetString();

                if (!root.TryGetProperty("object", out var objectProp))
                {
                    _logger.LogError("No 'object' property in webhook JSON");
                    return (null, false, null);
                }

                if (!objectProp.TryGetProperty("id", out var idProp))
                {
                    _logger.LogError("No 'object.id' property in webhook JSON");
                    return (null, false, null);
                }
                var paymentId = idProp.GetString();

                switch (eventName)
                {
                    case "payment.succeeded":
                        _logger.LogInformation("Payment {PaymentId} succeeded", paymentId);

                        // Пытаемся вытащить payment_method -> id
                        // "object": { "payment_method": { "type":"bank_card", "id":"XYZ", ... } }
                        string? paymentMethodId = null;
                        if (objectProp.TryGetProperty("payment_method", out var pmElem) &&
                            pmElem.TryGetProperty("id", out var pmIdElem))
                        {
                            paymentMethodId = pmIdElem.GetString();
                        }

                        return (paymentId, true, paymentMethodId);

                    case "payment.canceled":
                        _logger.LogInformation("Payment {PaymentId} canceled", paymentId);
                        return (paymentId, false, null);

                    case "payment.waiting_for_capture":
                        _logger.LogInformation("Payment {PaymentId} waiting for capture", paymentId);
                        return (paymentId, false, null);

                    default:
                        _logger.LogInformation("Ignored event {EventName} for payment {PaymentId}", eventName, paymentId);
                        return (paymentId, false, null);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing webhook");
                return (null, false, null);
            }
        }



        private bool IsIpFromYooKassa(IPAddress? ip)
        {
            if (ip == null) return false;

            // Список подсетей/адресов ЮKassa из документации:
            // https://yookassa.ru/developers/using-api/webhooks#podtverzhdenie-autentichnosti-uvedomleniy
            // Обратите внимание, что некоторые адреса указаны без CIDR, значит /32 для IPv4, /128 для IPv6
            // (либо нужно дописать вручную нужные маски).
            var ykassaCIDRs = new (string Cidr, IPAddress Network, int Prefix)[]
            {
                ("185.71.76.0/27",   IPAddress.Parse("185.71.76.0"),   27),
                ("185.71.77.0/27",   IPAddress.Parse("185.71.77.0"),   27),
                ("77.75.153.0/25",   IPAddress.Parse("77.75.153.0"),   25),
                ("77.75.156.11/32",  IPAddress.Parse("77.75.156.11"),  32),
                ("77.75.156.35/32",  IPAddress.Parse("77.75.156.35"),  32),
                ("77.75.154.128/25", IPAddress.Parse("77.75.154.128"), 25),
                ("2a02:5180::/32",   IPAddress.Parse("2a02:5180::"),   32)
            };

            // Проверяем, что IP (ip) принадлежит хотя бы одной из указанных подсетей.
            foreach (var (cidrString, networkAddress, prefixLength) in ykassaCIDRs)
            {
                if (IsInCidrRange(ip, networkAddress, prefixLength))
                {
                    // Если IP вошёл хотя бы в одну подсеть, значит он «белый».
                    return true;
                }
            }

            // Если не подошёл ни один диапазон
            return false;
        }

        /// <summary>
        /// Проверяет, что ip лежит в сети network/prefixLength.
        /// Поддерживаются и IPv4, и IPv6.
        /// </summary>
        private bool IsInCidrRange(IPAddress ip, IPAddress network, int prefixLength)
        {
            // Если версии IP (IPv4 vs IPv6) не совпадают — точно не в диапазоне
            if (ip.AddressFamily != network.AddressFamily)
                return false;

            // Получаем байты IP‑адресов
            byte[] ipBytes = ip.GetAddressBytes();
            byte[] networkBytes = network.GetAddressBytes();

            // Для IPv4 делаем проверку через 32-битное представление
            // Для IPv6 — через 128-битное (BigInteger)
            if (ip.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork) // IPv4
            {
                // Конвертируем в 32-битное целое
                uint ipValue = BitConverter.ToUInt32(ipBytes.Reverse().ToArray(), 0);
                uint networkValue = BitConverter.ToUInt32(networkBytes.Reverse().ToArray(), 0);

                // Считаем маску (количество старших бит = prefixLength)
                // Например, если prefixLength = 27, маска будет 0xFFFFFFE0
                uint mask = prefixLength == 0 ? 0 : uint.MaxValue << (32 - prefixLength);

                // Сравниваем: (ip & mask) == (network & mask)
                return (ipValue & mask) == (networkValue & mask);
            }
            else // IPv6
            {
                // Преобразуем в BigInteger (байты разворачиваем в обратном порядке, т.к. в BitConverter
                // младший байт идёт первым, а в BigInteger — наоборот)
                BigInteger ipValue = new BigInteger(ipBytes.Reverse().ToArray());
                BigInteger networkValue = new BigInteger(networkBytes.Reverse().ToArray());

                // Аналогично IPv4: для 128 бит вычисляем маску
                // prefixLength может быть 0..128
                // Маску удобнее всего получить как ( (1 << prefixLength) - 1 ) << (128 - prefixLength)
                // Но поскольку это BigInteger, используем побитовые операции.
                BigInteger mask = MaskForIPv6(prefixLength);

                return (ipValue & mask) == (networkValue & mask);
            }
        }

        /// <summary>
        /// Возвращает BigInteger‑маску для IPv6 при заданном prefixLength (0..128).
        /// Пример: если prefixLength=32, старшие 32 бита = 1, остальные 96 – 0.
        /// </summary>
        private BigInteger MaskForIPv6(int prefixLength)
        {
            // Если префикс 0, значит маска = 0
            if (prefixLength == 0)
                return BigInteger.Zero;

            // 128‑битное число, у которого prefixLength старших бит = 1, остальные = 0
            // Формируем так:
            //   (1 << prefixLength) - 1  даёт число с prefixLength младшими битами = 1
            //   Нужно это сместить влево на (128 - prefixLength), чтобы 1-биты стали «старшими»
            // Но для BigInteger используем битовые операции.
            BigInteger allOnes = (BigInteger.One << prefixLength) - 1; // prefixLength младших бит = 1
            return allOnes << (128 - prefixLength);
        }

    }

}
