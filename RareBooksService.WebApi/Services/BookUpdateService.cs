using RareBooksService.Parser;
using RareBooksService.Parser.Services;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
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

        /// <summary>
        /// Поставить текущие операции на паузу (завершить безопасно после текущего лота)
        /// и пропускать плановые запуски до Resume().
        /// </summary>
        void ForcePause();

        /// <summary>
        /// Снять паузу. Если во время паузы пропустили запуск, отметим это флагом MissedRunDueToPause,
        /// но не запускаем автоматически - ждём планового старта или ForceRunNow().
        /// </summary>
        void ForceResume();

        /// <summary>
        /// Прервать текущий процесс (если идёт), сбросить прогресс и тут же запустить заново все операции.
        /// </summary>
        void ForceRunNow();
    }

    public class BookUpdateService : BackgroundService, IBookUpdateService, IProgressReporter
    {
        // ==================================================================
        // ========== 1) ЛОГИ ДЛЯ UI (последние N записей) ===================
        // ==================================================================
        private readonly List<LogEntry> _logEntries = new();
        private readonly object _logLock = new object();
        private const int MAX_LOG_COUNT = 50;

        private void AddLogEntry(LogEntry entry)
        {
            lock (_logLock)
            {
                if (_logEntries.Count >= MAX_LOG_COUNT)
                {
                    _logEntries.RemoveAt(0);
                }
                _logEntries.Add(entry);
            }
        }

        public List<LogEntry> GetLogEntriesSnapshot()
        {
            lock (_logLock)
            {
                return _logEntries.ToList();
            }
        }

        // ==================================================================
        // ========== 2) ОСНОВНЫЕ ПОЛЯ СЕРВИСА ==============================
        // ==================================================================
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<BookUpdateService> _logger;

        // Флаг «пауза» означает, что следующие плановые запуски пропускаем,
        // а текущий процесс попросим остановиться
        private bool _isPaused;

        // Флаг «запущен ли сейчас»
        private bool _isRunningNow;

        // Когда запускали в последний раз
        private DateTime? _lastRunTimeUtc;

        // Когда планируем следующий запуск
        private DateTime? _nextRunTimeUtc;

        // Флаг «пропустили ли плановый запуск из-за паузы»
        private bool _missedRunDueToPause;

        // Флаг «мягкой» отмены текущего процесса
        private bool _cancellationRequested;

        // Текущее название операции (для UI)
        private string? _currentOperationName;

        // Счётчик обработанных лотов за операцию
        private int _processedCount;

        // Последний обработанный лот
        private int _lastProcessedLotId;

        // Текст для последнего обработанного лота
        private string? _lastProcessedLotTitle;

        // Текущая задача (если что, можно дождаться)
        private Task? _currentRunTask;

        // ==================================================================
        // ========== 3) СПИСОК ОПЕРАЦИЙ ====================================
        // ==================================================================
        // Мы опишем четыре операции в массиве. При запуске пройдём по ним по порядку.
        public int _currentStepIndex = 0;

        private (string Name, Func<CancellationToken, Task> Operation)[] _operations;

        // ==================================================================
        // ========== 4) КОНСТРУКТОР ========================================
        // ==================================================================
        public BookUpdateService(IServiceProvider serviceProvider, ILogger<BookUpdateService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;

            /*if (!_cancellationRequested && !externalStoppingToken.IsCancellationRequested)
                {
                    _currentOperationName = "UpdateFinishedAuctionsStartPriceOneAsync";
                    ResetProgress();
                    //await lotFetchingService.RefreshLotsWithEmptyImageUrlsAsync(externalStoppingToken);
                    await lotFetchingService.UpdateFinishedAuctionsStartPriceOneAsync(externalStoppingToken);
                }*/

            // 0) FreeList с данными малозначимых книг:

            /*if (!_cancellationRequested && !externalStoppingToken.IsCancellationRequested)
            {
                _currentOperationName = "FetchFreeListData";
                ResetProgress();

                List<int> idList = File.ReadAllLines("d:\\temp\\books\\wrong_id.txt")
                    .Select(x => int.Parse(x))
                    .ToList();
                await lotFetchingService.FetchFreeListData(idList);
            }*/

            // Определяем массив шагов (операций).
            // Каждый шаг - кортеж (НазваниеОперации, async метод).
            _operations = new (string, Func<CancellationToken, Task>)[]
            {
                // Новая операция для проверки категорий книг
                /*("VerifyLotCategoriesAsync", async ct =>
                {
                    using var scope = _serviceProvider.CreateScope();
                    var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();

                    _currentOperationName = "VerifyLotCategoriesAsync";
                    ResetProgress();
                    _logger.LogInformation("Проверка соответствия категорий в лотах...");

                    if (lotFetchingService is LotFetchingService realLotFetchingService)
                    {
                        realLotFetchingService.ProgressChanged += OnLotProgressChanged;
                        realLotFetchingService.SetCancellationCheckFunc(() => _cancellationRequested || ct.IsCancellationRequested);
                    }

                    try
                    {
                        await lotFetchingService.VerifyLotCategoriesAsync(ct);
                    }
                    finally
                    {
                        if (lotFetchingService is LotFetchingService realLotFetchingService2)
                        {
                            realLotFetchingService2.ProgressChanged -= OnLotProgressChanged;
                            realLotFetchingService2.SetCancellationCheckFunc(null);
                        }
                    }
                }),*/
                
                // Операция для скачивания изображений для книг с относительными URL
                /*("RefreshLotsWithRelativeImageUrlsAsync", async ct =>
                {
                    using var scope = _serviceProvider.CreateScope();
                    var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();

                    _currentOperationName = "RefreshLotsWithRelativeImageUrlsAsync";
                    ResetProgress();
                    _logger.LogInformation("Обработка книг с относительными URL изображений...");

                    if (lotFetchingService is LotFetchingService realLotFetchingService)
                    {
                        realLotFetchingService.ProgressChanged += OnLotProgressChanged;
                        realLotFetchingService.SetCancellationCheckFunc(() => _cancellationRequested || ct.IsCancellationRequested);
                    }

                    try
                    {
                        await lotFetchingService.RefreshLotsWithRelativeImageUrlsAsync(ct);
                    }
                    finally
                    {
                        if (lotFetchingService is LotFetchingService realLotFetchingService2)
                        {
                            realLotFetchingService2.ProgressChanged -= OnLotProgressChanged;
                            realLotFetchingService2.SetCancellationCheckFunc(null);
                        }
                    }
                }),*/
                ("FetchAllNewData", async ct =>
                {
                    // Для каждой операции создаём scope, чтобы получить нужные сервисы:
                    using var scope = _serviceProvider.CreateScope();
                    var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();

                    _currentOperationName = "FetchAllNewData";
                    ResetProgress();
                    _logger.LogInformation("Starting fetchAllNewData...");

                    // Передаем токен, внутри lotFetchingService есть проверки ct.IsCancellationRequested
                    // + SetCancellationCheckFunc(...)
                    if (lotFetchingService is LotFetchingService realLotFetchingService)
                    {
                        realLotFetchingService.ProgressChanged += OnLotProgressChanged;
                        realLotFetchingService.SetCancellationCheckFunc(() => _cancellationRequested || ct.IsCancellationRequested);
                    }

                    try
                    {
                        await lotFetchingService.FetchAllNewData(ct);
                    }
                    finally
                    {
                        // Снимаем подписки
                        if (lotFetchingService is LotFetchingService realLotFetchingService2)
                        {
                            realLotFetchingService2.ProgressChanged -= OnLotProgressChanged;
                            realLotFetchingService2.SetCancellationCheckFunc(null);
                        }
                    }
                }),

                ("UpdateCompletedAuctionsAsync", async ct =>
                {
                    using var scope = _serviceProvider.CreateScope();
                    var auctionService = scope.ServiceProvider.GetRequiredService<IAuctionService>();

                    _currentOperationName = "UpdateCompletedAuctionsAsync";
                    ResetProgress();
                    _logger.LogInformation("Updating completed auctions...");
                    await auctionService.UpdateCompletedAuctionsAsync(ct);
                }),

                ("FetchSoldFixedPriceLotsAsync", async ct =>
                {
                    using var scope = _serviceProvider.CreateScope();
                    var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();

                    _currentOperationName = "FetchSoldFixedPriceLotsAsync";
                    ResetProgress();
                    _logger.LogInformation("Fetching sold fixed price lots...");

                    if (lotFetchingService is LotFetchingService realLotFetchingService)
                    {
                        realLotFetchingService.ProgressChanged += OnLotProgressChanged;
                        realLotFetchingService.SetCancellationCheckFunc(() => _cancellationRequested || ct.IsCancellationRequested);
                    }

                    try
                    {
                        await lotFetchingService.FetchSoldFixedPriceLotsAsync(ct);
                    }
                    finally
                    {
                        if (lotFetchingService is LotFetchingService realLotFetchingService2)
                        {
                            realLotFetchingService2.ProgressChanged -= OnLotProgressChanged;
                            realLotFetchingService2.SetCancellationCheckFunc(null);
                        }
                    }
                }),

                ("UpdateFinishedFixedPriceAsync", async ct =>
                {
                    using var scope = _serviceProvider.CreateScope();
                    var lotFetchingService = scope.ServiceProvider.GetRequiredService<ILotFetchingService>();

                    _currentOperationName = "UpdateFinishedFixedPriceAsync";
                    ResetProgress();
                    _logger.LogInformation("Fetching sold fixed price lots... (UpdateFinishedFixedPriceAsync)");

                    if (lotFetchingService is LotFetchingService realLotFetchingService)
                    {
                        realLotFetchingService.ProgressChanged += OnLotProgressChanged;
                        realLotFetchingService.SetCancellationCheckFunc(() => _cancellationRequested || ct.IsCancellationRequested);
                    }

                    try
                    {
                        await lotFetchingService.UpdateFinishedFixedPriceAsync(ct);
                    }
                    finally
                    {
                        if (lotFetchingService is LotFetchingService realLotFetchingService2)
                        {
                            realLotFetchingService2.ProgressChanged -= OnLotProgressChanged;
                            realLotFetchingService2.SetCancellationCheckFunc(null);
                        }
                    }
                })
            };
        }

        // ==================================================================
        // ========== 5) ОСНОВНОЙ ЦИКЛ HOSTED SERVICE ========================
        // ==================================================================
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                // Сбрасываем для нового запуска
                _cancellationRequested = false;
                
                // Сбрасываем индекс текущего шага для следующего запуска
                _currentStepIndex = 0;

                if (_isPaused)
                {
                    _logger.LogInformation("Сервис на паузе => пропускаем плановый запуск");
                    _missedRunDueToPause = true;
                }
                else
                {
                    // Запускаем все операции (если не запущено)
                    await RunAllOperationsAsync(stoppingToken);
                }

                if (stoppingToken.IsCancellationRequested) break;

                // Ждем 1 день
                var nextRun = DateTime.UtcNow.AddDays(1);
                _nextRunTimeUtc = nextRun;
                var delay = nextRun - DateTime.UtcNow;
                if (delay < TimeSpan.Zero) delay = TimeSpan.Zero;

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

        // ==================================================================
        // ========== 6) ЗАПУСК ЦЕПОЧКИ ОПЕРАЦИЙ =============================
        // ==================================================================
        private async Task RunAllOperationsAsync(CancellationToken externalToken)
        {
            if (_isRunningNow)
            {
                _logger.LogWarning("Попытка RunAllOperationsAsync, но уже идёт выполнение. Отклоняем.");
                return;
            }

            _isRunningNow = true;
            _lastRunTimeUtc = DateTime.UtcNow;
            _missedRunDueToPause = false;

            try
            {
                while (_currentStepIndex < _operations.Length)
                {
                    if (_isPaused || _cancellationRequested || externalToken.IsCancellationRequested)
                    {
                        // Прерываем цикл, сохраняя _currentStepIndex
                        _logger.LogInformation("Остановка цепочки операций на шаге {0}, пауза/отмена", _currentStepIndex);
                        return;
                    }

                    var (opName, opFunc) = _operations[_currentStepIndex];
                    _logger.LogInformation("=== Запуск операции [{0}] (stepIndex={1}) ===", opName, _currentStepIndex);

                    try
                    {
                        // Вызываем функцию операции, передавая token
                        await opFunc(externalToken);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Ошибка внутри операции [{0}], stepIndex={1}.", opName, _currentStepIndex);
                        // Можно сделать break, чтобы прервать всю цепочку, или continue, 
                        // или вообще игнорировать и идти дальше. Тут — continue:
                    }

                    _currentStepIndex++;
                }

                // Если дошли сюда, значит выполнили все 4 операции
                _logger.LogInformation("=== Все 4 операции завершены. ===");
                // Не сбрасываем индекс здесь, это будет сделано в начале следующего выполнения ExecuteAsync
            }
            finally
            {
                _isRunningNow = false;
                _currentOperationName = null;
            }
        }

        // ==================================================================
        // ========== 7) ПОДПИСКА НА ПРОГРЕСС ЛОТОВ ==========================
        // ==================================================================
        /// <summary>
        /// Вызывается из realLotFetchingService.ProgressChanged для каждого лота
        /// </summary>
        private void OnLotProgressChanged(int currentLotId, string? currentTitle)
        {
            _processedCount++;

            if (currentLotId != 0)
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

        // ==================================================================
        // ========== 8) МЕТОДЫ УПРАВЛЕНИЯ (Pause/Resume/RunNow) ============
        // ==================================================================
        public void ForcePause()
        {
            if (_isPaused)
            {
                _logger.LogInformation("Сервис уже на паузе");
                return;
            }

            _logger.LogInformation("Паузим сервис (остановка после текущего лота).");
            _isPaused = true;
            _cancellationRequested = true;
        }

        public void ForceResume()
        {
            if (!_isPaused)
            {
                _logger.LogInformation("Сервис и так не на паузе.");
                return;
            }

            _logger.LogInformation("Resume: снимаем паузу. (Не запускаем автоматически — ждём плановый запуск или ForceRunNow.)");
            _isPaused = false;
            _cancellationRequested = false;
        }

        public void ForceRunNow()
        {
            if (_isPaused)
            {
                _logger.LogWarning("Сервис на паузе — сначала сделайте Resume().");
                return;
            }

            // Проверяем, не идёт ли сейчас
            if (_isRunningNow)
            {
                _logger.LogWarning("Уже идёт текущая операция, дождитесь окончания или нажмите Pause().");
                return;
            }

            _logger.LogInformation("ForceRunNow: сбрасываем цепочку и запускаем все операции с нуля.");
            _cancellationRequested = false;
            _currentStepIndex = 0; // начинаем заново с первой операции
            
            // Обновляем время следующего запуска
            _nextRunTimeUtc = DateTime.UtcNow.AddDays(1);
            _logger.LogInformation("Следующий плановый запуск запланирован на {NextRunTimeUtc}", _nextRunTimeUtc);

            // Запускаем в фоне
            var token = new CancellationToken();
            _currentRunTask = RunAllOperationsAsync(token);
            _logger.LogInformation("Запуск операций инициирован принудительно");
        }

        // ==================================================================
        // ========== 9) GETTERS ============================================
        // ==================================================================
        public bool IsPaused
        {
            get => _isPaused;
            set => _isPaused = value;
        }

        public bool IsRunningNow => _isRunningNow;

        public DateTime? LastRunTimeUtc => _lastRunTimeUtc;
        public DateTime? NextRunTimeUtc => _nextRunTimeUtc;
        public bool MissedRunDueToPause => _missedRunDueToPause;

        public string? CurrentOperationName => _currentOperationName;
        public int ProcessedCount => _processedCount;
        public int LastProcessedLotId => _lastProcessedLotId;
        public string? LastProcessedLotTitle => _lastProcessedLotTitle;

        // ==================================================================
        // ========== 10) IProgressReporter реализации ======================
        // ==================================================================
        public void ReportInfo(string message, string? operation = null, int? lotId = null, string? title = null)
        {
            AddLogEntry(new LogEntry
            {
                Timestamp = DateTime.UtcNow,
                Message = message,
                OperationName = operation,
                LotId = lotId,
                LotTitle = title,
                IsError = false
            });
        }

        public void ReportError(Exception ex, string message, string? operation = null, int? lotId = null, string? title = null)
        {
            AddLogEntry(new LogEntry
            {
                Timestamp = DateTime.UtcNow,
                Message = message,
                OperationName = operation,
                LotId = lotId,
                LotTitle = title,
                IsError = true,
                ExceptionMessage = ex.ToString()
            });
        }
    }
}
