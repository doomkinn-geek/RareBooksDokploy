using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Common.Models.Dto.RareBooksService.Common.Models.Dto;
using RareBooksService.Common.Models.Settings;
using RareBooksService.Data;
using System.Net;
using Yandex.Checkout.V3;

namespace RareBooksService.WebApi.Services
{
    public interface ISubscriptionService
    {
        Task<SubscriptionDto> CreateSubscriptionAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew);
        Task ActivateSubscriptionAsync(string paymentId, string? paymentMethodId);
        Task<List<SubscriptionPlanDto>> GetActiveSubscriptionPlansAsync();
        Task<SubscriptionPlanDto?> GetPlanByIdAsync(int planId);

        Task<List<SubscriptionDto>> GetUserSubscriptionsAsync(string userId);
        Task UpdateSubscriptionAsync(SubscriptionDto subscriptionDto);
        Task<SubscriptionDto?> GetActiveSubscriptionForUser(string userId);

        Task<bool> AssignSubscriptionPlanAsync(string userId, int planId, bool autoRenew);
        Task<bool> DisableSubscriptionAsync(string userId);
        Task<bool> TryAutoRenewSubscriptionAsync(int subscriptionId);

        Task CancelSubscriptionAsync(string paymentId);
    }

    public class SubscriptionService : ISubscriptionService
    {
        private readonly UsersDbContext _db;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ILogger<SubscriptionService> _logger;
        private readonly Client _yooKassaClient;

        public SubscriptionService(UsersDbContext db, 
            UserManager<ApplicationUser> userManager, 
            ILogger<SubscriptionService> logger,
            IOptions<YandexKassaSettings> ykSettings)
        {
            _db = db;
            _userManager = userManager;
            _logger = logger;

            try
            {
                // Инициализируем клиента
                var settings = ykSettings.Value;
                _yooKassaClient = new Client(settings.ShopId, settings.SecretKey);
                ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            }
            catch (Exception ex)
            {
                return;
            }
        }

        public async Task<SubscriptionDto> CreateSubscriptionAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew)
        {
            // Отключаем старые активные
            var oldSubs = await _db.Subscriptions
                .Where(s => s.UserId == user.Id && s.IsActive)
                .ToListAsync();
            foreach (var old in oldSubs)
                old.IsActive = false;

            // Создаём новую
            var newSub = new Subscription
            {
                UserId = user.Id,
                SubscriptionPlanId = plan.Id,
                StartDate = DateTime.UtcNow,
                EndDate = DateTime.UtcNow.AddMonths(1),
                IsActive = false,
                AutoRenew = autoRenew,
                PaymentId = null,
                PriceAtPurchase = plan.Price
            };
            _db.Subscriptions.Add(newSub);

            // user.HasSubscription = false (до оплаты)
            user.HasSubscription = false;
            await _db.SaveChangesAsync();

            return ToDto(newSub, plan);
        }

        public async Task ActivateSubscriptionAsync(string paymentId, string? paymentMethodId)
        {
            var sub = await _db.Subscriptions
                .Where(s => s.PaymentId == paymentId)
                .Include(s => s.User)
                .FirstOrDefaultAsync();

            if (sub == null) return;

            // Делаем активной
            sub.IsActive = true;
            sub.UsedRequestsThisPeriod = 0;
            sub.User.HasSubscription = true;

            // Если передан PaymentMethodId, сохраняем
            if (!string.IsNullOrEmpty(paymentMethodId))
            {
                sub.PaymentMethodId = paymentMethodId;
            }

            // Отключаем все остальные подписки пользователя (если бизнес-логика требует)
            var others = await _db.Subscriptions
                .Where(s => s.UserId == sub.UserId && s.Id != sub.Id && s.IsActive)
                .ToListAsync();
            foreach (var other in others)
                other.IsActive = false;

            await _db.SaveChangesAsync();
        }

        public async Task<bool> TryAutoRenewSubscriptionAsync(int subscriptionId)
        {
            var sub = await _db.Subscriptions
                .Include(s => s.User)
                .Include(s => s.SubscriptionPlan)
                .FirstOrDefaultAsync(s => s.Id == subscriptionId);

            if (sub == null || !sub.IsActive || !sub.AutoRenew)
                return false;

            if (string.IsNullOrEmpty(sub.PaymentMethodId))
                return false; // нечего списывать, нет сохранённой карты

            var plan = sub.SubscriptionPlan;
            var user = sub.User;

            // Делаем асинхронный клиент
            var asyncClient = _yooKassaClient.MakeAsync();

            // Формируем запрос
            var newPayment = new NewPayment
            {
                Amount = new Amount
                {
                    Value = plan.Price,
                    Currency = "RUB"
                },
                PaymentMethodId = sub.PaymentMethodId,
                Capture = true,
                Description = $"Автопродление подписки: {plan.Name} для {user.Email}",
                Metadata = new Dictionary<string, string>
                {
                    { "userId", user.Id },
                    { "planId", plan.Id.ToString() },
                    { "autoRenew", "true" },
                    { "renewForSubId", sub.Id.ToString() }
                }
            };

            try
            {
                var payment = await asyncClient.CreatePaymentAsync(newPayment);

                if (payment.Status == PaymentStatus.Succeeded)
                {
                    // Успешно списали — продлеваем
                    sub.EndDate = sub.EndDate < DateTime.UtcNow
                        ? DateTime.UtcNow.AddMonths(1)
                        : sub.EndDate.AddMonths(1);

                    sub.IsActive = true;
                    await _db.SaveChangesAsync();
                    return true;
                }
                else
                {
                    // Платёж не прошёл
                    sub.IsActive = false;
                    sub.User.HasSubscription = false;
                    await _db.SaveChangesAsync();

                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "AutoRenew: ошибка при создании платежа");
                return false;
            }
        }



        public async Task<List<SubscriptionPlanDto>> GetActiveSubscriptionPlansAsync()
        {
            try
            {
                _logger.LogInformation("Начинаем выборку активных планов подписки из базы...");

                var plans = await _db.SubscriptionPlans
                    .Where(p => p.IsActive)
                    .ToListAsync();

                _logger.LogInformation("Активные планы подписки выбраны: {Count} шт.", plans.Count);

                // Преобразование в DTO
                var result = plans.Select(ToDto).ToList();
                _logger.LogInformation("Сформирован список DTO планов подписки: {Count} шт.", result.Count);

                return result;
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Ошибка в GetActiveSubscriptionPlansAsync при выборке планов из БД");
                // Обязательно пробрасываем исключение выше, чтобы контроллер мог отреагировать
                throw;
            }
        }


        public async Task<SubscriptionPlanDto?> GetPlanByIdAsync(int planId)
        {
            var plan = await _db.SubscriptionPlans
                .Where(p => p.IsActive && p.Id == planId)
                .FirstOrDefaultAsync();
            return plan == null ? null : ToDto(plan);
        }

        public async Task<List<SubscriptionDto>> GetUserSubscriptionsAsync(string userId)
        {
            var subs = await _db.Subscriptions
                .Include(s => s.SubscriptionPlan)
                .Where(s => s.UserId == userId)
                .OrderByDescending(s => s.StartDate)
                .ToListAsync();

            return subs.Select(s => ToDto(s, s.SubscriptionPlan)).ToList();
        }

        public async Task UpdateSubscriptionAsync(SubscriptionDto dto)
        {
            var entity = await _db.Subscriptions
                .FirstOrDefaultAsync(s => s.Id == dto.Id);
            if (entity == null) return;

            entity.SubscriptionPlanId = dto.SubscriptionPlanId;
            entity.AutoRenew = dto.AutoRenew;
            entity.IsActive = dto.IsActive;
            entity.StartDate = dto.StartDate;
            entity.EndDate = dto.EndDate;
            entity.PaymentId = dto.PaymentId;
            entity.UsedRequestsThisPeriod = dto.UsedRequestsThisPeriod;
            // PriceAtPurchase ? (при желании)

            _db.Subscriptions.Update(entity);
            await _db.SaveChangesAsync();
        }

        public async Task<SubscriptionDto?> GetActiveSubscriptionForUser(string userId)
        {
            var now = DateTime.UtcNow;
            var sub = await _db.Subscriptions
                .Include(s => s.SubscriptionPlan)
                .Where(s => s.UserId == userId && s.IsActive && s.EndDate > now)
                .OrderByDescending(s => s.StartDate)
                .FirstOrDefaultAsync();
            if (sub == null) return null;

            return ToDto(sub, sub.SubscriptionPlan);
        }

        public async Task<bool> AssignSubscriptionPlanAsync(string userId, int planId, bool autoRenew)
        {
            var user = await _db.Users
                .Include(u => u.Subscriptions)
                .FirstOrDefaultAsync(u => u.Id == userId);
            if (user == null) return false;

            var plan = await _db.SubscriptionPlans.FindAsync(planId);
            if (plan == null || !plan.IsActive)
                return false;

            // Отключаем старые
            var oldActive = user.Subscriptions.Where(s => s.IsActive).ToList();
            foreach (var oldSub in oldActive)
                oldSub.IsActive = false;

            // Создаём новую
            var newSub = new Subscription
            {
                UserId = user.Id,
                SubscriptionPlanId = plan.Id,
                StartDate = DateTime.UtcNow,
                EndDate = DateTime.UtcNow.AddMonths(1),
                IsActive = true,
                AutoRenew = autoRenew,
                PriceAtPurchase = plan.Price
            };
            _db.Subscriptions.Add(newSub);

            user.HasSubscription = true;

            await _db.SaveChangesAsync();
            return true;
        }

        public async Task<bool> DisableSubscriptionAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return false;

            var activeSubs = await _db.Subscriptions
                .Where(s => s.UserId == userId && s.IsActive)
                .ToListAsync();
            foreach (var sub in activeSubs)
                sub.IsActive = false;

            user.HasSubscription = false;
            await _db.SaveChangesAsync();

            return true;
        }

        public async Task CancelSubscriptionAsync(string paymentId)
        {
            // Ищем подписку по paymentId
            var sub = await _db.Subscriptions
                .Include(s => s.User)
                .FirstOrDefaultAsync(s => s.PaymentId == paymentId);

            if (sub == null)
            {
                _logger.LogWarning("CancelSubscriptionAsync: не найдена подписка для paymentId={PaymentId}", paymentId);
                return;
            }

            // Отключаем подписку
            sub.IsActive = false;
            sub.User.HasSubscription = false;
            // Если хотите явно зафиксировать дату окончания, можно:
            // sub.EndDate = DateTime.UtcNow; 

            await _db.SaveChangesAsync();
            _logger.LogInformation("Подписка {SubId} для пользователя {UserId} отменена (ошибка платежа)", sub.Id, sub.UserId);
        }


        // ---------------------------
        // PRIVATE MAPPERS
        // ---------------------------
        private SubscriptionDto ToDto(Subscription sub, SubscriptionPlan? planEntity)
        {
            return new SubscriptionDto
            {
                Id = sub.Id,
                SubscriptionPlanId = sub.SubscriptionPlanId,
                AutoRenew = sub.AutoRenew,
                IsActive = sub.IsActive,
                StartDate = sub.StartDate,
                EndDate = sub.EndDate,
                PaymentId = sub.PaymentId,
                PriceAtPurchase = sub.PriceAtPurchase,
                UsedRequestsThisPeriod = sub.UsedRequestsThisPeriod,
                SubscriptionPlan = planEntity == null ? null : ToDto(planEntity)
            };
        }

        private SubscriptionPlanDto ToDto(SubscriptionPlan plan)
        {
            return new SubscriptionPlanDto
            {
                Id = plan.Id,
                Name = plan.Name,
                Price = plan.Price,
                MonthlyRequestLimit = plan.MonthlyRequestLimit,
                IsActive = plan.IsActive
            };
        }
    }
}
