using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using Yandex.Checkout.V3;

namespace RareBooksService.WebApi.Services
{
    public interface ISubscriptionService
    {
        Task<Subscription> CreateSubscriptionAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew);
        Task ActivateSubscriptionAsync(string paymentId);
        Task<List<SubscriptionPlan>> GetActiveSubscriptionPlansAsync();
        Task<SubscriptionPlan> GetPlanByIdAsync(int planId);
        Task<List<Subscription>> GetUserSubscriptionsAsync(string userId);
        Task UpdateSubscriptionAsync(Subscription subscription);
        Task<Subscription> GetActiveSubscriptionForUser(string userId);
    }

    public class SubscriptionService : ISubscriptionService
    {
        private readonly RegularBaseBooksContext _db;
        private readonly UserManager<ApplicationUser> _userManager;

        public SubscriptionService(RegularBaseBooksContext db, UserManager<ApplicationUser> userManager)
        {
            _db = db;
            _userManager = userManager;
        }

        /// <summary>
        /// Создаёт запись в таблице Subscriptions со статусом "не активна" (IsActive = false).
        /// Возвращаем её, чтобы далее при успешной оплате обновить.
        /// </summary>
        public async Task<Subscription> CreateSubscriptionAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew)
        {
            try
            {
                // Сначала деактивируем старую подписку, если нужна логика "одна активная"
                // (или можно оставить, тогда у пользователя будут несколько исторических подписок)
                var oldSubscriptions = await _db.Subscriptions
                    .Where(s => s.UserId == user.Id && s.IsActive)
                    .ToListAsync();
                foreach (var sub in oldSubscriptions)
                {
                    sub.IsActive = false;
                }

                var newSub = new Subscription
                {
                    UserId = user.Id,
                    SubscriptionPlanId = plan.Id,
                    StartDate = DateTime.UtcNow,
                    // Предположим, подписка на месяц:
                    EndDate = DateTime.UtcNow.AddMonths(1),
                    IsActive = false, // станет true после оплаты
                    AutoRenew = autoRenew,
                    PaymentId = null,
                    PriceAtPurchase = plan.Price
                };
                _db.Subscriptions.Add(newSub);

                // Если используете поле HasSubscription в ApplicationUser:
                user.HasSubscription = false;
                // (до фактической оплаты, позже включим true, когда оплата пройдёт)

                await _db.SaveChangesAsync();
                return newSub;
            }
            catch(Exception e)
            {
                return null;
            }
        }

        /// <summary>
        /// Находит подписку с указанным PaymentId и активирует её (IsActive = true), 
        /// а также ставит user.HasSubscription = true
        /// </summary>
        public async Task ActivateSubscriptionAsync(string paymentId)
        {
            var subscription = await _db.Subscriptions
                .Include(s => s.User)
                .FirstOrDefaultAsync(s => s.PaymentId == paymentId);

            if (subscription == null)
                return;

            subscription.IsActive = true;
            subscription.UsedRequestsThisPeriod = 0; // обнуляем счётчик запросов
            // Если хотим текущую подписку держать в user:
            subscription.User.HasSubscription = true;
            subscription.User.CurrentSubscriptionId = subscription.Id;

            await _db.SaveChangesAsync();
        }

        public async Task<List<SubscriptionPlan>> GetActiveSubscriptionPlansAsync()
        {
            return await _db.SubscriptionPlans.Where(p => p.IsActive).ToListAsync();
        }

        public async Task<SubscriptionPlan> GetPlanByIdAsync(int planId)
        {
            return await _db.SubscriptionPlans.FirstOrDefaultAsync(x => x.Id == planId && x.IsActive);
        }

        public async Task<List<Subscription>> GetUserSubscriptionsAsync(string userId)
        {
            return await _db.Subscriptions
                .Include(s => s.SubscriptionPlan)
                .Where(s => s.UserId == userId)
                .OrderByDescending(s => s.StartDate)
                .ToListAsync();
        }
        public async Task UpdateSubscriptionAsync(Subscription subscription)
        {            
            _db.Subscriptions.Update(subscription);

            await _db.SaveChangesAsync();
        }
        public async Task<Subscription> GetActiveSubscriptionForUser(string userId)
        {
            // возвращаем активную подписку, если EndDate > Now и IsActive = true
            var now = DateTime.UtcNow;
            var sub = await _db.Subscriptions
                .Include(s => s.SubscriptionPlan)
                .Where(s => s.UserId == userId && s.IsActive && s.EndDate > now)
                .OrderByDescending(s => s.StartDate)
                .FirstOrDefaultAsync();
            return sub;
        }


    }
}
