using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using System.Collections.Concurrent;
using System.Text.Json;
using System.IO.Compression;

namespace RareBooksService.WebApi.Services
{
    public interface ISubscriptionPlanImportService
    {
        Guid StartImport(long expectedFileSize = 0);
        void WriteFileChunk(Guid importTaskId, byte[] buffer, int count);
        Task FinishFileUploadAsync(Guid importTaskId, CancellationToken cancellationToken = default);
        SubscriptionPlanImportProgressDto GetImportProgress(Guid importTaskId);
        Task CancelImportAsync(Guid importTaskId);
        void CleanupAllFiles();
        void UpdateExpectedFileSize(Guid importTaskId, long expectedFileSize);
    }

    /// <summary>DTO для прогресса импорта планов подписок</summary>
    public class SubscriptionPlanImportProgressDto
    {
        public double UploadProgress { get; set; }   // 0..100
        public double ImportProgress { get; set; }   // 0..100
        public bool IsFinished { get; set; }
        public bool IsCancelledOrError { get; set; }
        public string Message { get; set; }
    }

    /// <summary>
    /// Статистика импорта планов подписок
    /// </summary>
    public class SubscriptionPlanImportStats
    {
        public int PlansProcessed { get; set; } = 0;
        public int PlansImported { get; set; } = 0;
        public int PlansUpdated { get; set; } = 0;
        public int PlansSkipped { get; set; } = 0;
        public List<string> Errors { get; set; } = new List<string>();
    }

    public class SubscriptionPlanImportService : ISubscriptionPlanImportService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<SubscriptionPlanImportService> _logger;

        private static readonly ConcurrentDictionary<Guid, SubscriptionPlanImportTaskInfo> _tasks = 
            new ConcurrentDictionary<Guid, SubscriptionPlanImportTaskInfo>();

        private const int MAX_CONCURRENT_IMPORTS = 2;
        private const long MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 МБ максимальный размер файла планов

        public SubscriptionPlanImportService(IServiceScopeFactory scopeFactory, ILogger<SubscriptionPlanImportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        public Guid StartImport(long expectedFileSize = 0)
        {
            // Проверка на количество активных импортов
            if (_tasks.Count(t => !t.Value.IsCompleted && !t.Value.IsCancelledOrError) >= MAX_CONCURRENT_IMPORTS)
            {
                throw new InvalidOperationException($"Достигнут лимит одновременных импортов планов подписок ({MAX_CONCURRENT_IMPORTS}).");
            }

            // Проверка на максимальный размер файла
            if (expectedFileSize > MAX_FILE_SIZE)
            {
                throw new InvalidOperationException($"Размер файла ({expectedFileSize / (1024 * 1024)} МБ) превышает максимально допустимый ({MAX_FILE_SIZE / (1024 * 1024)} МБ).");
            }

            var importId = Guid.NewGuid();
            var info = new SubscriptionPlanImportTaskInfo(importId);
            
            if (expectedFileSize > 0)
            {
                info.ExpectedFileSize = expectedFileSize;
            }
            
            if (!_tasks.TryAdd(importId, info))
            {
                throw new InvalidOperationException("Не удалось создать задачу импорта планов подписок.");
            }
            
            _logger.LogInformation("Начат новый импорт планов подписок с ID: {ImportId}", importId);
            return importId;
        }

        public void UpdateExpectedFileSize(Guid importTaskId, long expectedFileSize)
        {
            if (expectedFileSize <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(expectedFileSize), "Ожидаемый размер файла должен быть положительным числом.");
            }

            if (expectedFileSize > MAX_FILE_SIZE)
            {
                throw new InvalidOperationException($"Размер файла превышает максимально допустимый ({MAX_FILE_SIZE / (1024 * 1024)} МБ).");
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
            
            if (taskInfo.BytesUploaded > 0)
            {
                taskInfo.UploadProgress = (double)taskInfo.BytesUploaded / expectedFileSize * 100.0;
            }
            
            _logger.LogInformation("Обновлен ожидаемый размер файла для импорта планов {ImportId}: {Size} байт", importTaskId, expectedFileSize);
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
                _logger.LogError(ex, "Ошибка при записи чанка файла планов для задачи {ImportId}", importTaskId);
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
                taskInfo.FileStream.Close();
                taskInfo.UploadProgress = 100.0;

                _logger.LogInformation("Завершена загрузка файла планов для импорта {ImportId}, начинаем обработку", importTaskId);

                // Запускаем импорт в фоне
                _ = Task.Run(() => ProcessImportAsync(importTaskId, cancellationToken), cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при завершении загрузки файла планов для импорта {ImportId}", importTaskId);
                taskInfo.IsCancelledOrError = true;
                taskInfo.Message = $"Ошибка при завершении загрузки: {ex.Message}";
                throw;
            }
        }

        private async Task ProcessImportAsync(Guid importTaskId, CancellationToken cancellationToken)
        {
            var stats = new SubscriptionPlanImportStats();
            
            try
            {
                if (!_tasks.TryGetValue(importTaskId, out var taskInfo))
                {
                    return;
                }

                taskInfo.ImportProgress = 5;
                taskInfo.Message = "Распаковка архива...";

                // Извлекаем архив
                var extractPath = Path.Combine(Path.GetTempPath(), $"subscription_plans_import_extract_{importTaskId}");
                if (Directory.Exists(extractPath))
                    Directory.Delete(extractPath, true);
                Directory.CreateDirectory(extractPath);

                ZipFile.ExtractToDirectory(taskInfo.TempFilePath, extractPath);

                cancellationToken.ThrowIfCancellationRequested();
                taskInfo.ImportProgress = 10;
                taskInfo.Message = "Чтение данных планов подписок...";

                // Читаем JSON файл
                var jsonFilePath = Path.Combine(extractPath, "subscription_plans.json");
                if (!File.Exists(jsonFilePath))
                {
                    throw new InvalidOperationException("Файл subscription_plans.json не найден в архиве");
                }

                var jsonContent = await File.ReadAllTextAsync(jsonFilePath);
                var options = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };

                var exportedPlans = JsonSerializer.Deserialize<List<ExportedSubscriptionPlan>>(jsonContent, options);
                if (exportedPlans == null || exportedPlans.Count == 0)
                {
                    throw new InvalidOperationException("Нет планов подписок для импорта");
                }

                cancellationToken.ThrowIfCancellationRequested();
                taskInfo.ImportProgress = 15;
                taskInfo.Message = $"Найдено {exportedPlans.Count} планов подписок для импорта...";

                using var scope = _scopeFactory.CreateScope();
                var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

                int processed = 0;
                
                foreach (var exportedPlan in exportedPlans)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    
                    try
                    {
                        stats.PlansProcessed++;

                        // Проверяем существует ли план с таким ID
                        var existingPlan = await usersContext.SubscriptionPlans
                            .FirstOrDefaultAsync(sp => sp.Id == exportedPlan.Id);

                        if (existingPlan != null)
                        {
                            // Обновляем существующий план
                            existingPlan.Name = exportedPlan.Name;
                            existingPlan.Description = exportedPlan.Description;
                            existingPlan.Price = exportedPlan.Price;
                            existingPlan.MonthlyRequestLimit = exportedPlan.MonthlyRequestLimit;
                            existingPlan.IsActive = exportedPlan.IsActive;

                            usersContext.SubscriptionPlans.Update(existingPlan);
                            stats.PlansUpdated++;
                            
                            _logger.LogInformation($"План подписки {exportedPlan.Name} (ID: {exportedPlan.Id}) обновлен");
                        }
                        else
                        {
                            // Создаем новый план
                            var newPlan = new SubscriptionPlan
                            {
                                Id = exportedPlan.Id,
                                Name = exportedPlan.Name,
                                Description = exportedPlan.Description,
                                Price = exportedPlan.Price,
                                MonthlyRequestLimit = exportedPlan.MonthlyRequestLimit,
                                IsActive = exportedPlan.IsActive
                            };

                            usersContext.SubscriptionPlans.Add(newPlan);
                            stats.PlansImported++;
                            
                            _logger.LogInformation($"План подписки {exportedPlan.Name} (ID: {exportedPlan.Id}) импортирован");
                        }

                        // Сохраняем изменения
                        await usersContext.SaveChangesAsync();

                        processed++;
                        var importProgress = 15 + (int)((double)processed / exportedPlans.Count * 80);
                        taskInfo.ImportProgress = Math.Min(importProgress, 95);
                        taskInfo.Message = $"Импортировано {processed}/{exportedPlans.Count} планов подписок";
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Ошибка импорта плана подписки {exportedPlan.Name}");
                        stats.Errors.Add($"Ошибка импорта плана {exportedPlan.Name}: {ex.Message}");
                        stats.PlansSkipped++;
                    }
                }

                // Финализация
                taskInfo.ImportProgress = 100;
                taskInfo.IsCompleted = true;
                taskInfo.Message = $"Импорт планов завершён. Импортировано: {stats.PlansImported}, " +
                                 $"Обновлено: {stats.PlansUpdated}, Пропущено: {stats.PlansSkipped}";

                if (stats.Errors.Any())
                {
                    taskInfo.Message += $". Ошибок: {stats.Errors.Count}";
                }

                _logger.LogInformation("Импорт планов подписок {ImportId} завершен. Импортировано: {Imported}, Обновлено: {Updated}, Пропущено: {Skipped}", 
                    importTaskId, stats.PlansImported, stats.PlansUpdated, stats.PlansSkipped);

                // Очистка временных файлов
                try
                {
                    File.Delete(taskInfo.TempFilePath);
                    Directory.Delete(extractPath, true);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Не удалось удалить временные файлы для импорта {ImportId}", importTaskId);
                }
            }
            catch (OperationCanceledException)
            {
                if (_tasks.TryGetValue(importTaskId, out var taskInfo))
                {
                    taskInfo.IsCancelledOrError = true;
                    taskInfo.Message = "Импорт отменён пользователем";
                }
                _logger.LogWarning("Импорт планов подписок {ImportId} был отменен", importTaskId);
            }
            catch (Exception ex)
            {
                if (_tasks.TryGetValue(importTaskId, out var taskInfo))
                {
                    taskInfo.IsCancelledOrError = true;
                    taskInfo.Message = $"Ошибка импорта: {ex.Message}";
                }
                _logger.LogError(ex, "Ошибка при импорте планов подписок {ImportId}", importTaskId);
            }
        }

        public SubscriptionPlanImportProgressDto GetImportProgress(Guid importTaskId)
        {
            if (!_tasks.TryGetValue(importTaskId, out var info))
            {
                _logger.LogWarning("Запрошен прогресс для несуществующей задачи импорта планов {ImportId}", importTaskId);
                return new SubscriptionPlanImportProgressDto
                {
                    IsCancelledOrError = true,
                    Message = "Задача не найдена"
                };
            }

            return new SubscriptionPlanImportProgressDto
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
                
                try
                {
                    if (info.FileStream != null && info.FileStream.CanWrite)
                    {
                        await info.FileStream.DisposeAsync();
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Ошибка при закрытии файлового потока для импорта планов {ImportId}", importTaskId);
                }
                
                info.IsCompleted = true;
                _logger.LogInformation("Задача импорта планов подписок {ImportId} отменена пользователем", importTaskId);
            }
        }

        public void CleanupAllFiles()
        {
            _logger.LogInformation("Запущена очистка всех временных файлов импорта планов подписок");
            
            foreach (var kvp in _tasks)
            {
                var info = kvp.Value;
                try
                {
                    if (info.FileStream != null)
                    {
                        try
                        {
                            info.FileStream.Close();
                            info.FileStream.Dispose();
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Ошибка при закрытии файлового потока для импорта планов {ImportId}", info.ImportTaskId);
                        }
                    }
                    
                    if (File.Exists(info.TempFilePath))
                    {
                        File.Delete(info.TempFilePath);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Ошибка при очистке ресурсов для импорта планов {ImportId}", info.ImportTaskId);
                }

                _tasks.TryRemove(kvp.Key, out _);
            }
            
            _logger.LogInformation("Очистка временных файлов импорта планов подписок завершена");
        }

        private class SubscriptionPlanImportTaskInfo : IDisposable
        {
            private bool _disposed = false;
            
            public SubscriptionPlanImportTaskInfo(Guid id)
            {
                ImportTaskId = id;
                TempFilePath = Path.Combine(Path.GetTempPath(), $"subscription_plans_import_{id}.zip");
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
                        FileStream?.Dispose();
                    }
                    
                    FileStream = null;
                    _disposed = true;
                }
            }
            
            ~SubscriptionPlanImportTaskInfo()
            {
                Dispose(false);
            }
        }
    }
} 