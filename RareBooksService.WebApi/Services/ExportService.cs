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

        // Прогресс (0..100 или -1 при ошибке/отмене)
        private static ConcurrentDictionary<Guid, int> _progress = new ConcurrentDictionary<Guid, int>();
        // Детальный текст ошибки при -1
        private static ConcurrentDictionary<Guid, string> _errors = new ConcurrentDictionary<Guid, string>();
        // Путь к готовому ZIP‐файлу
        private static ConcurrentDictionary<Guid, string> _files = new ConcurrentDictionary<Guid, string>();
        // Для отмены (CancelExport)
        private static ConcurrentDictionary<Guid, CancellationTokenSource> _cancellationTokens = new ConcurrentDictionary<Guid, CancellationTokenSource>();

        private readonly ILogger<ExportService> _logger;

        // Можно сократить, чтобы не загружать в память за раз 50 000 записей
        private const int ChunkSize = 20000;

        public ExportService(IServiceScopeFactory scopeFactory, ILogger<ExportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        public async Task<Guid> StartExportAsync()
        {
            // Проверяем, нет ли уже запущенной задачи (у которой Progress между 0 и 99)
            bool anyActive = _progress.Values.Any(p => p >= 0 && p < 100);
            if (anyActive)
                throw new InvalidOperationException("Экспорт уже выполняется. Дождитесь завершения или отмените предыдущий экспорт.");

            // Генерируем новую задачу
            var taskId = Guid.NewGuid();
            _progress[taskId] = 0;
            _errors[taskId] = string.Empty;

            // Создаём CancellationToken
            var cts = new CancellationTokenSource();
            _cancellationTokens[taskId] = cts;

            // Запускаем экспорт в фоновом потоке
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
            int progress = -1;
            if (_progress.TryGetValue(taskId, out var p))
                progress = p;

            string error = null;
            if (_errors.TryGetValue(taskId, out var err) && !string.IsNullOrEmpty(err))
                error = err;

            return new ExportStatusDto
            {
                Progress = progress,
                IsError = (progress == -1),
                ErrorDetails = error
            };
        }

        private async Task DoExport(Guid taskId, CancellationToken token)
        {
            try
            {
                // Изначальный прогресс = 0
                _progress[taskId] = 0;

                // Готовим общий ZIP‐файл сразу
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"export_{taskId}.zip");
                if (File.Exists(zipFilePath)) File.Delete(zipFilePath);

                // Открываем ZIP в режиме создания (будем добавлять chunk.db по очереди)
                using (var zipArchive = ZipFile.Open(zipFilePath, ZipArchiveMode.Create))
                {
                    using var scope = _scopeFactory.CreateScope();
                    var regularContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                    // Считаем, сколько всего книг
                    int totalBooks = await regularContext.BooksInfo.CountAsync(token);
                    if (totalBooks == 0)
                    {
                        // Если книг нет — просто выставим прогресс = 100 и всё
                        _progress[taskId] = 100;
                        // Запишем пустой ZIP (без файлов)
                        _files[taskId] = zipFilePath;
                        return;
                    }

                    token.ThrowIfCancellationRequested();

                    // Загружаем все категории
                    var categories = await regularContext.Categories
                        .OrderBy(c => c.Id)
                        .ToListAsync(token);

                    token.ThrowIfCancellationRequested();

                    // Готовим временную папку
                    string tempFolder = Path.Combine(Path.GetTempPath(), $"export_{taskId}");
                    if (!Directory.Exists(tempFolder))
                        Directory.CreateDirectory(tempFolder);

                    int processed = 0;
                    int chunkIndex = 0;

                    // Пока не выгрузим все книги
                    while (processed < totalBooks)
                    {
                        token.ThrowIfCancellationRequested();

                        // Загружаем следующую порцию
                        var booksChunk = await regularContext.BooksInfo
                            .OrderBy(b => b.Id)
                            .Skip(processed)
                            .Take(ChunkSize)
                            .AsNoTracking()           // чтобы EF меньше держал в памяти
                            .ToListAsync(token);

                        if (booksChunk.Count == 0) break;

                        chunkIndex++;
                        string chunkDbPath = Path.Combine(tempFolder, $"part_{chunkIndex}.db");
                        if (File.Exists(chunkDbPath)) File.Delete(chunkDbPath);

                        // Создаём локальный SQLite‐контекст
                        var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                        optionsBuilder.UseSqlite($"Filename={chunkDbPath}");

                        using (var extendedContext = new ExtendedBooksContext(optionsBuilder.Options))
                        {
                            // Создаём таблицы
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

                            // Построим словарь сопоставлений CategoryId => PK
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
                                    // Находим PK созданной категории
                                    CategoryId = catMap.TryGetValue(
                                        b.Category.CategoryId, out var extCatId
                                    ) ? extCatId : 0
                                })
                            );

                            await extendedContext.SaveChangesAsync(token);

                            // Закрываем соединения, чтобы освободить файл
                            var conn = extendedContext.Database.GetDbConnection();
                            if (conn.State != ConnectionState.Closed)
                                conn.Close();
                        }

                        // Очистка пулов Sqlite
                        SqliteConnection.ClearAllPools();

                        processed += booksChunk.Count;

                        // Обновляем прогресс (0..90) на этапе выгрузки
                        int percentLoad = (int)((double)processed / totalBooks * 90);
                        _progress[taskId] = percentLoad;

                        // === Добавим этот chunk.db в уже открытый zipArchive ===
                        token.ThrowIfCancellationRequested();

                        zipArchive.CreateEntryFromFile(
                            chunkDbPath,
                            Path.GetFileName(chunkDbPath),
                            CompressionLevel.Optimal
                        );

                        // Удаляем chunk.db c диска — он уже в ZIP
                        File.Delete(chunkDbPath);
                        booksChunk.Clear(); // на всякий случай, чтобы быстрее освободилось
                    }

                    // Закрываем временную папку (она может быть пуста, но на всякий случай удалим)
                    if (Directory.Exists(tempFolder))
                    {
                        Directory.Delete(tempFolder, true);
                    }

                    // Выгрузка всех порций книг закончена — мы всё добавили в zipArchive
                    // zipArchive.Dispose() произойдёт после выхода из using

                    // Поднимем прогресс ближе к 100%,
                    // возможно, есть ещё мелкие завершающие операции, но уже фактически всё готово
                    _progress[taskId] = 95;

                    // Если есть что-то ещё, например, запись метаданных, можно сделать здесь ...
                    // ...
                }

                // Всё, архив готов.
                _files[taskId] = zipFilePath;
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
                _progress[taskId] = -1;
                // Запишем в _errors полный текст стека
                _errors[taskId] = e.ToString();
            }
            finally
            {
                _cancellationTokens.TryRemove(taskId, out _);
            }
        }

        // Возвращаем готовый ZIP (или null, если не найден)
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
            // Удалим все ZIP‐файлы, которые мы сохранили в _files
            foreach (var kvp in _files)
            {
                var file = kvp.Value;
                if (File.Exists(file))
                {
                    try
                    {
                        File.Delete(file);
                    }
                    catch
                    {
                        // Игнорируем ошибки удаления
                    }
                }
            }
            _files.Clear();
        }
    }
}
