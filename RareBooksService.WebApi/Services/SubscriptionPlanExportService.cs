using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using System.Collections.Concurrent;
using System.Text.Json;
using System.IO.Compression;

namespace RareBooksService.WebApi.Services
{
    public interface ISubscriptionPlanExportService
    {
        Task<Guid> StartExportAsync();
        ExportStatusDto GetStatus(Guid taskId);
        FileInfo GetExportedFile(Guid taskId);
        void CancelExport(Guid taskId);
        void CleanupAllFiles();
        IEnumerable<ActiveExportDto> GetActiveExports();
    }

    /// <summary>
    /// DTO для экспорта планов подписок
    /// </summary>
    public class ExportedSubscriptionPlan
    {
        public int Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public decimal Price { get; set; }
        public int MonthlyRequestLimit { get; set; }
        public bool IsActive { get; set; }
    }

    public class SubscriptionPlanExportService : ISubscriptionPlanExportService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<SubscriptionPlanExportService> _logger;

        // Словари для хранения состояния экспорта
        private static ConcurrentDictionary<Guid, int> _progress = new ConcurrentDictionary<Guid, int>();
        private static ConcurrentDictionary<Guid, string> _errors = new ConcurrentDictionary<Guid, string>();
        private static ConcurrentDictionary<Guid, string> _files = new ConcurrentDictionary<Guid, string>();
        private static ConcurrentDictionary<Guid, CancellationTokenSource> _cancellationTokens = new ConcurrentDictionary<Guid, CancellationTokenSource>();

        public SubscriptionPlanExportService(IServiceScopeFactory scopeFactory, ILogger<SubscriptionPlanExportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        public async Task<Guid> StartExportAsync()
        {
            // Проверяем, нет ли уже активного экспорта
            bool anyActive = _progress.Values.Any(p => p >= 0 && p < 100);
            if (anyActive)
            {
                _logger.LogWarning("Попытка запуска экспорта планов подписок при уже активном процессе");
                throw new InvalidOperationException("Экспорт планов подписок уже выполняется. Дождитесь завершения или отмените предыдущий экспорт.");
            }

            var taskId = Guid.NewGuid();
            _progress[taskId] = 0;
            _errors[taskId] = string.Empty;

            var cts = new CancellationTokenSource();
            _cancellationTokens[taskId] = cts;

            _logger.LogInformation($"Создана новая задача экспорта планов подписок, TaskId: {taskId}");

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
                cts.Cancel();
            }
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

        private async Task DoExport(Guid taskId, CancellationToken token)
        {
            try
            {
                _logger.LogInformation($"Начинаем экспорт планов подписок, TaskId: {taskId}");
                _progress[taskId] = 10;

                using var scope = _scopeFactory.CreateScope();
                var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

                // 1) Получаем все планы подписок
                _logger.LogInformation($"Загружаем планы подписок, TaskId: {taskId}");
                var subscriptionPlans = await usersContext.SubscriptionPlans
                    .AsNoTracking()
                    .OrderBy(sp => sp.Id)
                    .ToListAsync(token);

                _logger.LogInformation($"Найдено {subscriptionPlans.Count} планов подписок для экспорта, TaskId: {taskId}");
                
                token.ThrowIfCancellationRequested();
                _progress[taskId] = 30;

                // 2) Конвертируем в DTO
                var exportedPlans = subscriptionPlans.Select(plan => new ExportedSubscriptionPlan
                {
                    Id = plan.Id,
                    Name = plan.Name,
                    Description = plan.Description,
                    Price = plan.Price,
                    MonthlyRequestLimit = plan.MonthlyRequestLimit,
                    IsActive = plan.IsActive
                }).ToList();

                token.ThrowIfCancellationRequested();
                _progress[taskId] = 50;

                // 3) Создаём временную папку
                string tempFolder = Path.Combine(Path.GetTempPath(), $"subscription_plans_export_{taskId}");
                _logger.LogInformation($"Создаем временную папку: {tempFolder}, TaskId: {taskId}");
                if (Directory.Exists(tempFolder))
                    Directory.Delete(tempFolder, true);
                Directory.CreateDirectory(tempFolder);

                // 4) Сохраняем в JSON файл
                string jsonFilePath = Path.Combine(tempFolder, "subscription_plans.json");
                _logger.LogInformation($"Сохраняем {exportedPlans.Count} планов подписок в JSON файл: {jsonFilePath}, TaskId: {taskId}");
                
                var options = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    WriteIndented = true
                };

                var jsonContent = JsonSerializer.Serialize(exportedPlans, options);
                await File.WriteAllTextAsync(jsonFilePath, jsonContent, token);

                token.ThrowIfCancellationRequested();
                _progress[taskId] = 70;

                // 5) Создаём ZIP архив
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"subscription_plans_export_{taskId}.zip");
                _logger.LogInformation($"Создаем ZIP архив: {zipFilePath}, TaskId: {taskId}");
                
                if (File.Exists(zipFilePath))
                    File.Delete(zipFilePath);

                ZipFile.CreateFromDirectory(tempFolder, zipFilePath, CompressionLevel.Fastest, false);

                // Проверяем, что архив создался корректно
                if (!File.Exists(zipFilePath))
                {
                    throw new FileNotFoundException($"ZIP архив не был создан: {zipFilePath}");
                }

                var zipFileInfo = new FileInfo(zipFilePath);
                var zipSizeMB = zipFileInfo.Length / (1024.0 * 1024.0);
                _logger.LogInformation($"ZIP архив планов подписок создан успешно, размер: {zipSizeMB:F2} MB, TaskId: {taskId}");

                // Запоминаем путь к zip
                _files[taskId] = zipFilePath;

                // Удаляем временную папку
                try
                {
                    Directory.Delete(tempFolder, true);
                    _logger.LogInformation($"Временная папка удалена, TaskId: {taskId}");
                }
                catch (Exception deleteEx)
                {
                    _logger.LogWarning(deleteEx, $"Не удалось удалить временную папку {tempFolder}, TaskId: {taskId}");
                }

                // 100% – готово
                _progress[taskId] = 100;
                _logger.LogInformation($"Экспорт планов подписок завершен успешно, TaskId: {taskId}");
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning($"Экспорт планов подписок отменён пользователем, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = "Экспорт отменён пользователем.";
            }
            catch (OutOfMemoryException memEx)
            {
                _logger.LogError(memEx, $"Недостаточно памяти для экспорта планов подписок, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = "Недостаточно памяти для выполнения экспорта.";
            }
            catch (UnauthorizedAccessException accessEx)
            {
                _logger.LogError(accessEx, $"Ошибка доступа к файлам при экспорте планов подписок, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = "Ошибка доступа к временным файлам.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Неожиданная ошибка экспорта планов подписок, TaskId: {taskId}");
                _progress[taskId] = -1;
                _errors[taskId] = $"Неожиданная ошибка: {ex.Message}";
            }
            finally
            {
                _cancellationTokens.TryRemove(taskId, out _);
                _logger.LogInformation($"Задача экспорта планов подписок завершена, TaskId: {taskId}");
            }
        }
    }
} 