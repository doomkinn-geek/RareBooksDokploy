using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Parsing;
using System.Collections.Concurrent;
using System.Globalization;
using RareBooksService.Data.Parsing;
using Microsoft.Extensions.DependencyInjection;
using System.Threading;

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

                // Грузим все категории из PostgreSQL
                var categories = await regularContext.Categories.OrderBy(c => c.Id).ToListAsync(token);
                // Дополнительно берём distinct, если может быть дублирование CategoryId
                var distinctCats = categories
                    .GroupBy(cat => cat.CategoryId)
                    .Select(g => g.First())
                    .ToList();

                token.ThrowIfCancellationRequested();

                // Готовим пустой .db-файл
                var sqliteFilename = Path.Combine(Path.GetTempPath(), $"export_{taskId}.db");
                if (File.Exists(sqliteFilename)) File.Delete(sqliteFilename);

                var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                optionsBuilder.UseSqlite($"Filename={sqliteFilename}");

                using var extendedContext = new ExtendedBooksContext(optionsBuilder.Options);
                extendedContext.Database.EnsureCreated();

                // 1) Перенос категорий
                // Отключаем автопроверку изменений, чтобы быстрее вставить
                extendedContext.ChangeTracker.AutoDetectChangesEnabled = false;

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

                // Считываем категории обратно в EF, формируем карту
                // (Можно было бы на лету создавать словарь, но тогда
                // нужно аккуратно работать с PK и навигациями.)
                extendedContext.ChangeTracker.Clear(); // <-- сбрасываем трекер, чтобы не висели объекты категорий

                var extendedCategories = await extendedContext.Categories.ToListAsync(token);
                var catMap = extendedCategories.ToDictionary(c => c.CategoryId, c => c);

                // 2) Перенос книг
                int processed = 0;
                var processedBookIds = new HashSet<int>();  // Если важно не дублировать книги

                // Перебираем все категории (как и раньше)
                foreach (var cat in categories)
                {
                    token.ThrowIfCancellationRequested();

                    if (!catMap.TryGetValue(cat.CategoryId, out var categoryInMap))
                    {
                        // Категория отсутствует (теоретически не должно быть, если мы взяли distinctCats)
                        continue;
                    }

                    int page = 0;
                    while (true)
                    {
                        token.ThrowIfCancellationRequested();

                        var books = await regularContext.BooksInfo
                            .Where(b => b.CategoryId == cat.Id)
                            .OrderBy(b => b.Id)
                            .Skip(page * PageSize)
                            .Take(PageSize)
                            .ToListAsync(token);

                        if (books.Count == 0)
                            break; // следующая категория

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
                                    ImageUrls = book.ImageUrls,
                                    ThumbnailUrls = book.ThumbnailUrls,
                                    Price = book.Price,
                                    City = book.City,
                                    IsMonitored = book.IsMonitored,
                                    FinalPrice = book.FinalPrice,
                                    YearPublished = book.YearPublished,
                                    Tags = book.Tags,
                                    CategoryId = categoryInMap.Id,                                    
                                    PicsRatio = book.PicsRatio,
                                    Status = book.Status,
                                    StartPrice = book.StartPrice,
                                    Type = book.Type,
                                    SoldQuantity = book.SoldQuantity,
                                    BidsCount = book.BidsCount,
                                    SellerName = book.SellerName,
                                    PicsCount = book.PicsCount,
                                    IsImagesCompressed = book.IsImagesCompressed,
                                    ImageArchiveUrl = book.ImageArchiveUrl,
                                    IsLessValuable = book.IsLessValuable
                                };

                                extendedContext.BooksInfo.Add(newBook);
                                processedBookIds.Add(book.Id);
                                processed++;

                                // Каждые 100 добавлений — сохраняем и сбрасываем трекер
                                if (processed % 100 == 0)
                                {
                                    await extendedContext.SaveChangesAsync(token);
                                    extendedContext.ChangeTracker.Clear();

                                    int percent = (int)((double)processed / totalBooks * 100);
                                    _progress[taskId] = percent;
                                }
                            }
                            else
                            {
                                // Уже добавляли такую книгу, пропускаем
                            }
                        }

                        // Сохраняем «хвост» (если в пачке < 100)
                        await extendedContext.SaveChangesAsync(token);
                        extendedContext.ChangeTracker.Clear();

                        page++;
                    }
                }

                // Заключительная стадия
                _progress[taskId] = 100;
                _files[taskId] = sqliteFilename;
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
                // Восстанавливаем флаг автодетекта на всякий случай
                using var scope2 = _scopeFactory.CreateScope();
                using var tmpContext = new ExtendedBooksContext(new DbContextOptionsBuilder<ExtendedBooksContext>()
                    .UseSqlite($"Filename=:memory:") // фиктивно
                    .Options);

                tmpContext.ChangeTracker.AutoDetectChangesEnabled = true;

                _cancellationTokens.TryRemove(taskId, out _);
            }
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
