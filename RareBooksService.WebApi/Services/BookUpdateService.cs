using RareBooksService.Parser.Services;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public interface IBookUpdateService
    {
        bool IsPaused { get; set; }
        bool IsRunningNow { get; }
        DateTime? LastRunTimeUtc { get; }
        DateTime? NextRunTimeUtc { get; }

        // Признак, что последняя запланированная задача была пропущена из-за паузы.
        bool MissedRunDueToPause { get; }

        void ForcePause();
        void ForceResume();
        void ForceRunNow();
    }

    public class BookUpdateService : BackgroundService, IBookUpdateService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<BookUpdateService> _logger;

        private bool _isPaused;
        private bool _isRunningNow;
        private DateTime? _lastRunTimeUtc;
        private DateTime? _nextRunTimeUtc;

        // Флаг: был ли пропущен запуск из-за паузы
        private bool _missedRunDueToPause = false;

        // Флаг: «мягкая отмена» текущего процесса, чтобы дождаться завершения текущего лота
        private bool _cancellationRequested = false;

        // Прогресс-данные
        private string? _currentOperationName;
        private int _processedCount;
        private int _lastProcessedLotId;
        private string? _lastProcessedLotTitle;

        // Свойства для чтения этих данных извне:
        public string? CurrentOperationName => _currentOperationName;
        public int ProcessedCount => _processedCount;
        public int LastProcessedLotId => _lastProcessedLotId;
        public string? LastProcessedLotTitle => _lastProcessedLotTitle;

        // Текущая задача (на случай, если нужно дождаться её завершения)
        private Task? _currentRunTask;

        public BookUpdateService(IServiceProvider serviceProvider, ILogger<BookUpdateService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        public bool IsPaused
        {
            get => _isPaused;
            set => _isPaused = value;
        }

        public bool IsRunningNow => _isRunningNow;
        public DateTime? LastRunTimeUtc => _lastRunTimeUtc;
        public DateTime? NextRunTimeUtc => _nextRunTimeUtc;

        public bool MissedRunDueToPause => _missedRunDueToPause;

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                // Если подошло время запуститься
                // (по примеру — каждые 3 дня, либо можно вычислять дату и т. п.)
                // Для наглядности считаем, что сразу запускаем задачу, 
                // а потом ждем 3 дня.

                _cancellationRequested = false;  // сброс флага на каждую попытку

                if (_isPaused)
                {
                    // Если сервис на паузе — пропускаем запуск
                    _logger.LogInformation("Сервис на паузе, пропускаем плановый запуск");
                    _missedRunDueToPause = true;
                }
                else
                {
                    // Запускаем «работу»
                    _currentRunTask = RunUpdateBooksAsync(stoppingToken);
                    try
                    {
                        await _currentRunTask;
                    }
                    catch (Exception ex)
                    {
                        // Ловим любые ошибки
                        _logger.LogError(ex, "Ошибка в RunUpdateBooksAsync");
                    }
                    finally
                    {
                        _currentRunTask = null;
                    }
                }

                if (stoppingToken.IsCancellationRequested)
                    return;

                // Запланируем следующий запуск через 3 дня
                var nextRun = DateTime.UtcNow.AddDays(3);
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
                    return;
                }
            }
        }

        // Основной метод, в котором мы вызываем lotFetchingService
        private async Task RunUpdateBooksAsync(CancellationToken externalStoppingToken)
        {
            _isRunningNow = true;
            _lastRunTimeUtc = DateTime.UtcNow;
            _missedRunDueToPause = false; // Так как мы сейчас успешно запускаемся

            using var scope = _serviceProvider.CreateScope();
            var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();
            var auctionService = scope.ServiceProvider.GetRequiredService<IAuctionService>();

            // Подписываемся на ProgressChanged, чтобы обновлять поля
            if (lotFetchingService is LotFetchingService realLotFetchingService)
            {
                realLotFetchingService.ProgressChanged += OnLotProgressChanged;
                // Передадим ему «делегат/флаг» для graceful-cancel на уровне лотов
                realLotFetchingService.SetCancellationCheckFunc(() => _cancellationRequested || externalStoppingToken.IsCancellationRequested);
            }

            try
            {
                // 0) FreeList с данными малозначимых книг:

                /*if (!_cancellationRequested && !externalStoppingToken.IsCancellationRequested)
                {
                    _currentOperationName = "FetchFreeListData";
                    ResetProgress();

                    List<int> idList = File.ReadAllLines("d:\\temp\\books\\extendedNonStandardPricesSoviet_Group_x.txt")
                        .Select(x => int.Parse(x))
                        .ToList();
                    await lotFetchingService.FetchFreeListData(idList);
                }

                // 1) FetchAllNewData
                if (!_cancellationRequested && !externalStoppingToken.IsCancellationRequested)
                {
                    _currentOperationName = "FetchAllNewData";
                    ResetProgress();
                    _logger.LogInformation("Starting fetchAllNewData...");
                    await lotFetchingService.FetchAllNewData(externalStoppingToken);
                }

                // 2) UpdateCompletedAuctionsAsync
                if (!_cancellationRequested && !externalStoppingToken.IsCancellationRequested)
                {
                    _currentOperationName = "UpdateCompletedAuctionsAsync";
                    ResetProgress();
                    _logger.LogInformation("Updating completed auctions...");
                    await auctionService.UpdateCompletedAuctionsAsync(externalStoppingToken);
                }

                // 3) FetchSoldFixedPriceLotsAsync
                if (!_cancellationRequested && !externalStoppingToken.IsCancellationRequested)
                {
                    _currentOperationName = "FetchSoldFixedPriceLotsAsync";
                    ResetProgress();
                    _logger.LogInformation("Fetching sold fixed price lots...");
                    await lotFetchingService.FetchSoldFixedPriceLotsAsync(externalStoppingToken);
                }*/
            }
            finally
            {
                if (lotFetchingService is LotFetchingService realLotFetchingService2)
                {
                    realLotFetchingService2.ProgressChanged -= OnLotProgressChanged;
                    realLotFetchingService2.SetCancellationCheckFunc(null);
                }

                _isRunningNow = false;
                _currentOperationName = null;
                _logger.LogInformation("RunUpdateBooksAsync завершён. cancellationRequested={0}", _cancellationRequested);
            }
        }

        private void OnLotProgressChanged(int currentLotId, string? currentTitle)
        {
            _processedCount++;
            _lastProcessedLotId = currentLotId;
            if (!string.IsNullOrWhiteSpace(currentTitle))
                _lastProcessedLotTitle = currentTitle;

            _logger.LogInformation("Обработан лот #{LotId}, '{Title}'", currentLotId, currentTitle);
        }

        private void ResetProgress()
        {
            _processedCount = 0;
            _lastProcessedLotId = 0;
            _lastProcessedLotTitle = null;
        }

        /// <summary>
        /// Запросить «мягкую» отмену: после текущего лота остановиться.
        /// + перевести сервис в паузу, чтобы пропускать будущие запуска.
        /// </summary>
        public void ForcePause()
        {
            if (_isPaused)
            {
                _logger.LogInformation("Сервис уже на паузе");
                return;
            }

            _logger.LogInformation("Паузим сервис (с остановкой текущего процесса после лота).");
            _isPaused = true;
            _cancellationRequested = true;
            // Теперь в процессе (RunUpdateBooksAsync) после каждого лота мы будем проверять _cancellationRequested
            // и выйдем аккуратно.
        }

        /// <summary>
        /// Снять паузу. Если во время паузы пропустили запуск, _missedRunDueToPause = true,
        /// но мы НЕ запускаем сразу автоматически => ждём планового (или жмём RunNow).
        /// </summary>
        public void ForceResume()
        {
            if (!_isPaused)
            {
                _logger.LogInformation("Сервис и так не на паузе.");
                return;
            }

            _logger.LogInformation("Resume: снимаем паузу. (Но не запускаем автоматически — ждём планового запуска или ForceRunNow.)");
            _isPaused = false;
            _cancellationRequested = false; // Если вдруг был запрос на отмену, снимаем.
        }

        /// <summary>
        /// Внеплановый запуск (если сервис не запущен и не на паузе).
        /// </summary>
        public void ForceRunNow()
        {
            // Если хотим запретить запуск, пока сервис на паузе:
            if (_isPaused)
            {
                _logger.LogWarning("Сервис на паузе — сначала сделайте Resume().");
                return;
            }

            // Проверяем, не идёт ли уже операция
            if (_currentRunTask != null && !_currentRunTask.IsCompleted)
            {
                _logger.LogWarning("Уже идёт текущая операция, дождитесь окончания или нажмите Pause().");
                return;
            }

            _cancellationRequested = false;
            _logger.LogInformation("ForceRunNow: запускаем RunUpdateBooksAsync внепланово.");

            // Запускаем задачу в фоне (не дожидаемся её тут)
            var token = new CancellationToken(); // местный, т.к. у нас нет прямого Cancel
            _currentRunTask = RunUpdateBooksAsync(token);
        }
    }
}
