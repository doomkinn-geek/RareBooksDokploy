 using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Telegram;
using System.Collections.Concurrent;
using Microsoft.Extensions.DependencyInjection;
using System.IO.Compression;
using System.Text.Json;
using Microsoft.AspNetCore.Identity;

namespace RareBooksService.WebApi.Services
{
    public interface IUserImportService
    {
        Task<Guid> InitImportAsync(long fileSize);
        Task UploadChunkAsync(Guid importTaskId, byte[] chunkData);
        Task FinishUploadAsync(Guid importTaskId);
        UserImportProgressDto GetProgress(Guid importTaskId);
        Task CancelImportAsync(Guid importTaskId);
    }

    /// <summary>
    /// DTO для прогресса импорта пользователей
    /// </summary>
    public class UserImportProgressDto
    {
        public int UploadProgress { get; set; }
        public int ImportProgress { get; set; }
        public string Message { get; set; }
        public bool IsFinished { get; set; }
        public bool IsCancelledOrError { get; set; }
    }

    /// <summary>
    /// DTO для статистики импорта
    /// </summary>
    public class UserImportStats
    {
        public int UsersProcessed { get; set; }
        public int UsersImported { get; set; }
        public int UsersSkipped { get; set; }
        public int SearchHistoryImported { get; set; }
        public int SubscriptionsImported { get; set; }
        public int FavoriteBooksImported { get; set; }
        public int NotificationPreferencesImported { get; set; }
        public int BookNotificationsImported { get; set; }
        public int TelegramStatesImported { get; set; }
        public int TelegramTokensImported { get; set; }
        public List<string> Errors { get; set; } = new();
    }

    public class UserImportService : IUserImportService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<UserImportService> _logger;

        // Словари для состояния импорта
        private static ConcurrentDictionary<Guid, UserImportProgressDto> _importProgress = new();
        private static ConcurrentDictionary<Guid, string> _uploadPaths = new();
        private static ConcurrentDictionary<Guid, long> _fileSizes = new();
        private static ConcurrentDictionary<Guid, long> _uploadedBytes = new();
        private static ConcurrentDictionary<Guid, CancellationTokenSource> _cancellationTokens = new();

        public UserImportService(IServiceScopeFactory scopeFactory, ILogger<UserImportService> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        public async Task<Guid> InitImportAsync(long fileSize)
        {
            var importTaskId = Guid.NewGuid();
            
            // Создаем временный файл для загрузки
            var tempPath = Path.Combine(Path.GetTempPath(), $"user_import_{importTaskId}.zip");
            
            _importProgress[importTaskId] = new UserImportProgressDto
            {
                UploadProgress = 0,
                ImportProgress = 0,
                Message = "Инициализация импорта пользователей...",
                IsFinished = false,
                IsCancelledOrError = false
            };
            
            _uploadPaths[importTaskId] = tempPath;
            _fileSizes[importTaskId] = fileSize;
            _uploadedBytes[importTaskId] = 0;
            
            // Создаем пустой файл
            await File.WriteAllBytesAsync(tempPath, Array.Empty<byte>());
            
            _logger.LogInformation($"Инициализирован импорт пользователей {importTaskId}, размер файла: {fileSize} байт");
            
            return importTaskId;
        }

        public async Task UploadChunkAsync(Guid importTaskId, byte[] chunkData)
        {
            if (!_uploadPaths.TryGetValue(importTaskId, out var tempPath) ||
                !_fileSizes.TryGetValue(importTaskId, out var totalSize))
            {
                throw new InvalidOperationException("Импорт не найден или не инициализирован");
            }

            // Добавляем chunk к файлу
            await File.AppendAllTextAsync(tempPath, Convert.ToBase64String(chunkData));
            
            // Обновляем прогресс загрузки
            var currentBytes = _uploadedBytes[importTaskId] + chunkData.Length;
            _uploadedBytes[importTaskId] = currentBytes;
            
            var uploadProgress = totalSize > 0 ? (int)((currentBytes * 100) / totalSize) : 0;
            
            if (_importProgress.TryGetValue(importTaskId, out var progress))
            {
                progress.UploadProgress = Math.Min(uploadProgress, 100);
                progress.Message = $"Загружено {currentBytes}/{totalSize} байт";
            }
        }

        public async Task FinishUploadAsync(Guid importTaskId)
        {
            if (!_importProgress.TryGetValue(importTaskId, out var progress))
            {
                throw new InvalidOperationException("Импорт не найден");
            }

            progress.UploadProgress = 100;
            progress.Message = "Загрузка завершена. Начинаем обработку данных...";
            
            var cts = new CancellationTokenSource();
            _cancellationTokens[importTaskId] = cts;

            // Запускаем обработку в фоновом потоке
            _ = Task.Run(() => ProcessImportAsync(importTaskId, cts.Token));
        }

        public UserImportProgressDto GetProgress(Guid importTaskId)
        {
            if (_importProgress.TryGetValue(importTaskId, out var progress))
            {
                return progress;
            }

            return new UserImportProgressDto
            {
                UploadProgress = -1,
                ImportProgress = -1,
                Message = "Импорт не найден",
                IsFinished = true,
                IsCancelledOrError = true
            };
        }

        public async Task CancelImportAsync(Guid importTaskId)
        {
            if (_cancellationTokens.TryGetValue(importTaskId, out var cts))
            {
                cts.Cancel();
            }

            if (_importProgress.TryGetValue(importTaskId, out var progress))
            {
                progress.IsCancelledOrError = true;
                progress.Message = "Импорт отменён пользователем";
            }

            // Удаляем временный файл
            if (_uploadPaths.TryGetValue(importTaskId, out var tempPath) && File.Exists(tempPath))
            {
                try
                {
                    File.Delete(tempPath);
                }
                catch { /* ignore */ }
            }

            // Очищаем состояние
            _importProgress.TryRemove(importTaskId, out _);
            _uploadPaths.TryRemove(importTaskId, out _);
            _fileSizes.TryRemove(importTaskId, out _);
            _uploadedBytes.TryRemove(importTaskId, out _);
            _cancellationTokens.TryRemove(importTaskId, out _);
        }

        private async Task ProcessImportAsync(Guid importTaskId, CancellationToken cancellationToken)
        {
            var stats = new UserImportStats();
            
            try
            {
                if (!_uploadPaths.TryGetValue(importTaskId, out var tempPath) ||
                    !_importProgress.TryGetValue(importTaskId, out var progress))
                {
                    return;
                }

                progress.ImportProgress = 5;
                progress.Message = "Распаковка архива...";

                // Извлекаем архив
                var extractPath = Path.Combine(Path.GetTempPath(), $"user_import_extract_{importTaskId}");
                if (Directory.Exists(extractPath))
                    Directory.Delete(extractPath, true);
                Directory.CreateDirectory(extractPath);

                // Декодируем Base64 файл обратно в zip
                var base64Content = await File.ReadAllTextAsync(tempPath);
                var zipBytes = Convert.FromBase64String(base64Content);
                var realZipPath = Path.Combine(Path.GetTempPath(), $"user_import_real_{importTaskId}.zip");
                await File.WriteAllBytesAsync(realZipPath, zipBytes);

                ZipFile.ExtractToDirectory(realZipPath, extractPath);

                cancellationToken.ThrowIfCancellationRequested();
                progress.ImportProgress = 10;
                progress.Message = "Чтение данных пользователей...";

                // Читаем JSON файл
                var jsonFilePath = Path.Combine(extractPath, "users_data.json");
                if (!File.Exists(jsonFilePath))
                {
                    throw new InvalidOperationException("Файл users_data.json не найден в архиве");
                }

                var jsonContent = await File.ReadAllTextAsync(jsonFilePath);
                var options = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };

                var exportedUsers = JsonSerializer.Deserialize<List<ExportedUserData>>(jsonContent, options);
                if (exportedUsers == null || exportedUsers.Count == 0)
                {
                    throw new InvalidOperationException("Нет данных для импорта");
                }

                cancellationToken.ThrowIfCancellationRequested();
                progress.ImportProgress = 15;
                progress.Message = $"Найдено {exportedUsers.Count} пользователей для импорта...";

                using var scope = _scopeFactory.CreateScope();
                var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();
                var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

                int processed = 0;
                
                foreach (var exportedUser in exportedUsers)
                {
                    cancellationToken.ThrowIfCancellationRequested();
                    
                    try
                    {
                        stats.UsersProcessed++;
                        
                        // Проверяем, существует ли пользователь
                        var existingUser = await userManager.FindByEmailAsync(exportedUser.Email);
                        if (existingUser != null)
                        {
                            stats.UsersSkipped++;
                            _logger.LogWarning($"Пользователь с email {exportedUser.Email} уже существует, пропускаем");
                            continue;
                        }

                        // Проверяем, что ID еще не занят
                        var existingById = await usersContext.Users.FirstOrDefaultAsync(u => u.Id == exportedUser.Id);
                        var finalUserId = exportedUser.Id;
                        if (existingById != null)
                        {
                            // Генерируем новый ID если старый занят
                            finalUserId = Guid.NewGuid().ToString();
                            _logger.LogWarning($"ID {exportedUser.Id} уже занят, используем новый: {finalUserId}");
                        }

                        // Создаем нового пользователя со всеми данными авторизации
                        var newUser = new ApplicationUser
                        {
                            Id = finalUserId,
                            UserName = exportedUser.UserName,
                            NormalizedUserName = exportedUser.NormalizedUserName,
                            Email = exportedUser.Email,
                            NormalizedEmail = exportedUser.NormalizedEmail,
                            EmailConfirmed = exportedUser.EmailConfirmed,
                            PhoneNumber = exportedUser.PhoneNumber,
                            PhoneNumberConfirmed = exportedUser.PhoneNumberConfirmed,
                            TwoFactorEnabled = exportedUser.TwoFactorEnabled,
                            LockoutEnabled = exportedUser.LockoutEnabled,
                            LockoutEnd = exportedUser.LockoutEnd,
                            AccessFailedCount = exportedUser.AccessFailedCount,
                            HasSubscription = exportedUser.HasSubscription,
                            Role = exportedUser.Role,
                            CreatedAt = exportedUser.CreatedAt == default ? DateTime.UtcNow : exportedUser.CreatedAt,
                            
                            // Telegram поля
                            TelegramId = exportedUser.TelegramId,
                            TelegramUsername = exportedUser.TelegramUsername,
                            
                            // Восстанавливаем критически важные поля для авторизации
                            PasswordHash = exportedUser.PasswordHash,
                            SecurityStamp = exportedUser.SecurityStamp ?? Guid.NewGuid().ToString(),
                            ConcurrencyStamp = exportedUser.ConcurrencyStamp ?? Guid.NewGuid().ToString()
                        };

                        // Добавляем пользователя напрямую в контекст, чтобы сохранить PasswordHash
                        usersContext.Users.Add(newUser);
                        
                        try
                        {
                            await usersContext.SaveChangesAsync();
                            _logger.LogInformation($"Пользователь {exportedUser.Email} успешно импортирован с ID: {finalUserId}");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, $"Ошибка сохранения пользователя {exportedUser.Email}");
                            stats.Errors.Add($"Ошибка сохранения пользователя {exportedUser.Email}: {ex.Message}");
                            continue;
                        }

                        stats.UsersImported++;

                        // Импортируем историю поиска
                        foreach (var searchHistory in exportedUser.SearchHistory)
                        {
                            var newSearchHistory = new UserSearchHistory
                            {
                                UserId = finalUserId,
                                Query = searchHistory.Query,
                                SearchDate = searchHistory.SearchDate,
                                SearchType = searchHistory.SearchType
                            };
                            usersContext.UserSearchHistories.Add(newSearchHistory);
                            stats.SearchHistoryImported++;
                        }

                        // Импортируем избранные книги
                        foreach (var favoriteBook in exportedUser.FavoriteBooks)
                        {
                            var newFavoriteBook = new UserFavoriteBook
                            {
                                UserId = finalUserId,
                                BookId = favoriteBook.BookId,
                                AddedDate = favoriteBook.AddedDate
                            };
                            usersContext.UserFavoriteBooks.Add(newFavoriteBook);
                            stats.FavoriteBooksImported++;
                        }

                        // Импортируем подписки (требует существующих планов)
                        foreach (var subscription in exportedUser.Subscriptions)
                        {
                            var existingPlan = await usersContext.SubscriptionPlans
                                .FirstOrDefaultAsync(sp => sp.Id == subscription.SubscriptionPlanId);
                            
                            if (existingPlan != null)
                            {
                                var newSubscription = new Subscription
                                {
                                    UserId = finalUserId,
                                    SubscriptionPlanId = subscription.SubscriptionPlanId,
                                    StartDate = subscription.StartDate,
                                    EndDate = subscription.EndDate,
                                    IsActive = subscription.IsActive,
                                    AutoRenew = subscription.AutoRenew,
                                    PaymentId = subscription.PaymentId,
                                    PriceAtPurchase = subscription.PriceAtPurchase,
                                    UsedRequestsThisPeriod = subscription.UsedRequestsThisPeriod,
                                    PaymentMethodId = subscription.PaymentMethodId
                                };
                                usersContext.Subscriptions.Add(newSubscription);
                                stats.SubscriptionsImported++;
                            }
                            else
                            {
                                stats.Errors.Add($"План подписки {subscription.SubscriptionPlanId} не найден для пользователя {exportedUser.Email}");
                            }
                        }

                        // Импортируем настройки уведомлений
                        foreach (var notificationPref in exportedUser.NotificationPreferences)
                        {
                            var newNotificationPref = new UserNotificationPreference
                            {
                                UserId = finalUserId,
                                Keywords = notificationPref.Keywords,
                                Cities = notificationPref.Cities,
                                CategoryIds = notificationPref.CategoryIds,
                                MinPrice = notificationPref.MinPrice ?? 0,
                                MaxPrice = notificationPref.MaxPrice ?? 0,
                                MinYear = notificationPref.MinYear ?? 0,
                                MaxYear = notificationPref.MaxYear ?? 0,
                                DeliveryMethod = (NotificationDeliveryMethod)notificationPref.DeliveryMethod,
                                IsEnabled = notificationPref.IsEnabled,
                                NotificationFrequencyMinutes = notificationPref.NotificationFrequencyMinutes,
                                LastNotificationSent = notificationPref.LastNotificationSent,
                                CreatedAt = notificationPref.CreatedAt == default ? DateTime.UtcNow : notificationPref.CreatedAt,
                                UpdatedAt = DateTime.UtcNow
                            };
                            usersContext.UserNotificationPreferences.Add(newNotificationPref);
                            stats.NotificationPreferencesImported++;
                        }

                        // Импортируем уведомления о книгах
                        foreach (var bookNotification in exportedUser.BookNotifications)
                        {
                            var newBookNotification = new BookNotification
                            {
                                UserId = finalUserId,
                                BookId = bookNotification.BookId,
                                BookTitle = bookNotification.BookTitle,
                                BookPrice = bookNotification.BookPrice,
                                Status = (NotificationStatus)bookNotification.Status,
                                CreatedAt = bookNotification.CreatedAt == default ? DateTime.UtcNow : bookNotification.CreatedAt,
                                SentAt = bookNotification.SentAt,
                                ErrorMessage = bookNotification.ErrorMessage,
                                AttemptsCount = bookNotification.AttemptsCount
                            };
                            usersContext.BookNotifications.Add(newBookNotification);
                            stats.BookNotificationsImported++;
                        }

                        // Импортируем состояния Telegram (если есть TelegramId)
                        if (!string.IsNullOrEmpty(exportedUser.TelegramId))
                        {
                            foreach (var telegramState in exportedUser.TelegramUserStates)
                            {
                                var newTelegramState = new TelegramUserState
                                {
                                    TelegramId = telegramState.TelegramId,
                                    State = telegramState.State,
                                    StateData = telegramState.StateData,
                                    CreatedAt = telegramState.CreatedAt == default ? DateTime.UtcNow : telegramState.CreatedAt,
                                    UpdatedAt = telegramState.UpdatedAt == default ? DateTime.UtcNow : telegramState.UpdatedAt
                                };
                                usersContext.TelegramUserStates.Add(newTelegramState);
                                stats.TelegramStatesImported++;
                            }
                        }

                        // Импортируем токены привязки Telegram
                        foreach (var telegramToken in exportedUser.TelegramLinkTokens)
                        {
                            var newTelegramToken = new TelegramLinkToken
                            {
                                UserId = finalUserId,
                                Token = telegramToken.Token,
                                ExpiresAt = telegramToken.ExpiresAt,
                                CreatedAt = telegramToken.CreatedAt == default ? DateTime.UtcNow : telegramToken.CreatedAt,
                                IsUsed = telegramToken.IsUsed,
                                UsedAt = telegramToken.UsedAt
                            };
                            usersContext.TelegramLinkTokens.Add(newTelegramToken);
                            stats.TelegramTokensImported++;
                        }

                        // Сохраняем связанные данные
                        await usersContext.SaveChangesAsync();

                        processed++;
                        var importProgress = 15 + (int)((double)processed / exportedUsers.Count * 80);
                        progress.ImportProgress = Math.Min(importProgress, 95);
                        progress.Message = $"Импортировано {processed}/{exportedUsers.Count} пользователей";
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, $"Ошибка импорта пользователя {exportedUser.Email}");
                        stats.Errors.Add($"Ошибка импорта пользователя {exportedUser.Email}: {ex.Message}");
                    }
                }

                // Финализация
                progress.ImportProgress = 100;
                progress.IsFinished = true;
                progress.Message = $"Импорт завершён. Пользователей: {stats.UsersImported}/{stats.UsersProcessed}, " +
                                 $"История поиска: {stats.SearchHistoryImported}, " +
                                 $"Подписки: {stats.SubscriptionsImported}, " +
                                 $"Избранное: {stats.FavoriteBooksImported}, " +
                                 $"Настройки уведомлений: {stats.NotificationPreferencesImported}, " +
                                 $"Уведомления о книгах: {stats.BookNotificationsImported}, " +
                                 $"Состояния Telegram: {stats.TelegramStatesImported}, " +
                                 $"Токены Telegram: {stats.TelegramTokensImported}";

                if (stats.Errors.Any())
                {
                    progress.Message += $". Ошибок: {stats.Errors.Count}";
                }

                // Очистка временных файлов
                try
                {
                    File.Delete(tempPath);
                    File.Delete(realZipPath);
                    Directory.Delete(extractPath, true);
                }
                catch { /* ignore */ }

                _logger.LogInformation($"Импорт пользователей {importTaskId} завершён: {stats.UsersImported} пользователей, " +
                    $"{stats.NotificationPreferencesImported} настроек уведомлений, " +
                    $"{stats.BookNotificationsImported} уведомлений о книгах, " +
                    $"{stats.TelegramStatesImported} состояний Telegram, " +
                    $"{stats.TelegramTokensImported} токенов Telegram, " +
                    $"{stats.Errors.Count} ошибок");
            }
            catch (OperationCanceledException)
            {
                if (_importProgress.TryGetValue(importTaskId, out var progress))
                {
                    progress.IsCancelledOrError = true;
                    progress.Message = "Импорт отменён пользователем";
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Критическая ошибка импорта пользователей {importTaskId}");
                if (_importProgress.TryGetValue(importTaskId, out var progress))
                {
                    progress.IsCancelledOrError = true;
                    progress.Message = $"Критическая ошибка: {ex.Message}";
                }
            }
            finally
            {
                _cancellationTokens.TryRemove(importTaskId, out _);
            }
        }
    }
}