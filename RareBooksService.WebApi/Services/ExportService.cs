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

                // 1) Узнаём общее число книг
                int totalBooks = await regularContext.BooksInfo.CountAsync(token);
                if (totalBooks == 0)
                {
                    // Если книг нет, сразу выходим
                    _progress[taskId] = 100;
                    return;
                }
                token.ThrowIfCancellationRequested();

                // 2) Загружаем все категории из старой базы (PostgreSQL / PostgreSQL)
                //    Здесь Category.Id — это старый PK, Category.CategoryId — meshok ID
                var allCategories = await regularContext.Categories
                    .AsNoTracking()
                    .OrderBy(c => c.Id)
                    .ToListAsync(token);

                token.ThrowIfCancellationRequested();

                // 3) Создаём временную папку, куда будем складывать part_*.db
                string tempFolder = Path.Combine(Path.GetTempPath(), $"export_{taskId}");
                if (!Directory.Exists(tempFolder))
                    Directory.CreateDirectory(tempFolder);

                int processed = 0;
                int chunkIndex = 0;

                // Цикл по порциям книг (ChunkSize задан у вас в классе ExportService)
                while (processed < totalBooks)
                {
                    token.ThrowIfCancellationRequested();

                    // 4) Загружаем очередной блок (chunk) книг из старой базы
                    var booksChunk = await regularContext.BooksInfo
                        .OrderBy(b => b.Id)
                        .Skip(processed)
                        .Take(ChunkSize)
                        .AsNoTracking()  // отключаем трекинг EF для экономии памяти
                        .ToListAsync(token);

                    if (booksChunk.Count == 0)
                        break;

                    chunkIndex++;
                    string chunkDbPath = Path.Combine(tempFolder, $"part_{chunkIndex}.db");
                    if (File.Exists(chunkDbPath))
                        File.Delete(chunkDbPath);

                    // 5) Создаём контекст SQLite для текущего чанка
                    var optionsBuilder = new DbContextOptionsBuilder<ExtendedBooksContext>();
                    optionsBuilder.UseSqlite($"Filename={chunkDbPath}");

                    using (var extendedContext = new ExtendedBooksContext(optionsBuilder.Options))
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

                        // 7) Построим словарь, который сопоставляет "старый PK" -> "новый PK"
                        //    Чтобы для каждой категории oldCat.Id узнать newCat.Id
                        //    Для этого нужно идти «параллельно» по спискам allCategories и newCats,
                        //    так как мы вставляли их в одинаковом порядке.
                        var catMap = new Dictionary<int, int>(newCats.Count);
                        for (int i = 0; i < allCategories.Count; i++)
                        {
                            int oldId = allCategories[i].Id;    // Старый PK
                            int newId = newCats[i].Id;         // Новый PK (в SQLite)
                            catMap[oldId] = newId;
                        }

                        // 8) Конвертируем книги чанка под новую модель ExtendedBookInfo
                        //    и главное — подставляем правильный newCat.Id в поле CategoryId
                        //    (поскольку BookInfo.CategoryId ссылается на Category.Id)
                        var extendedBooks = new List<ExtendedBookInfo>(booksChunk.Count);
                        foreach (var oldBook in booksChunk)
                        {
                            token.ThrowIfCancellationRequested();

                            // Если в старой базе oldBook.CategoryId указывает на несуществующий id,
                            // нужно либо пропустить, либо подставить заглушку:
                            if (!catMap.TryGetValue(oldBook.CategoryId, out int newCatId))
                            {
                                // Пропустим книгу (или можно newCatId = 0)
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

                                // Самое главное: CategoryId = новый PK
                                CategoryId = newCatId
                            };

                            extendedBooks.Add(newBook);
                        }

                        // Сохраняем книги этого чанка
                        extendedContext.BooksInfo.AddRange(extendedBooks);
                        await extendedContext.SaveChangesAsync(token);
                    }

                    // Закрываем соединения, освобождаем SQLite connection pool
                    SqliteConnection.ClearAllPools();

                    processed += booksChunk.Count;

                    // 0..90%: остальное 10% зарезервируем на упаковку
                    int percent = (int)((double)processed / totalBooks * 90);
                    _progress[taskId] = percent;
                }

                // Небольшая пауза, чтобы гарантировать, что все файлы освобождены
                await Task.Delay(300, token);

                // 9) Создаём zip из tempFolder
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"export_{taskId}.zip");
                if (File.Exists(zipFilePath))
                    File.Delete(zipFilePath);
                ZipFile.CreateFromDirectory(tempFolder, zipFilePath);

                // Запоминаем путь к zip, чтобы потом отдавать файл
                _files[taskId] = zipFilePath;

                // Удаляем временную папку part_*.db
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
                _errors[taskId] = ex.ToString();
            }
            finally
            {
                _cancellationTokens.TryRemove(taskId, out _);
            }
        }


    }
}
