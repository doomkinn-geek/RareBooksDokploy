using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;

namespace RareBooksService.WebApi.Services
{
    public class SubscriptionRenewalBackgroundService : BackgroundService
    {
        private readonly ILogger<SubscriptionRenewalBackgroundService> _logger;
        private readonly IServiceScopeFactory _scopeFactory;

        public SubscriptionRenewalBackgroundService(
            ILogger<SubscriptionRenewalBackgroundService> logger,
            IServiceScopeFactory scopeFactory)
        {
            _logger = logger;
            _scopeFactory = scopeFactory;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("SubscriptionRenewalBackgroundService started");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await RenewExpiredSubscriptions(stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error in RenewExpiredSubscriptions");
                }
                await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
                // пока ставим маленький интервал для теста
                //await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
            }
        }

        private async Task RenewExpiredSubscriptions(CancellationToken stoppingToken)
        {
            // Создаём scope
            using var scope = _scopeFactory.CreateScope();

            // Берём необходимые scoped‑сервисы
            var db = scope.ServiceProvider.GetRequiredService<UsersDbContext>();
            var subscriptionService = scope.ServiceProvider.GetRequiredService<ISubscriptionService>();

            var now = DateTime.UtcNow;

            // 1) Пытаемся продлить те подписки, где авто-продление включено
            var subsToRenew = await db.Subscriptions
                .Where(s => s.IsActive && s.AutoRenew && s.PaymentMethodId != null && s.EndDate <= now)
                .ToListAsync(stoppingToken);

            _logger.LogInformation("Found {Count} subscriptions to renew", subsToRenew.Count);

            foreach (var sub in subsToRenew)
            {
                if (stoppingToken.IsCancellationRequested) break;

                _logger.LogInformation("Trying to auto-renew subscription #{Id}", sub.Id);
                bool success = await subscriptionService.TryAutoRenewSubscriptionAsync(sub.Id);
                _logger.LogInformation("Auto-renew subscription #{Id}: {Result}", sub.Id, success ? "SUCCESS" : "FAILED");
            }

            // 2) Отключаем подписки, которые НЕ autoRenew и уже истекли
            var subsToCancel = await db.Subscriptions
                .Include(s => s.User)
                .Where(s => s.IsActive && !s.AutoRenew && s.EndDate <= now)
                .ToListAsync(stoppingToken);

            if (subsToCancel.Count > 0)
            {
                _logger.LogInformation(
                    "Found {Count} subscriptions that expired and will be canceled (autoRenew = false)",
                    subsToCancel.Count
                );

                foreach (var sub in subsToCancel)
                {
                    sub.IsActive = false;
                    if (sub.User != null)
                    {
                        sub.User.HasSubscription = false;
                    }
                }

                await db.SaveChangesAsync(stoppingToken);
                _logger.LogInformation("{Count} expired subscriptions canceled", subsToCancel.Count);
            }
        }
    }


}
