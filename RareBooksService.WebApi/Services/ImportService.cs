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
        /// <summary>
        /// Инициирует загрузку и импорт файла SQLite.
        /// </summary>
        /// <returns>Идентификатор задачи импорта.</returns>
        Guid StartImport();

        /// <summary>
        /// Записывает часть файла для указанного importTaskId.
        /// </summary>
        /// <param name="importTaskId"></param>
        /// <param name="buffer"></param>
        /// <param name="count"></param>
        void WriteFileChunk(Guid importTaskId, byte[] buffer, int count);

        /// <summary>
        /// Завершить загрузку файла и запустить процесс импорта в фоне.
        /// </summary>
        Task FinishFileUploadAsync(Guid importTaskId);

        /// <summary>
        /// Получить текущее состояние задачи импорта.
        /// </summary>
        ImportProgressDto GetImportProgress(Guid importTaskId);

        /// <summary>
        /// Отменить задачу импорта (если поддерживается).
        /// </summary>
        void CancelImport(Guid importTaskId);
    }

    /// <summary>
    /// DTO для возвращения прогресса
    /// </summary>
    public class ImportProgressDto
    {
        public double UploadProgress { get; set; }   // 0..100
        public double ImportProgress { get; set; }   // 0..100
        public bool IsFinished { get; set; }         // true, если импорт завершён
        public bool IsCancelledOrError { get; set; } // true, если задача упала или отменена
        public string Message { get; set; }          // Доп. сообщение
    }

    public class ImportService : IImportService
    {
        // Храним данные о задачах в памяти:
        private static ConcurrentDictionary<Guid, ImportTaskInfo> _tasks = new ConcurrentDictionary<Guid, ImportTaskInfo>();

        // Для доступа к PostgreSQL
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

            // Пишем кусок в tempFile
            taskInfo.FileStream.Write(buffer, 0, count);
            taskInfo.BytesUploaded += count;

            // Обновляем UploadProgress:
            if (taskInfo.ExpectedFileSize > 0)
            {
                taskInfo.UploadProgress = (double)taskInfo.BytesUploaded / taskInfo.ExpectedFileSize * 100.0;
            }
            else
            {
                // Если не знаем общий размер, ставим -1 или рассчитываем иначе.
                taskInfo.UploadProgress = -1;
            }
        }

        public async Task FinishFileUploadAsync(Guid importTaskId)
        {
            if (!_tasks.TryGetValue(importTaskId, out var taskInfo))
                throw new InvalidOperationException("Import task not found.");

            // Закрываем FileStream, чтобы иметь готовый на диске файл
            taskInfo.FileStream.Close();
            taskInfo.UploadProgress = 100.0;

            // Запускаем задачу импорта
            _ = Task.Run(() => ImportInBackgroundAsync(taskInfo)); // не await, а в фоне
        }

        private async Task ImportInBackgroundAsync(ImportTaskInfo taskInfo)
        {
            try
            {
                // 1) Распаковываем полученный zip во временную папку
                string importFolder = Path.Combine(Path.GetTempPath(), $"import_{taskInfo.ImportTaskId}");
                if (Directory.Exists(importFolder))
                    Directory.Delete(importFolder, true);
                Directory.CreateDirectory(importFolder);

                System.IO.Compression.ZipFile.ExtractToDirectory(taskInfo.TempFilePath, importFolder);

                // Найдём все part_*.db-файлы
                var chunkFiles = Directory.GetFiles(importFolder, "part_*.db");

                // Посчитаем общее число книг во всех chunk'ах, 
                // чтобы примерно оценивать общий прогресс
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

                // 2) Идём по всем частям по порядку
                foreach (var chunkFile in chunkFiles.OrderBy(x => x))
                {
                    // Открываем контекст SQLite
                    var sqliteOptions = new DbContextOptionsBuilder<ExtendedBooksContext>()
                        .UseSqlite($"Filename={chunkFile}")
                        .Options;

                    using var srcContext = new ExtendedBooksContext(sqliteOptions);

                    // 2.1) Upsert категорий
                    var chunkCategories = await srcContext.Categories
                        .AsNoTracking()
                        .ToListAsync();
                    using (var scope = _scopeFactory.CreateScope())
                    {
                        var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                        pgContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        foreach (var cat in chunkCategories)
                        {
                            // Ищем по CategoryId
                            var existingCat = await pgContext.Categories
                                .FirstOrDefaultAsync(c => c.CategoryId == cat.CategoryId);

                            if (existingCat == null)
                            {
                                // Нет — создаём
                                var newCat = new RegularBaseCategory
                                {
                                    CategoryId = cat.CategoryId,
                                    Name = cat.Name
                                };
                                pgContext.Categories.Add(newCat);
                            }
                            else
                            {
                                // Обновляем при необходимости
                                existingCat.Name = cat.Name;
                            }
                        }
                        await pgContext.SaveChangesAsync();
                    }

                    // Словарь CategoryId -> real PK
                    Dictionary<int, int> catMap;
                    using (var scope = _scopeFactory.CreateScope())
                    {
                        var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                        catMap = await pgContext.Categories
                            .ToDictionaryAsync(c => c.CategoryId, c => c.Id);
                    }

                    // 2.2) Идём по книгам, чанками (например, по 2000)
                    int pageSize = 2000;
                    int pageIndex = 0;

                    while (true)
                    {
                        var chunkBooks = await srcContext.BooksInfo
                            .AsNoTracking()
                            .OrderBy(b => b.Id)
                            .Skip(pageIndex * pageSize)
                            .Take(pageSize)
                            .Include(b => b.Category) // чтобы bk.Category.CategoryId было доступно
                            .ToListAsync();

                        if (chunkBooks.Count == 0)
                            break;

                        // Переходим к upsert
                        using (var scope = _scopeFactory.CreateScope())
                        {
                            var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                            pgContext.ChangeTracker.AutoDetectChangesEnabled = false;

                            foreach (var book in chunkBooks)
                            {
                                // Ищем существующую запись (по Id)
                                var existingBook = await pgContext.BooksInfo
                                    .FirstOrDefaultAsync(b => b.Id == book.Id);

                                // Узнаём реальный PK категории
                                catMap.TryGetValue(book.Category.CategoryId, out var realCatId);

                                if (existingBook == null)
                                {
                                    // Создаём новую
                                    var newBook = new RegularBaseBook
                                    {
                                        Id = book.Id,
                                        Title = book.Title,
                                        NormalizedTitle = book.Title.ToLower(),
                                        Description = book.Description,
                                        NormalizedDescription = book.Description.ToLower(),
                                        BeginDate = DateTime.SpecifyKind(book.BeginDate, DateTimeKind.Utc),
                                        EndDate = DateTime.SpecifyKind(book.EndDate, DateTimeKind.Utc),
                                        ImageUrls = book.ImageUrls,
                                        ThumbnailUrls = book.ThumbnailUrls,
                                        Price = book.Price,
                                        City = book.City,
                                        IsMonitored = book.IsMonitored,
                                        FinalPrice = book.FinalPrice,
                                        YearPublished = book.YearPublished,
                                        CategoryId = realCatId,
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
                                    // Обновляем существующую
                                    existingBook.Title = book.Title;
                                    existingBook.NormalizedTitle = book.Title.ToLower();
                                    existingBook.Description = book.Description;
                                    existingBook.NormalizedDescription = book.Description.ToLower();
                                    existingBook.BeginDate = DateTime.SpecifyKind(book.BeginDate, DateTimeKind.Utc);
                                    existingBook.EndDate = DateTime.SpecifyKind(book.EndDate, DateTimeKind.Utc);
                                    existingBook.ImageUrls = book.ImageUrls;
                                    existingBook.ThumbnailUrls = book.ThumbnailUrls;
                                    existingBook.Price = book.Price;
                                    existingBook.City = book.City;
                                    existingBook.IsMonitored = book.IsMonitored;
                                    existingBook.FinalPrice = book.FinalPrice;
                                    existingBook.YearPublished = book.YearPublished;
                                    existingBook.CategoryId = realCatId;
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
                        }

                        processed += chunkBooks.Count;
                        taskInfo.ImportProgress = (double)processed / totalBooksCount * 100.0;
                        pageIndex++;
                    }
                    SqliteConnection.ClearAllPools();
                    GC.Collect();
                    GC.WaitForPendingFinalizers();
                }

                // Завершаем
                taskInfo.ImportProgress = 100.0;
                taskInfo.IsCompleted = true;
                taskInfo.Message = $"Imported/Updated {processed} books total.";

                // Удаляем временную папку
                Directory.Delete(importFolder, true);
            }
            catch (Exception ex)
            {
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Error: {ex.Message}. {ex.InnerException?.Message}";
            }
        }



        /*private async Task ImportInBackgroundAsync(ImportTaskInfo taskInfo)
        {
            try
            {
                // 1) Готовим контекст для чтения из SQLite
                var sqliteOptions = new DbContextOptionsBuilder<ExtendedBooksContext>()
                    .UseSqlite($"Filename={taskInfo.TempFilePath}")
                    .Options;
                using var sourceContext = new ExtendedBooksContext(sqliteOptions);

                // ВАЖНО: AsNoTracking, чтобы EF не вел трекинг
                var totalBooks = await sourceContext.BooksInfo.AsNoTracking().CountAsync();

                // 2) Создаём PostgreSQL-контекст на очистку таблиц (только раз)
                using (var scope = _scopeFactory.CreateScope())
                {
                    var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                    // Очистка BooksInfo (чанками):
                    while (true)
                    {
                        var chunk = pgContext.BooksInfo
                            .Take(1000)
                            .ToList(); // тут можно и 5000 — эти записи без сложных связей
                        if (chunk.Count == 0) break;

                        pgContext.BooksInfo.RemoveRange(chunk);
                        await pgContext.SaveChangesAsync();
                    }

                    // Очистка Categories
                    var allCats = pgContext.Categories.ToList();
                    pgContext.Categories.RemoveRange(allCats);
                    await pgContext.SaveChangesAsync();
                }

                // 3) Перенос категорий (их немного, можно за один раз)
                var categories = await sourceContext.Categories
                    .AsNoTracking() // тоже не трекаем
                    .ToListAsync();
                int catCount = categories.Count;

                // Сохраняем в PostgreSQL:
                using (var scope = _scopeFactory.CreateScope())
                {
                    var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                    // Создаём новые RegularBaseCategory
                    foreach (var cat in categories)
                    {
                        var newCat = new RegularBaseCategory
                        {
                            CategoryId = cat.CategoryId,
                            Name = cat.Name
                        };
                        pgContext.Categories.Add(newCat);
                    }
                    await pgContext.SaveChangesAsync();
                }

                // Словарь meshokId -> реальный PK
                Dictionary<int, int> catMap;
                using (var scope = _scopeFactory.CreateScope())
                {
                    var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                    catMap = await pgContext.Categories
                        .ToDictionaryAsync(c => c.CategoryId, c => c.Id);
                }

                // 4) Перенос книг — читаем чанками из SQLite (AsNoTracking)
                int pageSize = 200;      // уменьшили для экономии памяти
                int pageIndex = 0;
                int processed = 0;

                while (true)
                {
                    // Читаем кусок
                    var chunk = await sourceContext.BooksInfo
                        .AsNoTracking()
                        .OrderBy(b => b.Id)
                        .Skip(pageIndex * pageSize)
                        .Take(pageSize)
                        .Include(b => b.Category)  // нужно, чтобы взять bk.Category.CategoryId
                        .ToListAsync();

                    if (chunk.Count == 0)
                        break; // больше данных нет

                    // Формируем список RegularBaseBook для вставки
                    var listForContext = new List<RegularBaseBook>();
                    foreach (var bk in chunk)
                    {
                        if (!catMap.TryGetValue(bk.Category.CategoryId, out var realCatId))
                        {
                            // если не нашли — можно, например, пропустить
                            continue;
                        }                        
                        var newBook = new RegularBaseBook
                        {
                            Id = bk.Id,
                            Title = bk.Title,
                            NormalizedTitle = bk.Title.ToLower(),
                            Description = bk.Description,
                            NormalizedDescription = bk.Description.ToLower(),
                            BeginDate = DateTime.SpecifyKind(bk.BeginDate, DateTimeKind.Utc),
                            EndDate = DateTime.SpecifyKind(bk.EndDate, DateTimeKind.Utc),
                            ImageUrls = bk.ImageUrls,
                            ThumbnailUrls = bk.ThumbnailUrls,
                            Price = bk.Price,
                            City = bk.City,
                            IsMonitored = bk.IsMonitored,
                            FinalPrice = bk.FinalPrice,
                            YearPublished = bk.YearPublished,
                            CategoryId = realCatId,
                            Tags = bk.Tags,
                            PicsRatio = bk.PicsRatio,
                            Status = bk.Status,
                            StartPrice = bk.StartPrice,
                            Type = bk.Type,
                            SoldQuantity = bk.SoldQuantity,
                            BidsCount = bk.BidsCount,
                            SellerName = bk.SellerName,
                            PicsCount = bk.PicsCount,

                            //08.11.2024 - добавил поддержку малоценных лотов (советские до 1500) и сжатие изображений в object storage
                            IsImagesCompressed = bk.IsImagesCompressed,
                            ImageArchiveUrl = bk.ImageArchiveUrl,

                            //22.01.2025 - т.к. малоценных лотов очень много, храним их без загрузки изображений
                            //изображения будем получать по тем ссылкам, что есть на мешке
                            IsLessValuable = bk.IsLessValuable
                        };

                        listForContext.Add(newBook);
                    }

                    // 5) Сохраняем чанк отдельным контекстом, чтобы сразу освободить память
                    using (var scope = _scopeFactory.CreateScope())
                    {
                        var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                        // Отключаем автопроверку изменений
                        pgContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        pgContext.BooksInfo.AddRange(listForContext);

                        try
                        {
                            await pgContext.SaveChangesAsync();
                            processed += listForContext.Count;
                        }
                        catch (DbUpdateException ex)
                        {
                            // Если PK конфликт — обрабатываем поштучно
                            if (IsDuplicateKeyException(ex))
                            {
                                pgContext.ChangeTracker.Clear();

                                int subcount = 0;
                                foreach (var bk2 in listForContext)
                                {
                                    pgContext.BooksInfo.Add(bk2);
                                    try
                                    {
                                        await pgContext.SaveChangesAsync();
                                        subcount++;
                                    }
                                    catch (DbUpdateException ex2)
                                    {
                                        if (IsDuplicateKeyException(ex2))
                                        {
                                            // пропускаем запись
                                            pgContext.ChangeTracker.Clear();
                                        }
                                        else
                                        {
                                            throw;
                                        }
                                    }
                                }
                                processed += subcount;
                            }
                            else
                            {
                                throw;
                            }
                        }
                    }

                    // Обновляем прогресс
                    taskInfo.ImportProgress = (double)processed / totalBooks * 100.0;

                    pageIndex++;
                }

                // Завершение
                taskInfo.ImportProgress = 100.0;
                taskInfo.IsCompleted = true;
                taskInfo.Message = $"Imported {processed} books (total), {catCount} categories.";
            }
            catch (Exception ex)
            {
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Error: {ex.Message}. {ex.InnerException?.Message}";
            }
        }*/

        private bool IsDuplicateKeyException(DbUpdateException ex)
        {
            // Ищем признак, что это именно уникальный конфликт (23505)
            if (ex.InnerException is Npgsql.PostgresException pgEx)
            {
                // 23505 — дублирование уникального ключа (unique_violation)
                return pgEx.SqlState == "23505";
            }
            return false;
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
                // На уровне логики "прерывания" нет, можно лишь выставить флаг
                // или удалить задачу, если вы хотите остановить
                info.IsCancelledOrError = true;
                info.Message = "Cancelled by user";
                info.IsCompleted = true;
            }
        }

        // Удаляем файлы и чистим список.
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

        // Внутренний класс, чтобы хранить данные о задаче
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
            public long ExpectedFileSize { get; set; } = 0; // если клиент сообщает, можно заполнить

            public long BytesUploaded { get; set; } = 0;
            public double UploadProgress { get; set; } = 0.0;
            public double ImportProgress { get; set; } = 0.0;

            public bool IsCompleted { get; set; } = false;
            public bool IsCancelledOrError { get; set; } = false;
            public string Message { get; set; } = "";

        }
    }
}
