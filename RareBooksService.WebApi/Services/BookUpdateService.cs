// BookUpdateService.cs

using RareBooksService.Parser.Services;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public interface IBookUpdateService
    {
        /// <summary>
        /// Указывает, стоит ли сейчас на паузе сервис (не выполняет основные операции).
        /// </summary>
        bool IsPaused { get; set; }

        /// <summary>
        /// Показывает, выполняется ли сейчас какая-то операция (FetchAllNewData, и т.д.).
        /// </summary>
        bool IsRunningNow { get; }

        /// <summary>
        /// Время последнего запуска (UTC).
        /// </summary>
        DateTime? LastRunTimeUtc { get; }

        /// <summary>
        /// Время следующего запланированного запуска (UTC).
        /// </summary>
        DateTime? NextRunTimeUtc { get; }

        /// <summary>
        /// Принудительно поставить сервис на паузу, отменяя любую текущую операцию.
        /// </summary>
        void ForcePause();

        /// <summary>
        /// Снять паузу, чтобы сервис мог выполнять следующие операции.
        /// </summary>
        void ForceResume();
    }

    public class BookUpdateService : BackgroundService, IBookUpdateService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<BookUpdateService> _logger;

        private static bool _isPaused = false;
        private static bool _isRunningNow = false;
        private static DateTime? _lastRunTimeUtc = null;
        private static DateTime? _nextRunTimeUtc = null;

        // Для отмены текущего прогона (подробнее см. предыдущий пример)
        private CancellationTokenSource? _ctsForCurrentRun;
        private Task? _currentRunTask;

        public bool IsPaused
        {
            get => _isPaused;
            set => _isPaused = value;
        }
        public bool IsRunningNow => _isRunningNow;
        public DateTime? LastRunTimeUtc => _lastRunTimeUtc;
        public DateTime? NextRunTimeUtc => _nextRunTimeUtc;

        public BookUpdateService(IServiceProvider serviceProvider, ILogger<BookUpdateService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Пример «вечного» цикла, который планирует задание раз в 3 дня
            while (!stoppingToken.IsCancellationRequested)
            {
                var nextRun = DateTime.UtcNow.Date.AddDays(3);
                if (nextRun < DateTime.UtcNow)
                    nextRun = nextRun.AddDays(3);

                _nextRunTimeUtc = nextRun;

                var delay = nextRun - DateTime.UtcNow;
                if (delay < TimeSpan.Zero)
                    delay = TimeSpan.Zero;

                try
                {
                    await Task.Delay(delay, stoppingToken);
                }
                catch (TaskCanceledException)
                {
                    return; // завершаем службу
                }

                if (stoppingToken.IsCancellationRequested)
                    return;

                // Создаем токен на текущий запуск
                _ctsForCurrentRun = new CancellationTokenSource();
                using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(
                    stoppingToken,
                    _ctsForCurrentRun.Token
                );
                var actualToken = linkedCts.Token;

                _currentRunTask = RunUpdateBooksAsync(actualToken);

                try
                {
                    await _currentRunTask;
                }
                catch (OperationCanceledException)
                {
                    _logger.LogInformation("RunUpdateBooksAsync был прерван (OperationCanceledException).");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Неожиданная ошибка в RunUpdateBooksAsync");
                }
                finally
                {
                    _currentRunTask = null;
                    _ctsForCurrentRun.Dispose();
                    _ctsForCurrentRun = null;
                }
            }
        }

        private async Task RunUpdateBooksAsync(CancellationToken token)
        {
            if (_isPaused)
            {
                _logger.LogInformation("BookUpdateService: пауза, пропускаем обновление.");
                return;
            }

            _isRunningNow = true;
            _lastRunTimeUtc = DateTime.UtcNow;

            using var scope = _serviceProvider.CreateScope();
            // Пример получения необходимых сервисов
            var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();
            var auctionService = scope.ServiceProvider.GetRequiredService<IAuctionService>();

            try
            {
                _logger.LogInformation("Starting fetchAllNewData...");
                await lotFetchingService.FetchAllNewData(token);

                _logger.LogInformation("Updating completed auctions...");
                await auctionService.UpdateCompletedAuctionsAsync(token);

                _logger.LogInformation("Fetching sold fixed price lots...");
                await lotFetchingService.FetchSoldFixedPriceLotsAsync(token);
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("RunUpdateBooksAsync прерван из-за отмены (OperationCanceledException).");
                throw; // пробрасываем выше
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

        public void ForcePause()
        {
            _isPaused = true;
            // Отменяем текущий прогон, если он есть
            if (_ctsForCurrentRun != null)
            {
                _logger.LogInformation("Cancel current run because of ForcePause()");
                _ctsForCurrentRun.Cancel();
            }
        }

        public void ForceResume()
        {
            _isPaused = false;
            // Если хотим прямо сейчас запустить — можно вручную запустить, 
            // иначе дождемся планового времени
        }
    }
}
