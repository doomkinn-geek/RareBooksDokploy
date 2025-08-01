 using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using System.Collections.Concurrent;
using Microsoft.Extensions.DependencyInjection;
using System.IO.Compression;
using Microsoft.Data.Sqlite;
using System.Text.Json;

namespace RareBooksService.WebApi.Services
{
    public interface IUserExportService
    {
        Task<Guid> StartExportAsync();
        ExportStatusDto GetStatus(Guid taskId);
        FileInfo GetExportedFile(Guid taskId);
        void CancelExport(Guid taskId);
        void CleanupAllFiles();
        IEnumerable<ActiveExportDto> GetActiveExports();
    }

    /// <summary>
    /// DTO для экспортированных данных пользователя
    /// </summary>
    public class ExportedUserData
    {
        public string Id { get; set; }
        public string UserName { get; set; }
        public string Email { get; set; }
        public bool EmailConfirmed { get; set; }
        public string PhoneNumber { get; set; }
        public bool PhoneNumberConfirmed { get; set; }
        public bool TwoFactorEnabled { get; set; }
        public bool LockoutEnabled { get; set; }
        public DateTimeOffset? LockoutEnd { get; set; }
        public int AccessFailedCount { get; set; }
        public bool HasSubscription { get; set; }
        public string Role { get; set; }
        
        // Связанные данные
        public List<ExportedUserSearchHistory> SearchHistory { get; set; } = new();
        public List<ExportedSubscription> Subscriptions { get; set; } = new();
        public List<ExportedUserFavoriteBook> FavoriteBooks { get; set; } = new();
    }

    public class ExportedUserSearchHistory
    {
        public string Query { get; set; }
        public DateTime SearchDate { get; set; }
        public string SearchType { get; set; }
    }

    public class ExportedSubscription
    {
        public int SubscriptionPlanId { get; set; }
        public string SubscriptionPlanName { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public bool IsActive { get; set; }
        public bool AutoRenew { get; set; }
        public string PaymentId { get; set; }
        public decimal PriceAtPurchase { get; set; }
        public int UsedRequestsThisPeriod { get; set; }
        public string PaymentMethodId { get; set; }
    }

    public class ExportedUserFavoriteBook
    {
        public int BookId { get; set; }
        public DateTime AddedDate { get; set; }
    }

    public class UserExportService : IUserExportService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<UserExportService> _logger;

        // Словари для хранения состояния экспорта
        private static ConcurrentDictionary<Guid, int> _progress = new ConcurrentDictionary<Guid, int>();
        private static ConcurrentDictionary<Guid, string> _errors = new ConcurrentDictionary<Guid, string>();
        private static ConcurrentDictionary<Guid, string> _files = new ConcurrentDictionary<Guid, string>();
        private static ConcurrentDictionary<Guid, CancellationTokenSource> _cancellationTokens = new ConcurrentDictionary<Guid, CancellationTokenSource>();

        private const int ChunkSize = 1000; // Меньший размер чанка для пользователей

        public UserExportService(IServiceScopeFactory scopeFactory, ILogger<UserExportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        public async Task<Guid> StartExportAsync()
        {
            // Очистка старых файлов
            CleanupOldExportFilesOnDisk();

            // Проверка активного экспорта
            bool anyActive = _progress.Values.Any(p => p >= 0 && p < 100);
            if (anyActive)
                throw new InvalidOperationException("Экспорт пользователей уже выполняется. Дождитесь завершения или отмените предыдущий экспорт.");

            var taskId = Guid.NewGuid();
            _progress[taskId] = 0;
            _errors[taskId] = string.Empty;

            var cts = new CancellationTokenSource();
            _cancellationTokens[taskId] = cts;

            // Запускаем экспорт в фоновом потоке
            _ = Task.Run(() => DoExport(taskId, cts.Token));
            return taskId;
        }

        private void CleanupOldExportFilesOnDisk()
        {
            try
            {
                string tempPath = Path.GetTempPath();

                // Удаляем все zip-файлы вида user_export_*.zip
                var oldZips = Directory.GetFiles(tempPath, "user_export_*.zip");
                foreach (var zip in oldZips)
                {
                    try
                    {
                        File.Delete(zip);
                    }
                    catch { /* ignore */ }
                }

                // Удаляем все подпапки вида user_export_*
                var oldDirs = Directory.GetDirectories(tempPath, "user_export_*");
                foreach (var dir in oldDirs)
                {
                    try
                    {
                        Directory.Delete(dir, true);
                    }
                    catch { /* ignore */ }
                }
            }
            catch { /* ignore */ }
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
                _progress[taskId] = 0;

                using var scope = _scopeFactory.CreateScope();
                var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

                // 1) Получаем общее количество пользователей
                int totalUsers = await usersContext.Users.CountAsync(token);
                if (totalUsers == 0)
                {
                    _progress[taskId] = 100;
                    return;
                }
                token.ThrowIfCancellationRequested();

                // 2) Создаём временную папку
                string tempFolder = Path.Combine(Path.GetTempPath(), $"user_export_{taskId}");
                if (!Directory.Exists(tempFolder))
                    Directory.CreateDirectory(tempFolder);

                int processed = 0;
                var allExportedUsers = new List<ExportedUserData>();

                // 3) Обрабатываем пользователей порциями
                while (processed < totalUsers)
                {
                    token.ThrowIfCancellationRequested();

                    var usersChunk = await usersContext.Users
                        .Include(u => u.SearchHistory)
                        .Include(u => u.Subscriptions)
                            .ThenInclude(s => s.SubscriptionPlan)
                        .Include(u => u.FavoriteBooks)
                        .OrderBy(u => u.Id)
                        .Skip(processed)
                        .Take(ChunkSize)
                        .AsNoTracking()
                        .ToListAsync(token);

                    if (usersChunk.Count == 0)
                        break;

                    // Конвертируем в DTO
                    foreach (var user in usersChunk)
                    {
                        token.ThrowIfCancellationRequested();

                        var exportedUser = new ExportedUserData
                        {
                            Id = user.Id,
                            UserName = user.UserName,
                            Email = user.Email,
                            EmailConfirmed = user.EmailConfirmed,
                            PhoneNumber = user.PhoneNumber,
                            PhoneNumberConfirmed = user.PhoneNumberConfirmed,
                            TwoFactorEnabled = user.TwoFactorEnabled,
                            LockoutEnabled = user.LockoutEnabled,
                            LockoutEnd = user.LockoutEnd,
                            AccessFailedCount = user.AccessFailedCount,
                            HasSubscription = user.HasSubscription,
                            Role = user.Role,
                            SearchHistory = user.SearchHistory?.Select(sh => new ExportedUserSearchHistory
                            {
                                Query = sh.Query,
                                SearchDate = sh.SearchDate,
                                SearchType = sh.SearchType
                            }).ToList() ?? new List<ExportedUserSearchHistory>(),
                            Subscriptions = user.Subscriptions?.Select(s => new ExportedSubscription
                            {
                                SubscriptionPlanId = s.SubscriptionPlanId,
                                SubscriptionPlanName = s.SubscriptionPlan?.Name,
                                StartDate = s.StartDate,
                                EndDate = s.EndDate,
                                IsActive = s.IsActive,
                                AutoRenew = s.AutoRenew,
                                PaymentId = s.PaymentId,
                                PriceAtPurchase = s.PriceAtPurchase,
                                UsedRequestsThisPeriod = s.UsedRequestsThisPeriod,
                                PaymentMethodId = s.PaymentMethodId
                            }).ToList() ?? new List<ExportedSubscription>(),
                            FavoriteBooks = user.FavoriteBooks?.Select(fb => new ExportedUserFavoriteBook
                            {
                                BookId = fb.BookId,
                                AddedDate = fb.AddedDate
                            }).ToList() ?? new List<ExportedUserFavoriteBook>()
                        };

                        allExportedUsers.Add(exportedUser);
                    }

                    processed += usersChunk.Count;

                    // Обновляем прогресс (0..80%)
                    int percent = (int)((double)processed / totalUsers * 80);
                    _progress[taskId] = percent;
                }

                // 4) Сохраняем в JSON файл
                _progress[taskId] = 85;
                string jsonFilePath = Path.Combine(tempFolder, "users_data.json");
                
                var options = new JsonSerializerOptions
                {
                    WriteIndented = true,
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };

                string jsonContent = JsonSerializer.Serialize(allExportedUsers, options);
                await File.WriteAllTextAsync(jsonFilePath, jsonContent, token);

                token.ThrowIfCancellationRequested();
                _progress[taskId] = 90;

                // 5) Создаём zip архив
                string zipFilePath = Path.Combine(Path.GetTempPath(), $"user_export_{taskId}.zip");
                if (File.Exists(zipFilePath))
                    File.Delete(zipFilePath);

                ZipFile.CreateFromDirectory(tempFolder, zipFilePath, CompressionLevel.Fastest, false);

                token.ThrowIfCancellationRequested();
                _progress[taskId] = 95;

                // Запоминаем путь к zip
                _files[taskId] = zipFilePath;

                // Удаляем временную папку
                Directory.Delete(tempFolder, true);

                // 100% - готово
                _progress[taskId] = 100;
            }
            catch (OperationCanceledException)
            {
                _progress[taskId] = -1;
                _errors[taskId] = "Экспорт пользователей отменён.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка экспорта пользователей");
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