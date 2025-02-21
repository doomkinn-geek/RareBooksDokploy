using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Interfaces;
using RareBooksService.Common.Models.Parsing;
using RareBooksService.Data;
using RareBooksService.Data.Parsing;
using System.Collections.Concurrent;
using System.Threading;

namespace RareBooksService.WebApi.Services
{
    public interface IImportService
    {
        Guid StartImport();
        void WriteFileChunk(Guid importTaskId, byte[] buffer, int count);
        Task FinishFileUploadAsync(Guid importTaskId);
        ImportProgressDto GetImportProgress(Guid importTaskId);
        void CancelImport(Guid importTaskId);
        void CleanupAllFiles();
    }

    /// <summary>DTO для прогресса импорта</summary>
    public class ImportProgressDto
    {
        public double UploadProgress { get; set; }   // 0..100
        public double ImportProgress { get; set; }   // 0..100
        public bool IsFinished { get; set; }
        public bool IsCancelledOrError { get; set; }
        public string Message { get; set; }
    }

    public class ImportService : IImportService
    {
        private static ConcurrentDictionary<Guid, ImportTaskInfo> _tasks = new ConcurrentDictionary<Guid, ImportTaskInfo>();

        private readonly IServiceScopeFactory _scopeFactory;

        public ImportService(IServiceScopeFactory scopeFactory)
        {
            _scopeFactory = scopeFactory;
        }

        public Guid StartImport()
        {
            var importId = Guid.NewGuid();
            var info = new ImportTaskInfo(importId);
            _tasks[importId] = info;
            return importId;
        }

        public void WriteFileChunk(Guid importTaskId, byte[] buffer, int count)
        {
            if (!_tasks.TryGetValue(importTaskId, out var taskInfo))
                throw new InvalidOperationException("Import task not found.");

            if (taskInfo.IsCompleted)
                throw new InvalidOperationException("Task is already completed or cancelled.");

            taskInfo.FileStream.Write(buffer, 0, count);
            taskInfo.BytesUploaded += count;

            if (taskInfo.ExpectedFileSize > 0)
            {
                taskInfo.UploadProgress = (double)taskInfo.BytesUploaded / taskInfo.ExpectedFileSize * 100.0;
            }
            else
            {
                taskInfo.UploadProgress = -1;
            }
        }

        public async Task FinishFileUploadAsync(Guid importTaskId)
        {
            if (!_tasks.TryGetValue(importTaskId, out var taskInfo))
                throw new InvalidOperationException("Import task not found.");

            // Закроем файл, чтобы он стал полноценным ZIP на диске
            taskInfo.FileStream.Close();
            taskInfo.UploadProgress = 100.0;

            // Запускаем импорт в фоне
            _ = Task.Run(() => ImportInBackgroundAsync(taskInfo));
        }

        private async Task ImportInBackgroundAsync(ImportTaskInfo taskInfo)
        {
            try
            {
                // 1) Распакуем ZIP во временную папку
                string importFolder = Path.Combine(Path.GetTempPath(), $"import_{taskInfo.ImportTaskId}");
                if (Directory.Exists(importFolder))
                    Directory.Delete(importFolder, true);
                Directory.CreateDirectory(importFolder);

                // Извлекаем все part_*.db
                System.IO.Compression.ZipFile.ExtractToDirectory(taskInfo.TempFilePath, importFolder);
                var chunkFiles = Directory.GetFiles(importFolder, "part_*.db");

                // Подсчитываем общее количество книг (для прогресса)
                long totalBooksCount = 0;
                foreach (var chunkFile in chunkFiles)
                {
                    var sqliteOptions = new DbContextOptionsBuilder<ExtendedBooksContext>()
                        .UseSqlite($"Filename={chunkFile}")
                        .Options;

                    using var srcContext = new ExtendedBooksContext(sqliteOptions);
                    long cnt = await srcContext.BooksInfo.LongCountAsync();
                    totalBooksCount += cnt;
                }

                long processed = 0;

                // 2) Идём по всем chunk’ам
                foreach (var chunkFile in chunkFiles.OrderBy(x => x))
                {
                    var sqliteOptions = new DbContextOptionsBuilder<ExtendedBooksContext>()
                        .UseSqlite($"Filename={chunkFile}")
                        .Options;

                    using var srcContext = new ExtendedBooksContext(sqliteOptions)
                    {
                        // Необязательно, но можно отключить TrackChanges
                        ChangeTracker = { AutoDetectChangesEnabled = false }
                    };

                    // ======================= Шаг 2.1: Категории =========================
                    // Считываем категории из chunk-файла. У каждой будет .Id (локальный PK) и .CategoryId (meshok.net)
                    var chunkCategories = await srcContext.Categories
                        .AsNoTracking()
                        .ToListAsync();

                    using (var scope = _scopeFactory.CreateScope())
                    {
                        var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                        pgContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        // 2.1.1) Upsert категорий в PG (по Meshok.net-ID = cat.CategoryId)
                        foreach (var cat in chunkCategories)
                        {
                            // Ищем в PG запись с таким же CategoryId (у нас в PG это поле — "CategoryId" на meshok.net)
                            var existingCat = await pgContext.Categories
                                .FirstOrDefaultAsync(c => c.CategoryId == cat.CategoryId);

                            if (existingCat == null)
                            {
                                // Добавляем новую
                                var newCat = new RegularBaseCategory
                                {
                                    CategoryId = cat.CategoryId,  // meshok ID
                                    Name = cat.Name
                                };
                                pgContext.Categories.Add(newCat);
                            }
                            else
                            {
                                // Обновляем уже имеющуюся
                                existingCat.Name = cat.Name;
                            }
                        }
                        await pgContext.SaveChangesAsync();

                        // 2.1.2) Собираем словарь "chunkCategory.Id => pgCategory.Id"
                        //        Т.е. локальный PK => реальный PK в PG
                        var meshokIds = chunkCategories.Select(c => c.CategoryId).Distinct().ToList();
                        var realPgCategories = await pgContext.Categories
                            .Where(x => meshokIds.Contains(x.CategoryId))
                            .ToListAsync();

                        var catMap = new Dictionary<int, int>();
                        // Идём параллельно по chunkCategories
                        // chunkCat.Id = локальный PK, chunkCat.CategoryId = meshok ID
                        // Ищем реальный pgCat.Id, у которого (pgCat.CategoryId == chunkCat.CategoryId)
                        foreach (var chunkCat in chunkCategories)
                        {
                            var pgCat = realPgCategories.FirstOrDefault(x => x.CategoryId == chunkCat.CategoryId);
                            if (pgCat != null)
                            {
                                catMap[chunkCat.Id] = pgCat.Id;
                            }
                        }

                        // ======================= Шаг 2.2: Книги =========================
                        // Поскольку книг может быть много, обрабатываем их постранично
                        int pageSize = 2000;
                        int pageIndex = 0;

                        while (true)
                        {
                            var chunkBooks = await srcContext.BooksInfo
                                .AsNoTracking()
                                .OrderBy(b => b.Id)
                                .Skip(pageIndex * pageSize)
                                .Take(pageSize)
                                .ToListAsync();

                            if (chunkBooks.Count == 0) break;

                            // Upsert книг в PostgreSQL
                            foreach (var book in chunkBooks)
                            {
                                // В chunk-файле book.CategoryId = локальный PK категории
                                // Сопоставляем его к реальному PG-Id
                                if (!catMap.TryGetValue(book.CategoryId, out int realPgCatId))
                                {
                                    // Не нашли в словаре => пропускаем книгу или привязываем к "заглушке"
                                    continue;
                                }

                                // Ищем книгу по её Id (предполагая, что он уникален между chunk’ами)
                                var existingBook = await pgContext.BooksInfo
                                    .FirstOrDefaultAsync(b => b.Id == book.Id);

                                if (existingBook == null)
                                {
                                    // Создаём новую запись
                                    var newBook = new RegularBaseBook
                                    {
                                        Id = book.Id,
                                        Title = book.Title,
                                        NormalizedTitle = book.Title.ToLowerInvariant(),
                                        Description = book.Description,
                                        NormalizedDescription = book.Description.ToLowerInvariant(),
                                        BeginDate = DateTime.SpecifyKind(book.BeginDate, DateTimeKind.Utc),
                                        EndDate = DateTime.SpecifyKind(book.EndDate, DateTimeKind.Utc),
                                        ImageUrls = book.ImageUrls,
                                        ThumbnailUrls = book.ThumbnailUrls,
                                        Price = book.Price,
                                        City = book.City,
                                        IsMonitored = book.IsMonitored,
                                        FinalPrice = book.FinalPrice,
                                        YearPublished = book.YearPublished,
                                        // ВАЖНО: тут пишем реальный PK категории
                                        CategoryId = realPgCatId,

                                        Tags = book.Tags,
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
                                    pgContext.BooksInfo.Add(newBook);
                                }
                                else
                                {
                                    // Обновляем
                                    existingBook.Title = book.Title;
                                    existingBook.NormalizedTitle = book.Title.ToLowerInvariant();
                                    existingBook.Description = book.Description;
                                    existingBook.NormalizedDescription = book.Description.ToLowerInvariant();
                                    existingBook.BeginDate = DateTime.SpecifyKind(book.BeginDate, DateTimeKind.Utc);
                                    existingBook.EndDate = DateTime.SpecifyKind(book.EndDate, DateTimeKind.Utc);
                                    existingBook.ImageUrls = book.ImageUrls;
                                    existingBook.ThumbnailUrls = book.ThumbnailUrls;
                                    existingBook.Price = book.Price;
                                    existingBook.City = book.City;
                                    existingBook.IsMonitored = book.IsMonitored;
                                    existingBook.FinalPrice = book.FinalPrice;
                                    existingBook.YearPublished = book.YearPublished;
                                    // Снова ВАЖНО: реальный PK
                                    existingBook.CategoryId = realPgCatId;

                                    existingBook.Tags = book.Tags;
                                    existingBook.PicsRatio = book.PicsRatio;
                                    existingBook.Status = book.Status;
                                    existingBook.StartPrice = book.StartPrice;
                                    existingBook.Type = book.Type;
                                    existingBook.SoldQuantity = book.SoldQuantity;
                                    existingBook.BidsCount = book.BidsCount;
                                    existingBook.SellerName = book.SellerName;
                                    existingBook.PicsCount = book.PicsCount;
                                    existingBook.IsImagesCompressed = book.IsImagesCompressed;
                                    existingBook.ImageArchiveUrl = book.ImageArchiveUrl;
                                    existingBook.IsLessValuable = book.IsLessValuable;
                                }
                            }

                            await pgContext.SaveChangesAsync();

                            processed += chunkBooks.Count;
                            taskInfo.ImportProgress = (double)processed / totalBooksCount * 100.0;

                            pageIndex++;
                        }
                    }

                    // Закрываем SQLite для данного chunk
                    SqliteConnection.ClearAllPools();
                }

                // Закончили все chunks
                taskInfo.ImportProgress = 100.0;
                taskInfo.IsCompleted = true;
                taskInfo.Message = $"Imported/Updated {processed} books total.";

                // Удалим временную папку
                Directory.Delete(importFolder, true);
            }
            catch (Exception ex)
            {
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Error: {ex.Message} {ex.InnerException?.Message}";
            }
        }


        public ImportProgressDto GetImportProgress(Guid importTaskId)
        {
            if (!_tasks.TryGetValue(importTaskId, out var info))
            {
                return new ImportProgressDto
                {
                    IsCancelledOrError = true,
                    Message = "Task not found"
                };
            }

            return new ImportProgressDto
            {
                UploadProgress = info.UploadProgress,
                ImportProgress = info.ImportProgress,
                IsFinished = info.IsCompleted,
                IsCancelledOrError = info.IsCancelledOrError,
                Message = info.Message
            };
        }

        public void CancelImport(Guid importTaskId)
        {
            if (_tasks.TryGetValue(importTaskId, out var info))
            {
                info.IsCancelledOrError = true;
                info.Message = "Cancelled by user";
                info.IsCompleted = true;
            }
        }

        public void CleanupAllFiles()
        {
            foreach (var kvp in _tasks)
            {
                var info = kvp.Value;
                try
                {
                    if (File.Exists(info.TempFilePath))
                    {
                        File.Delete(info.TempFilePath);
                    }
                }
                catch { }

                _tasks.TryRemove(kvp.Key, out _);
            }
        }

        private class ImportTaskInfo
        {
            public ImportTaskInfo(Guid id)
            {
                ImportTaskId = id;
                TempFilePath = Path.Combine(Path.GetTempPath(), $"import_{id}.db");
                FileStream = File.OpenWrite(TempFilePath);
            }
            public Guid ImportTaskId { get; }
            public FileStream FileStream { get; }
            public string TempFilePath { get; }
            public long ExpectedFileSize { get; set; } = 0;

            public long BytesUploaded { get; set; } = 0;
            public double UploadProgress { get; set; } = 0.0;
            public double ImportProgress { get; set; } = 0.0;

            public bool IsCompleted { get; set; } = false;
            public bool IsCancelledOrError { get; set; } = false;
            public string Message { get; set; } = "";
        }
    }
}
