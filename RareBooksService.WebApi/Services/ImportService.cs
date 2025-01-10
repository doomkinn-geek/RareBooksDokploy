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
                // 1) Настраиваем подключения
                var sqliteOptions = new DbContextOptionsBuilder<ExtendedBooksContext>()
                    .UseSqlite($"Filename={taskInfo.TempFilePath}")
                    .Options;

                using var sourceContext = new ExtendedBooksContext(sqliteOptions);

                using var scope = _scopeFactory.CreateScope();
                var pgContext = scope.ServiceProvider.GetRequiredService<RegularBaseBooksContext>();

                // 2) Частями очищаем таблицу BooksInfo
                // Вместо:  var allBooks = pgContext.BooksInfo.ToList();
                // используем цикл, чтобы не грузить все в память.
                while (true)
                {
                    // Берём по 1000 книг
                    var chunk = pgContext.BooksInfo
                        .Take(1000)
                        .ToList();

                    if (chunk.Count == 0) break;

                    pgContext.BooksInfo.RemoveRange(chunk);
                    await pgContext.SaveChangesAsync();
                }

                // Очищаем Categories (обычно их мало, можно убрать chunk)
                var allCats = pgContext.Categories.ToList();
                pgContext.Categories.RemoveRange(allCats);
                await pgContext.SaveChangesAsync();

                // 3) Перенос категорий целиком
                var categories = await sourceContext.Categories.ToListAsync();
                int catCount = categories.Count;

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

                // Формируем словарь meshokId -> реальный PK (Id)
                var catMap = await pgContext.Categories
                    .ToDictionaryAsync(c => c.CategoryId, c => c.Id);

                // 4) Частями читаем книги из sourceContext (SQLite) и вставляем в PostgreSQL
                int pageSize = 1000;
                int pageIndex = 0;

                int processed = 0;
                int totalBooks; // общее число книг (узнаем один раз)

                // Получаем общее число книг (чтобы прогресс более точно считать).
                totalBooks = await sourceContext.BooksInfo.CountAsync();

                while (true)
                {
                    // Читаем кусок по 1000 книг
                    var chunk = await sourceContext.BooksInfo
                        .OrderBy(b => b.Id) // или OrderBy(b => b.CategoryId) - важно иметь порядок
                        .Skip(pageIndex * pageSize)
                        .Take(pageSize)
                        .Include(b => b.Category)  // т.к. мы используем bk.Category.CategoryId
                        .ToListAsync();

                    if (chunk.Count == 0) break; // всё прочитали

                    foreach (var bk in chunk)
                    {
                        // Пытаемся найти реальный PK категории
                        if (!catMap.TryGetValue(bk.Category.CategoryId, out var realCatId))
                        {
                            throw new Exception($"No matching category for meshokId={bk.CategoryId}");
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
                            PicsCount = bk.PicsCount
                        };

                        pgContext.BooksInfo.Add(newBook);
                        processed++;
                    }

                    // Сохраняем этот кусок
                    await pgContext.SaveChangesAsync();
                    //Это сбрасывает локальное отслеживание сущностей и позволяет отработать сборщику мусора
                    pgContext.ChangeTracker.Clear();

                    // Обновляем прогресс
                    taskInfo.ImportProgress = (double)processed / totalBooks * 100.0;

                    pageIndex++;
                }

                // 5) Завершаем
                taskInfo.ImportProgress = 100.0;
                taskInfo.IsCompleted = true;
                taskInfo.Message = $"Imported {processed} books (total), {catCount} categories.";
            }
            catch (Exception ex)
            {
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = "Error: " + ex.Message;
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
