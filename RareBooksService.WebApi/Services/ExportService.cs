using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Parsing;
using System.Collections.Concurrent;
using RareBooksService.Data.Parsing;
using Microsoft.Extensions.DependencyInjection;
using System.IO.Compression;
using Microsoft.Data.Sqlite;
using System.Data;

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
        public int Progress { get; set; }      // 0..100 или -1 при ошибке/отмене
        public bool IsError { get; set; }
        public string ErrorDetails { get; set; }
    }

    public class ExportService : IExportService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<ExportService> _logger;

        // Словари для хранения состояния экспорта:
        private static ConcurrentDictionary<Guid, int> _progress = new ConcurrentDictionary<Guid, int>();
        private static ConcurrentDictionary<Guid, string> _errors = new ConcurrentDictionary<Guid, string>();
        private static ConcurrentDictionary<Guid, string> _files = new ConcurrentDictionary<Guid, string>();
        private static ConcurrentDictionary<Guid, CancellationTokenSource> _cancellationTokens = new ConcurrentDictionary<Guid, CancellationTokenSource>();

        // Уменьшаем chunkSize для снижения пикового потребления памяти
        private const int ChunkSize = 20000;

        public ExportService(IServiceScopeFactory scopeFactory, ILogger<ExportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        /// <summary>Запуск экспорта</summary>
        public async Task<Guid> StartExportAsync()
        {
            // Проверка: не идёт ли уже экспорт
            bool anyActive = _progress.Values.Any(p => p >= 0 && p < 100);
            if (anyActive)
                throw new InvalidOperationException("Экспорт уже выполняется. Дождитесь завершения или отмените предыдущий экспорт.");

            var taskId = Guid.NewGuid();
            _progress[taskId] = 0;
            _errors[taskId] = string.Empty;

            var cts = new CancellationTokenSource();
            _cancellationTokens[taskId] = cts;

            // Запускаем DoExport в фоновом потоке
            _ = Task.Run(() => DoExport(taskId, cts.Token));
            return taskId;
        }

        public ExportStatusDto GetStatus(Guid taskId)
        {
            int progress = -1;
            if (_progress.TryGetValue(taskId, out var p))
                progress = p;

            string errorDetails = null;
            if (_errors.TryGetValue(taskId, out var err) && !string.IsNullOrEmpty(err))
            {
                errorDetails = err;
            }

            return new ExportStatusDto
            {
                Progress = progress,
                IsError = (progress == -1),
                ErrorDetails = errorDetails
            };
        }

        public FileInfo GetExportedFile(Guid taskId)
        {
            if (_files.TryGetValue(taskId, out var path))
            {
                return new FileInfo(path);
            }
            return null;
        }

        public void CancelExport(Guid taskId)
        {
            if (_cancellationTokens.TryGetValue(taskId, out var cts))
            {
                cts.Cancel();  // попросим прервать DoExport
            }
        }

        public void CleanupAllFiles()
        {
            // Удаляем все сохранённые zip-файлы
            foreach (var kvp in _files)
            {
                var file = kvp.Value;
                if (File.Exists(file))
                {
                    try
                    {
                        File.Delete(file);
                    }
                    catch { /* ignore */ }
                }
            }
            _files.Clear();
        }

        /// <summary>
        /// Основная логика экспорта
        /// </summary>
        private async Task DoExport(Guid taskId, CancellationToken token)
        {
            try
            {
                _progress[taskId] = 0;

                using var scope = _scopeFactory.CreateScope();
                var regularContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                // Сколько всего книг
                int totalBooks = await regularContext.BooksInfo.CountAsync(token);
                if (totalBooks == 0)
                {
                    // Нечего экспортировать
                    _progress[taskId] = 100;
                    return;
                }

                token.ThrowIfCancellationRequested();

                // Загружаем все категории полностью (небольшая таблица)
                var categories = await regularContext.Categories
                    .OrderBy(c => c.Id)
                    .AsNoTracking()
                    .ToListAsync(token);

                token.ThrowIfCancellationRequested();

                // Создадим временную папку для частей
                string tempFolder = Path.Combine(Path.GetTempPath(), $"export_{taskId}");
                if (!Directory.Exists(tempFolder))
                    Directory.CreateDirectory(tempFolder);

                int processed = 0;
                int chunkIndex = 0;

                // Цикл по порциям книг
                while (processed < totalBooks)
                {
                    token.ThrowIfCancellationRequested();

                    // Выбираем очередной кусок (chunk) книг
                    var booksChunk = await regularContext.BooksInfo
                        .OrderBy(b => b.Id)
                        .Skip(processed)
                        .Take(ChunkSize)
                        // Чтобы EF не держал в памяти трекер, уменьшая расход RAM
                        .AsNoTracking()
                        .ToListAsync(token);

                    if (booksChunk.Count == 0) break;

                    chunkIndex++;
                    string chunkDbPath = Path.Combine(tempFolder, $"part_{chunkIndex}.db");
                    if (File.Exists(chunkDbPath))
                        File.Delete(chunkDbPath);

                    // Для текущего chunk создаём отдельную SQLite-базу
                    var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                    optionsBuilder.UseSqlite($"Filename={chunkDbPath}");

                    using (var extendedContext = new ExtendedBooksContext(optionsBuilder.Options))
                    {
                        // Создаём таблицы
                        extendedContext.Database.EnsureCreated();
                        // Отключим лишний трекинг
                        extendedContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        // 1) Запишем ПОЛНУЮ таблицу Categories
                        extendedContext.Categories.AddRange(
                            categories.Select(c => new ExtendedCategory
                            {
                                CategoryId = c.CategoryId,
                                Name = c.Name
                            })
                        );
                        await extendedContext.SaveChangesAsync(token);

                        // 2) Запишем книги этого chunk
                        // Заметьте: теперь CategoryId мы берём напрямую, без catMap
                        // (предполагается, что BookInfo.CategoryId не null).
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

                                // Ключевой момент: используем поля BookInfo.CategoryId
                                // Если оно может быть null, сделайте, напр. b.CategoryId ?? 0
                                CategoryId = b.CategoryId
                            })
                        );
                        await extendedContext.SaveChangesAsync(token);

                        // Закрываем соединения, освобождаем файл
                        var conn = extendedContext.Database.GetDbConnection();
                        if (conn.State != ConnectionState.Closed)
                            conn.Close();
                    }

                    // После формирования chunk.db – освобождаем connection pool
                    SqliteConnection.ClearAllPools();

                    processed += booksChunk.Count;

                    // Обновляем прогресс (0..90%, остальное — упаковка)
                    int percent = (int)((double)processed / totalBooks * 90);
                    _progress[taskId] = percent;
                }

                // Небольшая пауза, чтобы гарантировать освобождение файлов
                await Task.Delay(300, token);

                // ====== Упаковка =====
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"export_{taskId}.zip");
                if (File.Exists(zipFilePath))
                    File.Delete(zipFilePath);

                // Создаём ZIP из tempFolder
                ZipFile.CreateFromDirectory(tempFolder, zipFilePath);

                // Сохраняем файл в словарь
                _files[taskId] = zipFilePath;

                // Удаляем временную папку с chunk*.db
                Directory.Delete(tempFolder, true);

                // 100% – готово
                _progress[taskId] = 100;
            }
            catch (OperationCanceledException)
            {
                _progress[taskId] = -1;
                _errors[taskId] = "Экспорт отменён пользователем.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка экспорта");
                _progress[taskId] = -1;
                _errors[taskId] = ex.ToString(); // или ex.Message + ex.StackTrace
            }
            finally
            {
                // Убираем задачу из словаря
                _cancellationTokens.TryRemove(taskId, out _);
            }
        }
    }
}
