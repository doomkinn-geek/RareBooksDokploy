// BookUpdateService.cs

using RareBooksService.Parser.Services;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public class BookUpdateService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<BookUpdateService> _logger;

        // Сделаем статический (или Singleton) флаг, который будет указывать на паузу.
        // Можно реализовать по-разному (через Shared service), тут для простоты:
        private static bool _isPaused = false;

        // Чтобы знать, когда сервис реально что-то делает, заведём ещё поле «isRunning».
        private static bool _isRunningNow = false;

        // Можно хранить время последнего запуска и следующего
        private static DateTime? _lastRunTimeUtc = null;
        private static DateTime? _nextRunTimeUtc = null;

        public static bool IsPaused
        {
            get => _isPaused;
            set => _isPaused = value;
        }

        public static bool IsRunningNow => _isRunningNow;
        public static DateTime? LastRunTimeUtc => _lastRunTimeUtc;
        public static DateTime? NextRunTimeUtc => _nextRunTimeUtc;

        public BookUpdateService(IServiceProvider serviceProvider,
            ILogger<BookUpdateService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Первый запуск сразу
            await UpdateBooksAsync(stoppingToken);

            // Schedule the task (например, каждые 3 дня).
            while (!stoppingToken.IsCancellationRequested)
            {
                // Допустим, каждый раз рассчитываем след. запуск: через 3 дня с полуночью
                // (Пример, можно менять)
                DateTime nextRunTime = DateTime.UtcNow.Date.AddDays(3).AddHours(0);
                if (nextRunTime < DateTime.UtcNow)
                    nextRunTime = nextRunTime.AddDays(3);

                _nextRunTimeUtc = nextRunTime;

                var delay = nextRunTime - DateTime.UtcNow;
                if (delay < TimeSpan.Zero)
                    delay = TimeSpan.Zero;

                try
                {
                    await Task.Delay(delay, stoppingToken);
                }
                catch (TaskCanceledException)
                {
                    // сервис останавливается
                    return;
                }

                if (!stoppingToken.IsCancellationRequested)
                {
                    await UpdateBooksAsync(stoppingToken);
                }
            }
        }

        private async Task UpdateBooksAsync(CancellationToken token)
        {
            // Если сервис «на паузе», то ничего не делаем
            if (_isPaused)
            {
                _logger.LogInformation("BookUpdateService is paused, skip updating.");
                return;
            }

            _isRunningNow = true;
            _lastRunTimeUtc = DateTime.UtcNow;

            using var scope = _serviceProvider.CreateScope();
            var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();
            var auctionService = scope.ServiceProvider.GetRequiredService<IAuctionService>();

            try
            {
                _logger.LogInformation("Starting fetchAllNewData...");
                await lotFetchingService.FetchAllNewData();

                _logger.LogInformation("Updating completed auctions...");
                await auctionService.UpdateCompletedAuctionsAsync();

                _logger.LogInformation("Fetching sold fixed price lots...");
                await lotFetchingService.FetchSoldFixedPriceLotsAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка получения/обновления данных с meshok.net");
            }
            finally
            {
                _isRunningNow = false;
            }
        }
    }
}
