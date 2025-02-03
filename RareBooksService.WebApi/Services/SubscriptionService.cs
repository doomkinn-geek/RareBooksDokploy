using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data;

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
        Task<bool> AssignSubscriptionPlanAsync(string userId, int planId, bool autoRenew);
        Task<bool> DisableSubscriptionAsync(string userId);
    }

    public class SubscriptionService : ISubscriptionService
    {
        private readonly UsersDbContext _db;
        private readonly UserManager<ApplicationUser> _userManager;

        public SubscriptionService(UsersDbContext db, UserManager<ApplicationUser> userManager)
        {
            _db = db;
            _userManager = userManager;
        }

        /// <summary>
        /// Создаёт запись в таблице Subscriptions со статусом "не активна" (IsActive = false).
        /// Возвращаем Subscription, чтобы позднее при успешной оплате её активировать.
        /// При этом «старые» активные подписки отключаются (IsActive=false), если вам нужно
        /// строгое правило "только одна подписка".
        /// </summary>
        public async Task<Subscription> CreateSubscriptionAsync(ApplicationUser user, SubscriptionPlan plan, bool autoRenew)
        {
            // Выключаем все предыдущие подписки, если нужно правило «только одна активная»
            var oldSubscriptions = await _db.Subscriptions
                .Where(s => s.UserId == user.Id && s.IsActive)
                .ToListAsync();
            foreach (var sub in oldSubscriptions)
            {
                sub.IsActive = false;
            }

            // Создаём новую подписку со статусом "ещё не активна"
            var newSub = new Subscription
            {
                UserId = user.Id,
                SubscriptionPlanId = plan.Id,
                StartDate = DateTime.UtcNow,
                EndDate = DateTime.UtcNow.AddMonths(1), // пример: срок = 1 месяц
                IsActive = false,  // активируем только после оплаты
                AutoRenew = autoRenew,
                PaymentId = null,  // платёж создадим и запишем позднее
                PriceAtPurchase = plan.Price
            };
            _db.Subscriptions.Add(newSub);

            // Пока оплата не прошла — user.HasSubscription = false
            user.HasSubscription = false;

            await _db.SaveChangesAsync();

            return newSub;
        }

        /// <summary>
        /// Активация подписки с указанным paymentId. Ставим IsActive = true,
        /// обнуляем счётчик запросов (UsedRequestsThisPeriod = 0).
        /// Также у пользователя ставим HasSubscription = true.
        /// </summary>
        public async Task ActivateSubscriptionAsync(string paymentId)
        {
            var subscription = await _db.Subscriptions
                .Include(s => s.User)
                .FirstOrDefaultAsync(s => s.PaymentId == paymentId);

            if (subscription == null)
                return;

            // Активируем
            subscription.IsActive = true;
            subscription.UsedRequestsThisPeriod = 0;
            subscription.User.HasSubscription = true;

            // При необходимости отключаем другие подписки (если есть ещё IsActive=true)
            var sameUserActiveSubs = await _db.Subscriptions
                .Where(s => s.UserId == subscription.UserId
                            && s.Id != subscription.Id
                            && s.IsActive)
                .ToListAsync();
            foreach (var old in sameUserActiveSubs)
            {
                old.IsActive = false;
            }

            await _db.SaveChangesAsync();
        }

        /// <summary>
        /// Возвращает список доступных (IsActive=true) планов подписки.
        /// </summary>
        public async Task<List<SubscriptionPlan>> GetActiveSubscriptionPlansAsync()
        {
            return await _db.SubscriptionPlans
                .Where(p => p.IsActive)
                .ToListAsync();
        }

        public async Task<SubscriptionPlan> GetPlanByIdAsync(int planId)
        {
            return await _db.SubscriptionPlans
                .FirstOrDefaultAsync(x => x.Id == planId && x.IsActive);
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

        /// <summary>
        /// Получаем действующую подписку пользователя (IsActive=true, EndDate>Now) 
        /// или null, если её нет.
        /// </summary>
        public async Task<Subscription> GetActiveSubscriptionForUser(string userId)
        {
            var now = DateTime.UtcNow;
            var sub = await _db.Subscriptions
                .Include(s => s.SubscriptionPlan)
                .Where(s => s.UserId == userId && s.IsActive && s.EndDate > now)
                .OrderByDescending(s => s.StartDate)
                .FirstOrDefaultAsync();

            return sub;
        }

        /// <summary>
        /// Выделенный метод для ручного «назначения плана» (без оплаты),
        /// отключающий старую подписку и создающий новую с IsActive=true.
        /// </summary>
        public async Task<bool> AssignSubscriptionPlanAsync(string userId, int planId, bool autoRenew)
        {
            var user = await _db.Users
                .Include(u => u.Subscriptions)
                .FirstOrDefaultAsync(u => u.Id == userId);
            if (user == null)
                return false;

            // Выключаем старую активную
            var oldActive = user.Subscriptions
                .Where(s => s.IsActive)
                .ToList();
            foreach (var oldSub in oldActive)
            {
                oldSub.IsActive = false;
            }

            // Проверяем план
            var plan = await _db.SubscriptionPlans.FindAsync(planId);
            if (plan == null || !plan.IsActive)
            {
                return false; // не можем назначить неактивный или несуществующий план
            }

            // Создаём новую подписку (сразу активную)
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

            // Ставим флаг
            user.HasSubscription = true;

            await _db.SaveChangesAsync();
            return true;
        }

        /// <summary>
        /// Отлючает все активные подписки пользователя (IsActive=false)
        /// и ставит HasSubscription = false.
        /// </summary>
        public async Task<bool> DisableSubscriptionAsync(string userId)
        {
            // 1. Найдём пользователя
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return false;

            // 2. Ищем все активные подписки (IsActive=true) и отключаем
            var activeSubs = await _db.Subscriptions
                .Where(s => s.UserId == userId && s.IsActive)
                .ToListAsync();

            foreach (var sub in activeSubs)
            {
                sub.IsActive = false;
            }

            user.HasSubscription = false;

            await _db.SaveChangesAsync();
            return true;
        }
    }
}
