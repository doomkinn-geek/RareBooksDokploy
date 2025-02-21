using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;

namespace RareBooksService.WebApi.Services
{
    public class SubscriptionRenewalBackgroundService : BackgroundService
    {
        private readonly ILogger<SubscriptionRenewalBackgroundService> _logger;
        private readonly ISubscriptionService _subscriptionService;
        private readonly IServiceScopeFactory _scopeFactory;

        public SubscriptionRenewalBackgroundService(
            ILogger<SubscriptionRenewalBackgroundService> logger,
            ISubscriptionService subscriptionService,
            IServiceScopeFactory scopeFactory)
        {
            _logger = logger;
            _subscriptionService = subscriptionService;
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

                // Спим сутки — либо можно сделать чаще
                await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
                //await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
            }
        }

        private async Task RenewExpiredSubscriptions(CancellationToken stoppingToken)
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var now = DateTime.UtcNow;

            // 1) Попытка продлить те подписки, у которых включён autoRenew:
            var subsToRenew = await db.Subscriptions
                .Where(s => s.IsActive && s.AutoRenew && s.PaymentMethodId != null && s.EndDate <= now)
                .ToListAsync(stoppingToken);

            _logger.LogInformation("Found {Count} subscriptions to renew", subsToRenew.Count);

            foreach (var sub in subsToRenew)
            {
                if (stoppingToken.IsCancellationRequested)
                    break;

                _logger.LogInformation("Trying to auto-renew subscription #{Id}", sub.Id);
                bool success = await _subscriptionService.TryAutoRenewSubscriptionAsync(sub.Id);
                _logger.LogInformation("Auto-renew subscription #{Id}: {Result}", sub.Id, success ? "SUCCESS" : "FAILED");
            }

            // 2) Отключаем подписки, которые НЕ autoRenew и уже истекли
            var subsToCancel = await db.Subscriptions
                .Include(s => s.User)
                .Where(s => s.IsActive && !s.AutoRenew && s.EndDate <= now)
                .ToListAsync(stoppingToken);

            if (subsToCancel.Count > 0)
            {
                _logger.LogInformation("Found {Count} subscriptions that expired and will be canceled (autoRenew = false)", subsToCancel.Count);

                foreach (var sub in subsToCancel)
                {
                    sub.IsActive = false;
                    if (sub.User != null)
                    {
                        sub.User.HasSubscription = false;
                    }
                    // Или sub.EndDate = DateTime.UtcNow; // если хотите зафиксировать, что она закончилась прямо сейчас
                }

                await db.SaveChangesAsync(stoppingToken);
                _logger.LogInformation("{Count} expired subscriptions canceled", subsToCancel.Count);
            }
        }

    }

}
