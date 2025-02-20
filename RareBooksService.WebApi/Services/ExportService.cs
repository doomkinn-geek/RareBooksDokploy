using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Parsing;
using System.Collections.Concurrent;
using System.Globalization;
using RareBooksService.Data.Parsing;
using Microsoft.Extensions.DependencyInjection;
using System.Threading;
using System.IO.Compression;
using System.Data;
using Microsoft.Data.Sqlite;

namespace RareBooksService.WebApi.Services
{
    public interface IExportService
    {
        Task<Guid> StartExportAsync();
        ExportStatusDto GetStatus(Guid taskId);
        FileInfo GetExportedFile(Guid taskId);
        void CancelExport(Guid taskId);
        void CleanupAllFiles();
    }

    /// <summary>
    /// DTO, который возвращаем при запросе статуса экспорта
    /// </summary>
    public class ExportStatusDto
    {
        public int Progress { get; set; }
        public bool IsError { get; set; }
        public string ErrorDetails { get; set; }
    }

    public class ExportService : IExportService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private static ConcurrentDictionary<Guid, int> _progress = new ConcurrentDictionary<Guid, int>();

        // Храним подробности ошибок в отдельном словаре.
        private static ConcurrentDictionary<Guid, string> _errors = new ConcurrentDictionary<Guid, string>();

        private static ConcurrentDictionary<Guid, string> _files = new ConcurrentDictionary<Guid, string>();
        private static ConcurrentDictionary<Guid, CancellationTokenSource> _cancellationTokens = new ConcurrentDictionary<Guid, CancellationTokenSource>();

        private const int PageSize = 1000; // Число книг за раз
        private readonly ILogger<ExportService> _logger;

        public ExportService(IServiceScopeFactory scopeFactory, ILogger<ExportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        public async Task<Guid> StartExportAsync()
        {
            // Проверяем, нет ли уже запущенной задачи
            bool anyActive = _progress.Values.Any(p => p >= 0 && p < 100);
            if (anyActive)
                throw new InvalidOperationException("Экспорт уже выполняется. Дождитесь завершения или отмените предыдущий экспорт.");

            var taskId = Guid.NewGuid();
            _progress[taskId] = 0;
            // Сбрасываем предыдущие ошибки на случай повторного использования taskId
            _errors[taskId] = string.Empty;

            var cts = new CancellationTokenSource();
            _cancellationTokens[taskId] = cts;

            _ = Task.Run(() => DoExport(taskId, cts.Token));
            return taskId;
        }

        public void CancelExport(Guid taskId)
        {
            if (_cancellationTokens.TryGetValue(taskId, out var cts))
            {
                cts.Cancel();
            }
        }

        public ExportStatusDto GetStatus(Guid taskId)
        {
            // Прогресс
            int progress = -1;
            if (_progress.TryGetValue(taskId, out var p))
                progress = p;

            // Ошибка
            string error = null;
            if (_errors.TryGetValue(taskId, out var err) && !string.IsNullOrEmpty(err))
            {
                // Если там лежит текст ошибки — вернём
                error = err;
            }

            // Собираем DTO
            var dto = new ExportStatusDto
            {
                Progress = progress,
                IsError = (progress == -1),
                ErrorDetails = error
            };
            return dto;
        }

        private async Task DoExport(Guid taskId, CancellationToken token)
        {
            try
            {
                _progress[taskId] = 0;

                using var scope = _scopeFactory.CreateScope();
                var regularContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                int totalBooks = await regularContext.BooksInfo.CountAsync(token);
                if (totalBooks == 0)
                {
                    _progress[taskId] = 100;
                    return;
                }

                token.ThrowIfCancellationRequested();

                // Загружаем все категории (до 50 записей)
                var categories = await regularContext.Categories.OrderBy(c => c.Id).ToListAsync(token);
                token.ThrowIfCancellationRequested();

                // Создадим временную папку
                string tempFolder = Path.Combine(Path.GetTempPath(), $"export_{taskId}");
                if (!Directory.Exists(tempFolder))
                    Directory.CreateDirectory(tempFolder);

                const int chunkSize = 50000;
                int processed = 0;
                int chunkIndex = 0;

                while (processed < totalBooks)
                {
                    token.ThrowIfCancellationRequested();

                    var booksChunk = await regularContext.BooksInfo
                        .OrderBy(b => b.Id)
                        .Skip(processed)
                        .Take(chunkSize)
                        .ToListAsync(token);

                    if (booksChunk.Count == 0) break;

                    chunkIndex++;
                    string chunkDbPath = Path.Combine(tempFolder, $"part_{chunkIndex}.db");
                    if (File.Exists(chunkDbPath)) File.Delete(chunkDbPath);

                    var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                    optionsBuilder.UseSqlite($"Filename={chunkDbPath}");

                    using (var extendedContext = new ExtendedBooksContext(optionsBuilder.Options))
                    {
                        extendedContext.Database.EnsureCreated();
                        extendedContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        // Сохраняем категории
                        extendedContext.Categories.AddRange(
                            categories.Select(c => new ExtendedCategory
                            {
                                CategoryId = c.CategoryId,
                                Name = c.Name
                            })
                        );
                        await extendedContext.SaveChangesAsync(token);

                        // Сопоставим CategoryId => PK
                        var extCats = await extendedContext.Categories.ToListAsync(token);
                        var catMap = extCats.ToDictionary(x => x.CategoryId, x => x.Id);

                        // Добавляем chunk книг
                        extendedContext.BooksInfo.AddRange(
                            booksChunk.Select(b => new ExtendedBookInfo
                            {
                                Id = b.Id,
                                Title = b.Title,
                                Description = b.Description,
                                BeginDate = b.BeginDate,
                                EndDate = b.EndDate,
                                Price = b.Price,
                                FinalPrice = b.FinalPrice,
                                City = b.City,
                                IsMonitored = b.IsMonitored,
                                YearPublished = b.YearPublished,
                                Tags = b.Tags,
                                PicsRatio = b.PicsRatio,
                                Status = b.Status,
                                StartPrice = b.StartPrice,
                                Type = b.Type,
                                SoldQuantity = b.SoldQuantity,
                                BidsCount = b.BidsCount,
                                SellerName = b.SellerName,
                                PicsCount = b.PicsCount,
                                ImageUrls = b.ImageUrls,
                                ThumbnailUrls = b.ThumbnailUrls,
                                IsImagesCompressed = b.IsImagesCompressed,
                                ImageArchiveUrl = b.ImageArchiveUrl,
                                IsLessValuable = b.IsLessValuable,
                                CategoryId = catMap.TryGetValue(b.Category.CategoryId, out var extCatId)
                                    ? extCatId : 0
                            })
                        );

                        await extendedContext.SaveChangesAsync(token);

                        // Закрываем соединения
                        var conn = extendedContext.Database.GetDbConnection();
                        if (conn.State != ConnectionState.Closed)
                            conn.Close();
                    }

                    // Очищаем пулы
                    SqliteConnection.ClearAllPools();
                    // Можно вызвать GC, чтобы форсировать закрытие файлов (редко нужно, но можно):
                    GC.Collect();
                    GC.WaitForPendingFinalizers();

                    processed += booksChunk.Count;
                    int percent = (int)((double)processed / totalBooks * 100);
                    _progress[taskId] = percent;
                }

                // Перед упаковкой подождём чуть-чуть
                await Task.Delay(300, token);

                // Упаковываем всё в zip
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"export_{taskId}.zip");
                if (File.Exists(zipFilePath)) File.Delete(zipFilePath);

                ZipFile.CreateFromDirectory(tempFolder, zipFilePath);

                _files[taskId] = zipFilePath;

                // Удаляем временную папку
                Directory.Delete(tempFolder, true);

                _progress[taskId] = 100;
            }
            catch (OperationCanceledException)
            {
                _progress[taskId] = -1;
                _errors[taskId] = "Экспорт отменён пользователем.";
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Ошибка экспорта");
                // Ставим прогресс -1 и сохраняем текст ошибки
                _progress[taskId] = -1;
                _errors[taskId] = e.ToString(); // или e.Message + e.StackTrace
            }
            finally
            {
                _cancellationTokens.TryRemove(taskId, out _);
            }
        }

        public FileInfo GetExportedFile(Guid taskId)
        {
            if (_files.TryGetValue(taskId, out var filename))
            {
                return new FileInfo(filename);
            }
            return null;
        }

        public void CleanupAllFiles()
        {
            foreach (var kvp in _files)
            {
                var file = kvp.Value;
                if (File.Exists(file))
                {
                    try
                    {
                        File.Delete(file);
                    }
                    catch { }
                }
            }
            _files.Clear();
        }
    }
}
