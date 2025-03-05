using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Interfaces;
using RareBooksService.Common.Models.Parsing;
using RareBooksService.Data;
using RareBooksService.Data.Parsing;
using System.Collections.Concurrent;
using System.IO.Compression;
using System.Threading;

namespace RareBooksService.WebApi.Services
{
    public interface IImportService
    {
        Guid StartImport(long expectedFileSize = 0);
        void WriteFileChunk(Guid importTaskId, byte[] buffer, int count);
        Task FinishFileUploadAsync(Guid importTaskId, CancellationToken cancellationToken = default);
        ImportProgressDto GetImportProgress(Guid importTaskId);
        Task CancelImportAsync(Guid importTaskId);
        void CleanupAllFiles();
        void UpdateExpectedFileSize(Guid importTaskId, long expectedFileSize);
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
        private static readonly ConcurrentDictionary<Guid, ImportTaskInfo> _tasks = new ConcurrentDictionary<Guid, ImportTaskInfo>();
        private const int MAX_CONCURRENT_IMPORTS = 3; // Максимальное количество одновременных импортов
        private const long MAX_FILE_SIZE = 500 * 1024 * 1024; // 500 МБ максимальный размер файла
        
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<ImportService> _logger;

        public ImportService(IServiceScopeFactory scopeFactory, ILogger<ImportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        public Guid StartImport(long expectedFileSize = 0)
        {
            // Проверка на количество активных импортов
                if (_tasks.Count(t => !t.Value.IsCompleted && !t.Value.IsCancelledOrError) >= MAX_CONCURRENT_IMPORTS)
            {
                throw new InvalidOperationException($"Достигнут лимит одновременных импортов ({MAX_CONCURRENT_IMPORTS}). Пожалуйста, дождитесь завершения текущих задач.");
            }

            // Проверка на максимальный размер файла
            if (expectedFileSize > MAX_FILE_SIZE)
            {
                throw new InvalidOperationException($"Размер файла ({expectedFileSize / (1024 * 1024)} МБ) превышает максимально допустимый ({MAX_FILE_SIZE / (1024 * 1024)} МБ).");
            }

            var importId = Guid.NewGuid();
            var info = new ImportTaskInfo(importId);
            
            // Устанавливаем ожидаемый размер файла, если он указан
            if (expectedFileSize > 0)
            {
                info.ExpectedFileSize = expectedFileSize;
            }
            
            if (!_tasks.TryAdd(importId, info))
            {
                // Обработка маловероятной коллизии GUID
                throw new InvalidOperationException("Не удалось создать задачу импорта. Пожалуйста, попробуйте еще раз.");
            }
            
            _logger.LogInformation("Начат новый импорт с ID: {ImportId}", importId);
            return importId;
        }

        /// <summary>
        /// Обновляет ожидаемый размер файла для существующей задачи импорта
        /// </summary>
        /// <param name="importTaskId">ID задачи импорта</param>
        /// <param name="expectedFileSize">Ожидаемый размер файла в байтах</param>
        public void UpdateExpectedFileSize(Guid importTaskId, long expectedFileSize)
        {
            if (expectedFileSize <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(expectedFileSize), "Ожидаемый размер файла должен быть положительным числом.");
            }

            if (expectedFileSize > MAX_FILE_SIZE)
            {
                throw new InvalidOperationException($"Размер файла ({expectedFileSize / (1024 * 1024)} МБ) превышает максимально допустимый ({MAX_FILE_SIZE / (1024 * 1024)} МБ).");
            }

            if (!_tasks.TryGetValue(importTaskId, out var taskInfo))
            {
                throw new InvalidOperationException($"Задача импорта с ID {importTaskId} не найдена.");
            }

            if (taskInfo.IsCompleted || taskInfo.IsCancelledOrError)
            {
                throw new InvalidOperationException("Задача уже завершена или отменена.");
            }

            taskInfo.ExpectedFileSize = expectedFileSize;
            
            // Пересчитываем прогресс загрузки, если уже есть загруженные данные
            if (taskInfo.BytesUploaded > 0)
            {
                taskInfo.UploadProgress = (double)taskInfo.BytesUploaded / expectedFileSize * 100.0;
            }
            
            _logger.LogInformation("Обновлен ожидаемый размер файла для импорта {ImportId}: {Size} байт", importTaskId, expectedFileSize);
        }

        public void WriteFileChunk(Guid importTaskId, byte[] buffer, int count)
        {
            if (buffer == null)
            {
                throw new ArgumentNullException(nameof(buffer), "Буфер данных не может быть null.");
            }

            if (count <= 0 || count > buffer.Length)
            {
                throw new ArgumentOutOfRangeException(nameof(count), "Некорректное количество байт для записи.");
            }

            if (!_tasks.TryGetValue(importTaskId, out var taskInfo))
            {
                throw new InvalidOperationException($"Задача импорта с ID {importTaskId} не найдена.");
            }

            if (taskInfo.IsCompleted || taskInfo.IsCancelledOrError)
            {
                throw new InvalidOperationException("Задача уже завершена или отменена.");
            }

            // Проверка на превышение максимального размера файла
            if (taskInfo.ExpectedFileSize > 0 && taskInfo.BytesUploaded + count > MAX_FILE_SIZE)
            {
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Превышен максимальный размер файла ({MAX_FILE_SIZE / (1024 * 1024)} МБ).";
                throw new InvalidOperationException(taskInfo.Message);
            }

            try
            {
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
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при записи чанка файла для задачи {ImportId}", importTaskId);
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Ошибка при записи данных: {ex.Message}";
                throw;
            }
        }

        public async Task FinishFileUploadAsync(Guid importTaskId, CancellationToken cancellationToken = default)
        {
            if (!_tasks.TryGetValue(importTaskId, out var taskInfo))
            {
                throw new InvalidOperationException($"Задача импорта с ID {importTaskId} не найдена.");
            }

            try
            {
                // Закроем файл, чтобы он стал полноценным ZIP на диске
                taskInfo.FileStream.Close();
                taskInfo.UploadProgress = 100.0;

                _logger.LogInformation("Завершена загрузка файла для импорта {ImportId}, начинаем обработку", importTaskId);

                // Запускаем импорт в фоне
                _ = Task.Run(() => ImportInBackgroundAsync(taskInfo, cancellationToken), cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при завершении загрузки файла для импорта {ImportId}", importTaskId);
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Ошибка при завершении загрузки: {ex.Message}";
                throw;
            }
        }

        private async Task ImportInBackgroundAsync(ImportTaskInfo taskInfo, CancellationToken cancellationToken)
        {
            string importFolder = Path.Combine(Path.GetTempPath(), $"import_{taskInfo.ImportTaskId}");
            
            try
            {
                // Проверка формата файла
                if (!File.Exists(taskInfo.TempFilePath))
                {
                    taskInfo.IsCancelledOrError = true;
                    taskInfo.Message = "Файл импорта не найден.";
                    _logger.LogError("Файл импорта не найден: {FilePath}", taskInfo.TempFilePath);
                    return;
                }
                
                if (!IsZipFile(taskInfo.TempFilePath))
                {
                    taskInfo.IsCancelledOrError = true;
                    taskInfo.Message = "Загруженный файл не является валидным ZIP архивом.";
                    _logger.LogError("Файл не является ZIP архивом: {FilePath}", taskInfo.TempFilePath);
                    return;
                }

                cancellationToken.ThrowIfCancellationRequested();

                // 1) Распакуем ZIP во временную папку
                if (Directory.Exists(importFolder))
                    Directory.Delete(importFolder, true);
                
                Directory.CreateDirectory(importFolder);
                _logger.LogInformation("Создана временная папка для импорта: {FolderPath}", importFolder);

                // Извлекаем все part_*.db
                ZipFile.ExtractToDirectory(taskInfo.TempFilePath, importFolder);
                var chunkFiles = Directory.GetFiles(importFolder, "part_*.db");
                
                // Проверка наличия нужных файлов
                if (chunkFiles.Length == 0)
                {
                    taskInfo.IsCancelledOrError = true;
                    taskInfo.Message = "В архиве не найдены файлы part_*.db. Проверьте формат данных для импорта.";
                    _logger.LogError("В архиве не найдены файлы part_*.db: {ImportId}", taskInfo.ImportTaskId);
                    return;
                }

                _logger.LogInformation("Найдено {Count} файлов чанков в архиве", chunkFiles.Length);
                
                cancellationToken.ThrowIfCancellationRequested();

                // Подсчитываем общее количество книг (для прогресса)
                long totalBooksCount = 0;
                foreach (var chunkFile in chunkFiles)
                {
                    var sqliteOptions = new DbContextOptionsBuilder<ExtendedBooksContext>()
                        .UseSqlite($"Filename={chunkFile}")
                        .Options;

                    using var srcContext = new ExtendedBooksContext(sqliteOptions);
                    try
                    {
                        long cnt = await srcContext.BooksInfo.LongCountAsync(cancellationToken);
                        totalBooksCount += cnt;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Ошибка при подсчете книг в файле {ChunkFile}", chunkFile);
                        // Продолжаем работу, даже если один из файлов поврежден
                    }
                }

                _logger.LogInformation("Всего будет импортировано {Count} книг", totalBooksCount);

                long processed = 0;

                // 2) Идём по всем chunk'ам
                foreach (var chunkFile in chunkFiles.OrderBy(x => x))
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    
                    _logger.LogInformation("Обработка файла: {ChunkFile}", Path.GetFileName(chunkFile));
                    
                    var sqliteOptions = new DbContextOptionsBuilder<ExtendedBooksContext>()
                        .UseSqlite($"Filename={chunkFile}")
                        .Options;

                    using var srcContext = new ExtendedBooksContext(sqliteOptions)
                    {
                        // Необязательно, но можно отключить TrackChanges
                        ChangeTracker = { AutoDetectChangesEnabled = false }
                    };

                    // ======================= Шаг 2.1: Категории =========================
                    var chunkCategories = await srcContext.Categories
                        .AsNoTracking()
                        .ToListAsync(cancellationToken);

                    _logger.LogInformation("Найдено {Count} категорий в файле", chunkCategories.Count);

                    using (var scope = _scopeFactory.CreateScope())
                    {
                        var pgContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
                        pgContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        // Начинаем транзакцию для категорий
                        using var transaction = await pgContext.Database.BeginTransactionAsync(cancellationToken);
                        try
                        {
                            // Создаем словарь для маппинга CategoryId -> Category
                            var categoryMap = new Dictionary<int, RegularBaseCategory>();

                            // 2.1.1) Upsert категорий в PG (по Meshok.net-ID = cat.CategoryId)
                            foreach (var cat in chunkCategories)
                            {
                                if (cat == null || cat.CategoryId <= 0)
                                {
                                    _logger.LogWarning("Пропускаем некорректную категорию (null или id <= 0)");
                                    continue;
                                }
                                
                                // Ищем в PG запись с таким же CategoryId (у нас в PG это поле — "CategoryId" на meshok.net)
                                var existingCat = await pgContext.Categories
                                    .FirstOrDefaultAsync(c => c.CategoryId == cat.CategoryId, cancellationToken);

                                RegularBaseCategory category;
                                if (existingCat == null)
                                {
                                    // Добавляем новую
                                    category = new RegularBaseCategory
                                    {
                                        CategoryId = cat.CategoryId,  // meshok ID
                                        Name = cat.Name ?? "Неизвестная категория"
                                    };
                                    pgContext.Categories.Add(category);
                                }
                                else
                                {
                                    // Обновляем уже имеющуюся
                                    existingCat.Name = cat.Name ?? existingCat.Name;
                                    category = existingCat;
                                }

                                // Добавляем в словарь маппинга
                                categoryMap[cat.CategoryId] = category;
                            }

                            await pgContext.SaveChangesAsync(cancellationToken);
                            await transaction.CommitAsync(cancellationToken);
                            
                            _logger.LogInformation("Категории успешно обновлены");

                            // 2.1.2) Импорт книг с правильными связями по CategoryId
                            var books = await srcContext.BooksInfo
                                .AsNoTracking()
                                .ToListAsync(cancellationToken);

                            _logger.LogInformation("Найдено {Count} книг в файле", books.Count);

                            int processedBooks = 0;
                            int batchSize = 100;
                            var booksToAdd = new List<RegularBaseBook>();

                            foreach (var book in books)
                            {
                                if (book == null)
                                {
                                    _logger.LogWarning("Пропускаем null книгу");
                                    continue;
                                }

                                // Находим соответствующую категорию по CategoryId из исходной книги
                                if (!categoryMap.TryGetValue(book.CategoryId, out var category))
                                {
                                    _logger.LogWarning("Не найдена категория для книги {BookId} с CategoryId {CategoryId}", 
                                        book.Id, book.CategoryId);
                                    continue;
                                }

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

                                    CategoryId = category.Id, // Используем Id категории из PG

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

                                booksToAdd.Add(newBook);
                                processedBooks++;

                                if (booksToAdd.Count >= batchSize)
                                {
                                    await pgContext.BooksInfo.AddRangeAsync(booksToAdd, cancellationToken);
                                    await pgContext.SaveChangesAsync(cancellationToken);
                                    booksToAdd.Clear();

                                    taskInfo.ImportProgress = (double)processedBooks / books.Count * 100.0;
                                }
                            }

                            // Сохраняем оставшиеся книги
                            if (booksToAdd.Any())
                            {
                                await pgContext.BooksInfo.AddRangeAsync(booksToAdd, cancellationToken);
                                await pgContext.SaveChangesAsync(cancellationToken);
                            }

                            taskInfo.ImportProgress = 100.0;
                            _logger.LogInformation("Импорт успешно завершен");
                        }
                        catch (Exception ex)
                        {
                            await transaction.RollbackAsync(cancellationToken);
                            _logger.LogError(ex, "Ошибка при импорте данных");
                            throw;
                        }
                    }

                    // Закрываем SQLite для данного chunk
                    SqliteConnection.ClearAllPools();
                }

                // Закончили все chunks
                taskInfo.ImportProgress = 100.0;
                taskInfo.IsCompleted = true;
                taskInfo.Message = $"Импортировано / Обновлено {processed} книг всего.";
                _logger.LogInformation("Импорт {ImportId} успешно завершен. Обработано {Count} книг", 
                    taskInfo.ImportTaskId, processed);
            }
            catch (OperationCanceledException)
            {
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = "Операция была отменена пользователем";
                _logger.LogWarning("Импорт {ImportId} был отменен пользователем", taskInfo.ImportTaskId);
            }
            catch (Exception ex)
            {
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Ошибка импорта: {ex.Message} {ex.InnerException?.Message}";
                _logger.LogError(ex, "Ошибка при импорте {ImportId}", taskInfo.ImportTaskId);
            }
            finally
            {
                // Гарантированная очистка временных ресурсов
                try
                {
                    if (Directory.Exists(importFolder))
                    {
                        Directory.Delete(importFolder, true);
                        _logger.LogInformation("Временная папка {FolderPath} удалена", importFolder);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Не удалось удалить временную папку {FolderPath}", importFolder);
                }
            }
        }

        /// <summary>
        /// Безопасное преобразование DateTime с проверкой на допустимые значения
        /// </summary>
        private DateTime SafeConvertDateTime(DateTime dateTime)
        {
            try
            {
                return DateTime.SpecifyKind(dateTime, DateTimeKind.Utc);
            }
            catch
            {
                // В случае некорректной даты возвращаем текущее время
                return DateTime.UtcNow;
            }
        }

        /// <summary>
        /// Проверяет, является ли файл ZIP-архивом
        /// </summary>
        /// <param name="filePath">Путь к файлу</param>
        /// <returns>true, если файл является ZIP-архивом</returns>
        private bool IsZipFile(string filePath)
        {
            try
            {
                // Проверяем сигнатуру ZIP файла (первый этап проверки)
                using (var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read))
                {
                    if (fs.Length < 4)
                        return false;

                    byte[] signature = new byte[4];
                    fs.Read(signature, 0, 4);
                    
                    // ZIP файл начинается с сигнатуры 'PK\x03\x04'
                    if (!(signature[0] == 0x50 && signature[1] == 0x4B && 
                          signature[2] == 0x03 && signature[3] == 0x04))
                    {
                        return false;
                    }
                }
                
                // Второй этап проверки - попытка открыть как архив
                using (var zipArchive = ZipFile.OpenRead(filePath))
                {
                    // Если дошли до этой точки без исключений, значит файл является корректным ZIP-архивом
                    return true;
                }
            }
            catch (InvalidDataException ex)
            {
                // Это исключение обычно возникает, если файл имеет неверный формат ZIP
                _logger.LogWarning(ex, "Файл не является корректным ZIP-архивом: {FilePath}", filePath);
                return false;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при проверке ZIP-файла: {FilePath}", filePath);
                return false;
            }
        }

        public ImportProgressDto GetImportProgress(Guid importTaskId)
        {
            if (!_tasks.TryGetValue(importTaskId, out var info))
            {
                _logger.LogWarning("Запрошен прогресс для несуществующей задачи {ImportId}", importTaskId);
                return new ImportProgressDto
                {
                    IsCancelledOrError = true,
                    Message = "Задача не найдена"
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

        public async Task CancelImportAsync(Guid importTaskId)
        {
            if (_tasks.TryGetValue(importTaskId, out var info))
            {
                info.IsCancelledOrError = true;
                info.Message = "Отменено пользователем";
                
                // Закрываем файл, если он еще открыт
                try
                {
                    if (info.FileStream != null && info.FileStream.CanWrite)
                    {
                        await info.FileStream.DisposeAsync();
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Ошибка при закрытии файлового потока для {ImportId}", importTaskId);
                }
                
                info.IsCompleted = true;
                _logger.LogInformation("Задача импорта {ImportId} отменена пользователем", importTaskId);
            }
            else
            {
                _logger.LogWarning("Попытка отменить несуществующую задачу {ImportId}", importTaskId);
            }
        }

        public void CleanupAllFiles()
        {
            _logger.LogInformation("Запущена очистка всех временных файлов импорта");
            
            foreach (var kvp in _tasks)
            {
                var info = kvp.Value;
                try
                {
                    // Закрываем файловый поток, если он открыт
                    if (info.FileStream != null)
                    {
                        try
                        {
                            info.FileStream.Close();
                            info.FileStream.Dispose();
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Ошибка при закрытии файлового потока для {ImportId}", info.ImportTaskId);
                        }
                    }
                    
                    // Удаляем временный файл
                    if (File.Exists(info.TempFilePath))
                    {
                        File.Delete(info.TempFilePath);
                        _logger.LogInformation("Удален временный файл {FilePath}", info.TempFilePath);
                    }
                    
                    // Удаляем временную папку с распакованными файлами
                    string importFolder = Path.Combine(Path.GetTempPath(), $"import_{info.ImportTaskId}");
                    if (Directory.Exists(importFolder))
                    {
                        Directory.Delete(importFolder, true);
                        _logger.LogInformation("Удалена временная папка {FolderPath}", importFolder);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Ошибка при очистке ресурсов для {ImportId}", info.ImportTaskId);
                }

                _tasks.TryRemove(kvp.Key, out _);
            }
            
            _logger.LogInformation("Очистка временных файлов импорта завершена");
        }

        private class ImportTaskInfo : IDisposable
        {
            private bool _disposed = false;
            
            public ImportTaskInfo(Guid id)
            {
                ImportTaskId = id;
                TempFilePath = Path.Combine(Path.GetTempPath(), $"import_{id}.db");
                FileStream = File.OpenWrite(TempFilePath);
            }
            
            public Guid ImportTaskId { get; }
            public FileStream FileStream { get; private set; }
            public string TempFilePath { get; }
            public long ExpectedFileSize { get; set; } = 0;

            public long BytesUploaded { get; set; } = 0;
            public double UploadProgress { get; set; } = 0.0;
            public double ImportProgress { get; set; } = 0.0;

            public bool IsCompleted { get; set; } = false;
            public bool IsCancelledOrError { get; set; } = false;
            public string Message { get; set; } = "";
            
            public void Dispose()
            {
                Dispose(true);
                GC.SuppressFinalize(this);
            }
            
            protected virtual void Dispose(bool disposing)
            {
                if (!_disposed)
                {
                    if (disposing)
                    {
                        // Освобождаем управляемые ресурсы
                        FileStream?.Dispose();
                    }
                    
                    // Освобождаем неуправляемые ресурсы
                    FileStream = null;
                    _disposed = true;
                }
            }
            
            ~ImportTaskInfo()
            {
                Dispose(false);
            }
        }
    }
}
