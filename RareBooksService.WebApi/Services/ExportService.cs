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
        int GetProgress(Guid taskId);
        FileInfo GetExportedFile(Guid taskId);
        void CancelExport(Guid taskId);
        void CleanupAllFiles();
    }

    public class ExportService : IExportService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private static ConcurrentDictionary<Guid, int> _progress = new ConcurrentDictionary<Guid, int>();
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
            // Задача считается незавершенной, если ее прогресс не -1 и не 100
            bool anyActive = _progress.Values.Any(p => p >= 0 && p < 100);
            if (anyActive)
            {
                throw new InvalidOperationException("Экспорт уже выполняется. Дождитесь завершения или отмените предыдущий экспорт.");
            }

            var taskId = Guid.NewGuid();
            _progress[taskId] = 0;
            var cts = new CancellationTokenSource();
            _cancellationTokens[taskId] = cts;

            // Запускаем таск в фоне
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

        /*private async Task DoExport(Guid taskId, CancellationToken token)
        {
            try
            {
                _progress[taskId] = 0;
                using var scope = _scopeFactory.CreateScope();
                var regularContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                int totalBooks = await regularContext.BooksInfo.CountAsync(token);    
                //int totalBooks = 10000;
                if (totalBooks == 0)
                {
                    _progress[taskId] = 100;
                    return;
                }

                token.ThrowIfCancellationRequested();

                var categories = await regularContext.Categories.OrderBy(c => c.Id).ToListAsync(token);

                var distinctCats = categories
                    .GroupBy(cat => cat.CategoryId)
                    .Select(g => g.First())
                    .ToList();

                token.ThrowIfCancellationRequested();

                var tempPath = Path.GetTempFileName();
                File.Delete(tempPath);
                var sqliteFilename = Path.Combine(Path.GetTempPath(), $"export_{taskId}.db");
                if (File.Exists(sqliteFilename)) File.Delete(sqliteFilename);

                var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                optionsBuilder.UseSqlite($"Filename={sqliteFilename}");

                using var extendedContext = new ExtendedBooksContext(optionsBuilder.Options);
                extendedContext.Database.EnsureCreated();

                // Переносим категории
                foreach (var cat in distinctCats)
                {
                    token.ThrowIfCancellationRequested();
                    var newCat = new ExtendedCategory
                    {
                        CategoryId = cat.CategoryId,
                        Name = cat.Name
                    };
                    extendedContext.Categories.Add(newCat);
                }
                await extendedContext.SaveChangesAsync(token);

                var extendedCategories = await extendedContext.Categories.ToListAsync(token);
                var catMap = extendedCategories.ToDictionary(c => c.CategoryId, c => c);

                int processed = 0;

                var processedBookIds = new HashSet<int>();

                foreach (var cat in categories)
                {
                    token.ThrowIfCancellationRequested();

                    if (!catMap.TryGetValue(cat.CategoryId, out var categoryInMap))
                    {
                        // Категория отсутствует в карте (если такое возможно?)
                        continue;
                    }

                    int page = 0;
                    while (true)
                    {
                        token.ThrowIfCancellationRequested();
                        //if (processed > totalBooks)
                        //{
                        //    break;
                        //}

                        var books = await regularContext.BooksInfo
                            .Where(b => b.CategoryId == cat.Id)
                            .OrderBy(b => b.Id)
                            .Skip(page * PageSize)
                            .Take(PageSize)
                            .ToListAsync(token);

                        if (books.Count == 0) break;

                        foreach (var book in books)
                        {
                            token.ThrowIfCancellationRequested();

                            if (!processedBookIds.Contains(book.Id))
                            {
                                var newBook = new ExtendedBookInfo
                                {
                                    Id = book.Id,
                                    Title = book.Title,
                                    Description = book.Description,
                                    BeginDate = book.BeginDate,
                                    EndDate = book.EndDate,
                                    Price = book.Price,
                                    City = book.City,
                                    IsMonitored = book.IsMonitored,
                                    FinalPrice = book.FinalPrice,
                                    YearPublished = book.YearPublished,
                                    CategoryId = categoryInMap.Id,
                                    Tags = book.Tags,
                                    PicsRatio = book.PicsRatio,
                                    Status = book.Status,
                                    StartPrice = book.StartPrice,
                                    Type = book.Type,
                                    SoldQuantity = book.SoldQuantity,
                                    BidsCount = book.BidsCount,
                                    SellerName = book.SellerName,
                                    PicsCount = book.PicsCount,
                                    ImageUrls = book.ImageUrls,
                                    ThumbnailUrls = book.ThumbnailUrls,

                                    //08.11.2024 - добавил поддержку малоценных лотов (советские до 1500) и сжатие изображений в object storage
                                    IsImagesCompressed = book.IsImagesCompressed,
                                    ImageArchiveUrl = book.ImageArchiveUrl,

                                    //22.01.2025 - т.к. малоценных лотов очень много, храним их без загрузки изображений
                                    //изображения будем получать по тем ссылкам, что есть на мешке
                                    IsLessValuable = book.IsLessValuable
                                };

                                extendedContext.BooksInfo.Add(newBook);
                                processedBookIds.Add(book.Id);
                                processed++;

                                if (processed % 100 == 0)
                                {
                                    await extendedContext.SaveChangesAsync(token);
                                    int percent = (int)((double)processed / totalBooks * 100);
                                    _progress[taskId] = percent;
                                }                                
                            }
                            else
                            {
                                // Уже добавляли такую книгу, пропускаем
                            }
                        }

                        await extendedContext.SaveChangesAsync(token);

                        //Это сбрасывает локальное отслеживание сущностей и позволяет отработать сборщику мусора
                        regularContext.ChangeTracker.Clear();
                        page++;
                        
                    }
                }

                // Завершаем
                _progress[taskId] = 100;
                _files[taskId] = sqliteFilename;
            }
            catch (OperationCanceledException)
            {
                _progress[taskId] = -1;
            }
            catch
            {
                _progress[taskId] = -1;
            }
            finally
            {
                _cancellationTokens.TryRemove(taskId, out _);
            }
        }*/

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

                // Загружаем все категории (до 50 записей), которые включим в каждую часть
                var categories = await regularContext.Categories.OrderBy(c => c.Id).ToListAsync(token);

                token.ThrowIfCancellationRequested();

                // Создадим временную папку для хранения chunk-файлов .db
                string tempFolder = Path.Combine(Path.GetTempPath(), $"export_{taskId}");
                if (!Directory.Exists(tempFolder))
                    Directory.CreateDirectory(tempFolder);

                // Число книг на одну часть
                const int chunkSize = 50000;
                int processed = 0;
                int chunkIndex = 0;

                // Будем бежать по всем книгам
                while (processed < totalBooks)
                {
                    token.ThrowIfCancellationRequested();

                    var booksChunk = await regularContext.BooksInfo
                        .OrderBy(b => b.Id)
                        .Skip(processed)
                        .Take(chunkSize)
                        .ToListAsync(token);

                    if (booksChunk.Count == 0)
                        break;

                    // Создаём отдельный файл SQLite для каждой части
                    chunkIndex++;
                    string chunkDbPath = Path.Combine(tempFolder, $"part_{chunkIndex}.db");
                    if (File.Exists(chunkDbPath)) File.Delete(chunkDbPath);

                    var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                    optionsBuilder.UseSqlite($"Filename={chunkDbPath}");

                    using (var extendedContext = new ExtendedBooksContext(optionsBuilder.Options))
                    {
                        extendedContext.Database.EnsureCreated();
                        // Отключаем автодетект изменений для ускорения вставок
                        extendedContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        // 1) Добавляем все категории
                        extendedContext.Categories.AddRange(
                            categories.Select(c => new ExtendedCategory
                            {
                                CategoryId = c.CategoryId,
                                Name = c.Name
                            })
                        );
                        await extendedContext.SaveChangesAsync(token);

                        // Снова читаем список категорий из SQLite, чтобы иметь корректные PK
                        var extCats = await extendedContext.Categories.ToListAsync(token);
                        var catMap = extCats.ToDictionary(x => x.CategoryId, x => x.Id);

                        // 2) Добавляем chunk книг
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
                                // Подставим FK категории
                                CategoryId = catMap.TryGetValue(
                                    b.Category.CategoryId,
                                    out var extCatId)
                                    ? extCatId
                                    : 0
                            })
                        );

                        await extendedContext.SaveChangesAsync(token);

                        var conn = extendedContext.Database.GetDbConnection();
                        if (conn.State != ConnectionState.Closed)
                            conn.Close();

                        SqliteConnection.ClearAllPools();
                        GC.Collect();
                        GC.WaitForPendingFinalizers();
                    }

                    processed += booksChunk.Count;

                    // Обновим прогресс
                    int percent = (int)((double)processed / totalBooks * 100);
                    _progress[taskId] = percent;
                }

                await Task.Delay(500);

                // Все части сформированы в tempFolder
                // Упаковываем всё в один zip
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"export_{taskId}.zip");
                if (File.Exists(zipFilePath))
                    File.Delete(zipFilePath);

                System.IO.Compression.ZipFile.CreateFromDirectory(tempFolder, zipFilePath);

                // Сохраняем путь к итоговому архиву
                _files[taskId] = zipFilePath;

                // Удаляем временную папку
                Directory.Delete(tempFolder, true);

                // Завершаем
                _progress[taskId] = 100;
            }
            catch (OperationCanceledException)
            {
                _progress[taskId] = -1;
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Ошибка экспорта");
                _progress[taskId] = -1;
            }
            finally
            {
                _cancellationTokens.TryRemove(taskId, out _);
            }
        }



        // Аналогичная проверка, как в ImportInBackgroundAsync, только для SQLite.
        // Если вы используете ту же базу (PostgreSQL), смотрите код из ImportService.
        private bool IsDuplicateKeyException(DbUpdateException ex)
        {
            if (ex.InnerException is Microsoft.Data.Sqlite.SqliteException sqliteEx)
            {
                // SQLITE_CONSTRAINT обычно имеет код 19
                if (sqliteEx.SqliteErrorCode == 19)
                {
                    return true;
                }
            }
            return false;
        }





        public int GetProgress(Guid taskId)
        {
            if (_progress.TryGetValue(taskId, out var p))
                return p;
            return -1;
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
