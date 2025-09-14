using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace RareBooksService.WebApi.Services
{
    public class NotificationBackgroundService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<NotificationBackgroundService> _logger;
        private readonly TimeSpan _interval = TimeSpan.FromMinutes(30); // Каждые 30 минут

        public NotificationBackgroundService(
            IServiceProvider serviceProvider, 
            ILogger<NotificationBackgroundService> logger)
        {
            _serviceProvider = serviceProvider ?? throw new ArgumentNullException(nameof(serviceProvider));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("NotificationBackgroundService запущен");

            // Ждем 5 минут после старта приложения перед первым запуском
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await ProcessNotificationsAsync(stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Ошибка при обработке уведомлений в background service");
                }

                try
                {
                    await Task.Delay(_interval, stoppingToken);
                }
                catch (TaskCanceledException)
                {
                    // Нормальная остановка сервиса
                    break;
                }
            }

            _logger.LogInformation("NotificationBackgroundService остановлен");
        }

        private async Task ProcessNotificationsAsync(CancellationToken cancellationToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var notificationService = scope.ServiceProvider.GetRequiredService<IBookNotificationService>();

            try
            {
                _logger.LogInformation("Начинаю периодическую обработку уведомлений...");
                
                await notificationService.ProcessNotificationsAsync(cancellationToken);
                
                _logger.LogInformation("Периодическая обработка уведомлений завершена");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при периодической обработке уведомлений");
            }
        }

        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("NotificationBackgroundService получил сигнал остановки");
            await base.StopAsync(cancellationToken);
        }
    }
}
