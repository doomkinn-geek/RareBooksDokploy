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
        IEnumerable<ActiveExportDto> GetActiveExports();
    }

    /// <summary>
    /// DTO для информации об активном экспорте
    /// </summary>
    public class ActiveExportDto
    {
        public Guid TaskId { get; set; }
        public int Progress { get; set; }
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
        private const int ChunkSize = 5000; // Еще больше уменьшаем для стабильности

        public ExportService(IServiceScopeFactory scopeFactory, ILogger<ExportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }


        public async Task<Guid> StartExportAsync()
        {
            // Проверяем доступную память
            var memoryBefore = GC.GetTotalMemory(false) / (1024.0 * 1024.0);
            _logger.LogInformation($"Доступная память перед экспортом: {memoryBefore:F2} MB");

            // 1) Перед запуском нового экспорта удалим старые файлы экспорта
            CleanupOldExportFilesOnDisk();

            // 2) Проверяем, нет ли уже активного экспорта
            bool anyActive = _progress.Values.Any(p => p >= 0 && p < 100);
            if (anyActive)
            {
                _logger.LogWarning("Попытка запуска экспорта при уже активном процессе");
                throw new InvalidOperationException("Экспорт уже выполняется. Дождитесь завершения или отмените предыдущий экспорт.");
            }

            var taskId = Guid.NewGuid();
            _progress[taskId] = 0;
            _errors[taskId] = string.Empty;

            var cts = new CancellationTokenSource();
            _cancellationTokens[taskId] = cts;

            _logger.LogInformation($"Создана новая задача экспорта, TaskId: {taskId}");

            // Запускаем DoExport в фоновом потоке
            _ = Task.Run(() => DoExport(taskId, cts.Token));
            return taskId;
        }

        /// <summary>
        /// Удаляем все временные файлы/папки предыдущих экспортных заданий.
        /// </summary>
        private void CleanupOldExportFilesOnDisk()
        {
            try
            {
                // Папка для временных файлов
                string tempPath = Path.GetTempPath();

                // 1) Удаляем все zip-файлы вида export_{...}.zip
                var oldZips = Directory.GetFiles(tempPath, "export_*.zip");
                foreach (var zip in oldZips)
                {
                    try
                    {
                        File.Delete(zip);
                    }
                    catch
                    {
                        // Игнорируем любые ошибки
                    }
                }

                // 2) Удаляем все подпапки вида export_{...}, где лежали part_*.db
                var oldDirs = Directory.GetDirectories(tempPath, "export_*");
                foreach (var dir in oldDirs)
                {
                    try
                    {
                        Directory.Delete(dir, true);
                    }
                    catch
                    {
                        // Игнорируем любые ошибки
                    }
                }
            }
            catch
            {
                // Если что-то пошло не так, не прерываем работу, а просто продолжаем
            }
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

        public IEnumerable<ActiveExportDto> GetActiveExports()
        {
            var activeExports = new List<ActiveExportDto>();
            
            foreach (var kvp in _progress)
            {
                var taskId = kvp.Key;
                var progress = kvp.Value;
                
                // Считаем активными экспорты с прогрессом от 0 до 99 (не завершенные и не ошибочные)
                if (progress >= 0 && progress < 100)
                {
                    activeExports.Add(new ActiveExportDto
                    {
                        TaskId = taskId,
                        Progress = progress
                    });
                }
            }
            
            return activeExports;
        }

        /// <summary>
        /// Основная логика экспорта
        /// </summary>
        private async Task DoExport(Guid taskId, CancellationToken token)
        {
            try
            {
                _logger.LogInformation($"Начинаем экспорт данных, TaskId: {taskId}");
                _progress[taskId] = 0;

                using var scope = _scopeFactory.CreateScope();
                var regularContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                // 1) Узнаём общее число книг
                _logger.LogInformation($"Подсчитываем общее количество книг, TaskId: {taskId}");
                int totalBooks = await regularContext.BooksInfo.CountAsync(token);
                _logger.LogInformation($"Найдено {totalBooks} книг для экспорта, TaskId: {taskId}");
                
                if (totalBooks == 0)
                {
                    _logger.LogWarning($"Нет книг для экспорта, TaskId: {taskId}");
                    _progress[taskId] = 100;
                    return;
                }
                token.ThrowIfCancellationRequested();

                // 2) Загружаем все категории из старой базы (PostgreSQL / PostgreSQL)
                //    Здесь Category.Id — это старый PK, Category.CategoryId — meshok ID
                _logger.LogInformation($"Загружаем категории, TaskId: {taskId}");
                var allCategories = await regularContext.Categories
                    .AsNoTracking()
                    .OrderBy(c => c.Id)
                    .ToListAsync(token);
                _logger.LogInformation($"Загружено {allCategories.Count} категорий, TaskId: {taskId}");

                token.ThrowIfCancellationRequested();

                // 3) Создаём временную папку, куда будем складывать part_*.db
                string tempFolder = Path.Combine(Path.GetTempPath(), $"export_{taskId}");
                _logger.LogInformation($"Создаем временную папку: {tempFolder}, TaskId: {taskId}");
                if (!Directory.Exists(tempFolder))
                    Directory.CreateDirectory(tempFolder);

                int processed = 0;
                int chunkIndex = 0;

                // Цикл по порциям книг (ChunkSize задан у вас в классе ExportService)
                _logger.LogInformation($"Начинаем обработку {totalBooks} книг порциями по {ChunkSize}, TaskId: {taskId}");
                while (processed < totalBooks)
                {
                    token.ThrowIfCancellationRequested();

                    // 4) Загружаем очередной блок (chunk) книг из старой базы
                    _logger.LogDebug($"Загружаем chunk {chunkIndex + 1}, позиция {processed}-{processed + ChunkSize}, TaskId: {taskId}");
                    var booksChunk = await regularContext.BooksInfo
                        .OrderBy(b => b.Id)
                        .Skip(processed)
                        .Take(ChunkSize)
                        .AsNoTracking()  // отключаем трекинг EF для экономии памяти
                        .ToListAsync(token);

                    if (booksChunk.Count == 0)
                    {
                        _logger.LogWarning($"Получен пустой chunk на позиции {processed}, завершаем, TaskId: {taskId}");
                        break;
                    }

                    chunkIndex++;
                    string chunkDbPath = Path.Combine(tempFolder, $"part_{chunkIndex}.db");
                    _logger.LogDebug($"Создаем SQLite файл: {chunkDbPath}, TaskId: {taskId}");
                    if (File.Exists(chunkDbPath))
                        File.Delete(chunkDbPath);

                    // 5) Создаём контекст SQLite для текущего чанка
                    var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                    optionsBuilder.UseSqlite($"Filename={chunkDbPath}");

                    using (var extendedContext = new ExtendedBooksContext(optionsBuilder.Options))
                    {
                        try
                        {
                            // Создаём таблицы, если вдруг не созданы
                            extendedContext.Database.EnsureCreated();
                            // Отключаем автоматическое DetectChanges для быстроты
                            extendedContext.ChangeTracker.AutoDetectChangesEnabled = false;

                        // 6) Заполняем таблицу категорий (полностью),
                        //    чтобы у каждой категории был свой auto-increment PK (Id)
                        //    и также сохранить meshok.net ID в поле CategoryId (не путать с PK!)
                        var newCats = allCategories.Select(oldCat => new ExtendedCategory
                        {
                            // Старый PK (oldCat.Id) мы не копируем, он не нужен.
                            // Логично хранить во "внешнем" поле meshok ID (старый oldCat.CategoryId).
                            CategoryId = oldCat.CategoryId,
                            Name = oldCat.Name
                        })
                        .ToList();

                        extendedContext.Categories.AddRange(newCats);
                        await extendedContext.SaveChangesAsync(token);

                        // 7) Создаем словарь для сопоставления CategoryId (meshok.net) с Id (PK) в новой базе
                        // Этот словарь сопоставляет meshok.net ID категории (oldCat.CategoryId) с новым PK (newCat.Id)
                        var categoryIdToPkMap = new Dictionary<int, int>();
                        foreach (var newCat in newCats)
                        {
                            categoryIdToPkMap[newCat.CategoryId] = newCat.Id;
                        }

                        // 8) Конвертируем книги чанка под новую модель ExtendedBookInfo
                        //    и подставляем правильный newCat.Id в поле CategoryId
                        //    (поскольку BookInfo.CategoryId ссылается на Category.Id)
                        var extendedBooks = new List<ExtendedBookInfo>(booksChunk.Count);
                        foreach (var oldBook in booksChunk)
                        {
                            token.ThrowIfCancellationRequested();

                            // Сначала найдем категорию в исходной базе, чтобы получить ее CategoryId (meshok.net)
                            var oldCategory = allCategories.FirstOrDefault(c => c.Id == oldBook.CategoryId);
                            if (oldCategory == null)
                            {
                                _logger.LogWarning($"Книга {oldBook.Id} ссылается на несуществующую категорию с Id={oldBook.CategoryId}");
                                continue;
                            }

                            // Теперь найдем соответствующий PK в новой базе по CategoryId (meshok.net)
                            if (!categoryIdToPkMap.TryGetValue(oldCategory.CategoryId, out int newCatId))
                            {
                                _logger.LogWarning($"Не удалось найти соответствующую категорию для meshok.net CategoryId={oldCategory.CategoryId}");
                                continue;
                            }

                            var newBook = new ExtendedBookInfo
                            {
                                // Переносим поля один в один
                                Id = oldBook.Id,  // Можно сохранить старый BookId
                                Title = oldBook.Title,
                                Description = oldBook.Description,
                                BeginDate = oldBook.BeginDate,
                                EndDate = oldBook.EndDate,
                                Price = oldBook.Price,
                                FinalPrice = oldBook.FinalPrice,
                                City = oldBook.City,
                                IsMonitored = oldBook.IsMonitored,
                                YearPublished = oldBook.YearPublished,
                                Tags = oldBook.Tags,
                                PicsRatio = oldBook.PicsRatio,
                                Status = oldBook.Status,
                                StartPrice = oldBook.StartPrice,
                                Type = oldBook.Type,
                                SoldQuantity = oldBook.SoldQuantity,
                                BidsCount = oldBook.BidsCount,
                                SellerName = oldBook.SellerName,
                                PicsCount = oldBook.PicsCount,
                                ImageUrls = oldBook.ImageUrls,
                                ThumbnailUrls = oldBook.ThumbnailUrls,
                                IsImagesCompressed = oldBook.IsImagesCompressed,
                                ImageArchiveUrl = oldBook.ImageArchiveUrl,
                                IsLessValuable = oldBook.IsLessValuable,

                                // Устанавливаем CategoryId как PK новой категории
                                CategoryId = newCatId
                            };

                            extendedBooks.Add(newBook);
                        }

                            // Сохраняем книги этого чанка
                            extendedContext.BooksInfo.AddRange(extendedBooks);
                            await extendedContext.SaveChangesAsync(token);
                            _logger.LogInformation($"Сохранено {extendedBooks.Count} книг в chunk {chunkIndex}, TaskId: {taskId}");
                        }
                        catch (Exception chunkEx)
                        {
                            _logger.LogError(chunkEx, $"Ошибка при обработке chunk {chunkIndex}, TaskId: {taskId}");
                            throw;
                        }
                    }

                    // Закрываем соединения, освобождаем SQLite connection pool
                    SqliteConnection.ClearAllPools();

                    processed += booksChunk.Count;

                    // Мониторинг памяти каждые 10 chunks
                    if (chunkIndex % 10 == 0)
                    {
                        var currentMemory = GC.GetTotalMemory(false) / (1024.0 * 1024.0);
                        _logger.LogInformation($"Chunk {chunkIndex}: обработано {processed}/{totalBooks}, память: {currentMemory:F2} MB, TaskId: {taskId}");
                        
                        // Принудительная сборка мусора каждые 50 chunks для освобождения памяти
                        if (chunkIndex % 50 == 0)
                        {
                            GC.Collect();
                            GC.WaitForPendingFinalizers();
                            var memoryAfterGC = GC.GetTotalMemory(true) / (1024.0 * 1024.0);
                            _logger.LogInformation($"Сборка мусора выполнена, память после: {memoryAfterGC:F2} MB, TaskId: {taskId}");
                        }
                    }

                    // 0..90%: остальное 10% зарезервируем на упаковку
                    int percent = (int)((double)processed / totalBooks * 90);
                    _progress[taskId] = percent;
                }

                // Небольшая пауза, чтобы гарантировать, что все файлы освобождены
                await Task.Delay(300, token);

                // 9) Создаём zip из tempFolder с оптимизацией для больших файлов
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"export_{taskId}.zip");
                _logger.LogInformation($"Начинаем создание ZIP архива: {zipFilePath}, TaskId: {taskId}");
                
                try
                {
                    if (File.Exists(zipFilePath))
                    {
                        File.Delete(zipFilePath);
                        _logger.LogInformation($"Удален существующий ZIP файл, TaskId: {taskId}");
                    }

                    _progress[taskId] = 91; // Начинаем упаковку

                    // Получаем информацию о размере папки для логирования
                    var dirInfo = new DirectoryInfo(tempFolder);
                    if (!dirInfo.Exists)
                    {
                        throw new DirectoryNotFoundException($"Временная папка не найдена: {tempFolder}");
                    }
                    
                    var dbFiles = dirInfo.GetFiles("*.db", SearchOption.AllDirectories);
                    var folderSizeMB = dbFiles.Sum(file => file.Length) / (1024.0 * 1024.0);
                    _logger.LogInformation($"Найдено {dbFiles.Length} файлов .db, общий размер: {folderSizeMB:F2} MB, TaskId: {taskId}");

                    if (dbFiles.Length == 0)
                    {
                        throw new InvalidOperationException("Не найдено файлов .db для архивирования");
                    }

                    // Проверяем свободное место на диске
                    var driveInfo = new DriveInfo(Path.GetPathRoot(zipFilePath));
                    var freeSpaceGB = driveInfo.AvailableFreeSpace / (1024.0 * 1024.0 * 1024.0);
                    _logger.LogInformation($"Свободное место на диске: {freeSpaceGB:F2} GB, TaskId: {taskId}");

                    // Используем более эффективный подход для больших архивов
                    _logger.LogInformation($"Запускаем архивирование папки {tempFolder}, TaskId: {taskId}");
                    ZipFile.CreateFromDirectory(
                        tempFolder, 
                        zipFilePath, 
                        CompressionLevel.Fastest, // Быстрое сжатие для ускорения процесса
                        false
                    );
                    _logger.LogInformation($"Архивирование завершено, TaskId: {taskId}");

                    token.ThrowIfCancellationRequested();
                    _progress[taskId] = 95; // Архив создан

                    // Проверяем, что архив создался корректно
                    if (!File.Exists(zipFilePath))
                    {
                        throw new FileNotFoundException($"ZIP архив не был создан: {zipFilePath}");
                    }

                    // Логируем размер созданного архива
                    var zipFileInfo = new FileInfo(zipFilePath);
                    var zipSizeMB = zipFileInfo.Length / (1024.0 * 1024.0);
                    _logger.LogInformation($"ZIP архив создан успешно, размер: {zipSizeMB:F2} MB, TaskId: {taskId}");

                    if (zipFileInfo.Length < 1024) // Файл меньше 1KB - подозрительно
                    {
                        _logger.LogWarning($"ZIP файл очень маленький ({zipFileInfo.Length} байт), возможна ошибка, TaskId: {taskId}");
                    }

                    // Запоминаем путь к zip, чтобы потом отдавать файл
                    _files[taskId] = zipFilePath;

                    // Удаляем временную папку part_*.db
                    try
                    {
                        Directory.Delete(tempFolder, true);
                        _logger.LogInformation($"Временная папка удалена, TaskId: {taskId}");
                    }
                    catch (Exception deleteEx)
                    {
                        _logger.LogWarning(deleteEx, $"Не удалось удалить временную папку {tempFolder}, TaskId: {taskId}");
                        // Не прерываем выполнение из-за этой ошибки
                    }

                    // 100% – готово
                    _progress[taskId] = 100;
                    _logger.LogInformation($"Экспорт завершен успешно, TaskId: {taskId}");
                }
                catch (Exception zipEx)
                {
                    _logger.LogError(zipEx, $"Критическая ошибка при создании ZIP архива, TaskId: {taskId}");
                    throw;
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning($"Экспорт отменён пользователем, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = "Экспорт отменён пользователем.";
            }
            catch (OutOfMemoryException memEx)
            {
                _logger.LogError(memEx, $"Недостаточно памяти для экспорта, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = "Недостаточно памяти для выполнения экспорта. Попробуйте экспортировать меньшими порциями.";
            }
            catch (UnauthorizedAccessException accessEx)
            {
                _logger.LogError(accessEx, $"Ошибка доступа к файлам при экспорте, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = "Ошибка доступа к временным файлам. Проверьте права доступа.";
            }
            catch (System.Data.Common.DbException dbEx)
            {
                _logger.LogError(dbEx, $"Ошибка базы данных при экспорте, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = $"Ошибка базы данных: {dbEx.Message}";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Неожиданная ошибка экспорта, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = $"Неожиданная ошибка: {ex.Message}";
            }
            finally
            {
                _cancellationTokens.TryRemove(taskId, out _);
                _logger.LogInformation($"Задача экспорта завершена, TaskId: {taskId}");
            }
        }


    }
}
