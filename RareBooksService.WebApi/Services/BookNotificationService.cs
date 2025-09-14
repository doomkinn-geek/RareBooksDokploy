using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using System.Text.RegularExpressions;

namespace RareBooksService.WebApi.Services
{
    public interface IBookNotificationService
    {
        Task<List<UserNotificationPreference>> GetActiveNotificationPreferencesAsync(CancellationToken cancellationToken = default);
        Task<List<RegularBaseBook>> FindMatchingBooksForUserAsync(UserNotificationPreference preference, DateTime sinceDate, CancellationToken cancellationToken = default);
        Task<bool> ShouldSendNotificationAsync(UserNotificationPreference preference, CancellationToken cancellationToken = default);
        Task<BookNotification> CreateNotificationAsync(UserNotificationPreference preference, RegularBaseBook book, List<string> matchedKeywords, CancellationToken cancellationToken = default);
        Task<bool> SendNotificationAsync(BookNotification notification, CancellationToken cancellationToken = default);
        Task MarkNotificationAsSentAsync(int notificationId, bool success, string errorMessage = null, CancellationToken cancellationToken = default);
        Task ProcessNotificationsAsync(CancellationToken cancellationToken = default);
        Task<int> ProcessNotificationsForNewBooksAsync(List<int> newBookIds, CancellationToken cancellationToken = default);
    }

    public class BookNotificationService : IBookNotificationService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<BookNotificationService> _logger;
        private readonly ITelegramNotificationService _telegramService;

        public BookNotificationService(
            IServiceScopeFactory scopeFactory,
            ILogger<BookNotificationService> logger,
            ITelegramNotificationService telegramService)
        {
            _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _telegramService = telegramService ?? throw new ArgumentNullException(nameof(telegramService));
        }

        public async Task<List<UserNotificationPreference>> GetActiveNotificationPreferencesAsync(CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            return await context.UserNotificationPreferences
                .Include(p => p.User)
                .Where(p => p.IsEnabled)
                .ToListAsync(cancellationToken);
        }

        public async Task<bool> ShouldSendNotificationAsync(UserNotificationPreference preference, CancellationToken cancellationToken = default)
        {
            if (!preference.IsEnabled) return false;

            // Проверяем частоту уведомлений
            if (preference.LastNotificationSent.HasValue)
            {
                var nextNotificationTime = preference.LastNotificationSent.Value.AddMinutes(preference.NotificationFrequencyMinutes);
                if (DateTime.UtcNow < nextNotificationTime)
                {
                    return false;
                }
            }

            return true;
        }

        public async Task<List<RegularBaseBook>> FindMatchingBooksForUserAsync(UserNotificationPreference preference, DateTime sinceDate, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

            var query = context.BooksInfo
                .Include(b => b.Category)
                .Where(b => b.BeginDate >= sinceDate); // Только новые книги

            // Фильтр по статусу (активные торги)
            query = query.Where(b => b.Status == 1); // Предполагаем, что 1 = активные торги

            // Фильтр по цене
            if (preference.MinPrice > 0)
            {
                query = query.Where(b => b.Price >= (double)preference.MinPrice);
            }
            if (preference.MaxPrice > 0)
            {
                query = query.Where(b => b.Price <= (double)preference.MaxPrice);
            }

            // Фильтр по году издания
            if (preference.MinYear > 0)
            {
                query = query.Where(b => b.YearPublished >= preference.MinYear);
            }
            if (preference.MaxYear > 0)
            {
                query = query.Where(b => b.YearPublished <= preference.MaxYear);
            }

            // Фильтр по категориям
            var categoryIds = preference.GetCategoryIdsList();
            if (categoryIds.Any())
            {
                query = query.Where(b => categoryIds.Contains(b.CategoryId));
            }

            // Фильтр по городам
            var cities = preference.GetCitiesList();
            if (cities.Any())
            {
                query = query.Where(b => cities.Contains(b.City.ToLower()));
            }

            var books = await query.ToListAsync(cancellationToken);

            // Фильтр по ключевым словам (в памяти, т.к. требует более сложной логики)
            var keywords = preference.GetKeywordsList();
            if (keywords.Any())
            {
                books = books.Where(book => ContainsKeywords(book, keywords)).ToList();
            }

            return books;
        }

        private bool ContainsKeywords(RegularBaseBook book, List<string> keywords)
        {
            if (!keywords.Any()) return true;

            var searchText = $"{book.Title} {book.Description} {string.Join(" ", book.Tags)}".ToLower();
            
            return keywords.Any(keyword => 
                searchText.Contains(keyword, StringComparison.OrdinalIgnoreCase) ||
                Regex.IsMatch(searchText, $@"\b{Regex.Escape(keyword)}\b", RegexOptions.IgnoreCase));
        }

        private List<string> GetMatchedKeywords(RegularBaseBook book, List<string> keywords)
        {
            var searchText = $"{book.Title} {book.Description} {string.Join(" ", book.Tags)}".ToLower();
            var matched = new List<string>();

            foreach (var keyword in keywords)
            {
                if (searchText.Contains(keyword, StringComparison.OrdinalIgnoreCase) ||
                    Regex.IsMatch(searchText, $@"\b{Regex.Escape(keyword)}\b", RegexOptions.IgnoreCase))
                {
                    matched.Add(keyword);
                }
            }

            return matched;
        }

        public async Task<BookNotification> CreateNotificationAsync(UserNotificationPreference preference, RegularBaseBook book, List<string> matchedKeywords, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var notification = new BookNotification
            {
                UserId = preference.UserId,
                BookId = book.Id,
                BookTitle = book.Title,
                BookDescription = book.Description,
                BookPrice = (decimal)book.Price,
                BookFinalPrice = book.FinalPrice.HasValue ? (decimal)book.FinalPrice.Value : null,
                BookCity = book.City,
                BookBeginDate = book.BeginDate,
                BookEndDate = book.EndDate,
                BookStatus = book.Status,
                DeliveryMethod = preference.DeliveryMethod,
                Status = NotificationStatus.Pending,
                Subject = $"Найдена интересная книга: {book.Title}",
                MatchedKeywords = string.Join(", ", matchedKeywords),
                UserNotificationPreferenceId = preference.Id,
                CreatedAt = DateTime.UtcNow
            };

            // Определяем адрес получателя в зависимости от способа доставки
            switch (preference.DeliveryMethod)
            {
                case NotificationDeliveryMethod.Email:
                    notification.RecipientAddress = preference.User.Email;
                    break;
                case NotificationDeliveryMethod.Telegram:
                    notification.RecipientAddress = preference.User.TelegramId;
                    break;
                default:
                    notification.RecipientAddress = preference.User.Email;
                    break;
            }

            context.BookNotifications.Add(notification);
            await context.SaveChangesAsync(cancellationToken);

            return notification;
        }

        public async Task<bool> SendNotificationAsync(BookNotification notification, CancellationToken cancellationToken = default)
        {
            try
            {
                notification.Status = NotificationStatus.Sending;
                notification.AttemptsCount++;

                using var scope = _scopeFactory.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();
                var booksContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                // Получаем актуальную информацию о книге
                var book = await booksContext.BooksInfo
                    .Include(b => b.Category)
                    .FirstOrDefaultAsync(b => b.Id == notification.BookId, cancellationToken);

                if (book == null)
                {
                    await MarkNotificationAsSentAsync(notification.Id, false, "Книга не найдена", cancellationToken);
                    return false;
                }

                var matchedKeywords = string.IsNullOrEmpty(notification.MatchedKeywords) 
                    ? new List<string>() 
                    : notification.MatchedKeywords.Split(", ").ToList();

                bool success = false;

                switch (notification.DeliveryMethod)
                {
                    case NotificationDeliveryMethod.Telegram:
                        success = await _telegramService.SendBookNotificationAsync(
                            notification.RecipientAddress, 
                            book, 
                            matchedKeywords, 
                            cancellationToken);
                        break;

                    case NotificationDeliveryMethod.Email:
                        // TODO: Реализовать отправку email
                        _logger.LogWarning("Email уведомления пока не реализованы");
                        success = false;
                        break;

                    default:
                        _logger.LogWarning("Неподдерживаемый способ доставки: {DeliveryMethod}", notification.DeliveryMethod);
                        success = false;
                        break;
                }

                await MarkNotificationAsSentAsync(notification.Id, success, success ? null : "Ошибка отправки", cancellationToken);

                return success;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке уведомления {NotificationId}", notification.Id);
                await MarkNotificationAsSentAsync(notification.Id, false, ex.Message, cancellationToken);
                return false;
            }
        }

        public async Task MarkNotificationAsSentAsync(int notificationId, bool success, string errorMessage = null, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var notification = await context.BookNotifications.FindAsync(notificationId);
            if (notification == null) return;

            if (success)
            {
                notification.Status = NotificationStatus.Sent;
                notification.SentAt = DateTime.UtcNow;
                notification.ErrorMessage = null;
            }
            else
            {
                notification.Status = NotificationStatus.Failed;
                notification.ErrorMessage = errorMessage;
                
                // Планируем повторную попытку через 30 минут для первых 3 попыток
                if (notification.AttemptsCount < 3)
                {
                    notification.NextAttemptAt = DateTime.UtcNow.AddMinutes(30);
                }
            }

            // Обновляем время последнего уведомления для пользователя
            if (success)
            {
                var preference = await context.UserNotificationPreferences
                    .FirstOrDefaultAsync(p => p.Id == notification.UserNotificationPreferenceId, cancellationToken);
                
                if (preference != null)
                {
                    preference.LastNotificationSent = DateTime.UtcNow;
                }
            }

            await context.SaveChangesAsync(cancellationToken);
        }

        public async Task ProcessNotificationsAsync(CancellationToken cancellationToken = default)
        {
            try
            {
                _logger.LogInformation("Начинаю обработку уведомлений...");

                // Обрабатываем неотправленные уведомления
                await ProcessPendingNotificationsAsync(cancellationToken);

                // Обрабатываем повторные попытки
                await ProcessRetryNotificationsAsync(cancellationToken);

                // Создаем новые уведомления для активных настроек
                await ProcessNewNotificationsAsync(cancellationToken);

                _logger.LogInformation("Обработка уведомлений завершена");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обработке уведомлений");
            }
        }

        public async Task<int> ProcessNotificationsForNewBooksAsync(List<int> newBookIds, CancellationToken cancellationToken = default)
        {
            if (!newBookIds?.Any() == true) return 0;

            int notificationsCreated = 0;

            try
            {
                var preferences = await GetActiveNotificationPreferencesAsync(cancellationToken);
                
                using var scope = _scopeFactory.CreateScope();
                var booksContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                var newBooks = await booksContext.BooksInfo
                    .Include(b => b.Category)
                    .Where(b => newBookIds.Contains(b.Id))
                    .ToListAsync(cancellationToken);

                foreach (var preference in preferences)
                {
                    if (!await ShouldSendNotificationAsync(preference, cancellationToken))
                        continue;

                    foreach (var book in newBooks)
                    {
                        // Проверяем соответствие книги критериям пользователя
                        if (DoesBookMatchPreference(book, preference))
                        {
                            var keywords = preference.GetKeywordsList();
                            var matchedKeywords = GetMatchedKeywords(book, keywords);

                            if (!keywords.Any() || matchedKeywords.Any())
                            {
                                var notification = await CreateNotificationAsync(preference, book, matchedKeywords, cancellationToken);
                                notificationsCreated++;

                                _logger.LogInformation("Создано уведомление {NotificationId} для пользователя {UserId} о книге {BookId}", 
                                    notification.Id, preference.UserId, book.Id);
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обработке уведомлений для новых книг");
            }

            return notificationsCreated;
        }

        private bool DoesBookMatchPreference(RegularBaseBook book, UserNotificationPreference preference)
        {
            // Проверка цены
            if (preference.MinPrice > 0 && book.Price < (double)preference.MinPrice) return false;
            if (preference.MaxPrice > 0 && book.Price > (double)preference.MaxPrice) return false;

            // Проверка года издания
            if (preference.MinYear > 0 && (!book.YearPublished.HasValue || book.YearPublished < preference.MinYear)) return false;
            if (preference.MaxYear > 0 && (!book.YearPublished.HasValue || book.YearPublished > preference.MaxYear)) return false;

            // Проверка категорий
            var categoryIds = preference.GetCategoryIdsList();
            if (categoryIds.Any() && !categoryIds.Contains(book.CategoryId)) return false;

            // Проверка городов
            var cities = preference.GetCitiesList();
            if (cities.Any() && !cities.Contains(book.City?.ToLower() ?? "")) return false;

            // Проверка статуса (только активные торги)
            if (book.Status != 1) return false;

            return true;
        }

        private async Task ProcessPendingNotificationsAsync(CancellationToken cancellationToken)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var pendingNotifications = await context.BookNotifications
                .Where(n => n.Status == NotificationStatus.Pending)
                .OrderBy(n => n.CreatedAt)
                .Take(50) // Обрабатываем по 50 уведомлений за раз
                .ToListAsync(cancellationToken);

            foreach (var notification in pendingNotifications)
            {
                await SendNotificationAsync(notification, cancellationToken);
                
                // Небольшая задержка между отправками
                await Task.Delay(100, cancellationToken);
            }
        }

        private async Task ProcessRetryNotificationsAsync(CancellationToken cancellationToken)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var retryNotifications = await context.BookNotifications
                .Where(n => n.Status == NotificationStatus.Failed && 
                           n.NextAttemptAt.HasValue && 
                           n.NextAttemptAt <= DateTime.UtcNow &&
                           n.AttemptsCount < 3)
                .OrderBy(n => n.NextAttemptAt)
                .Take(20)
                .ToListAsync(cancellationToken);

            foreach (var notification in retryNotifications)
            {
                await SendNotificationAsync(notification, cancellationToken);
                await Task.Delay(100, cancellationToken);
            }
        }

        private async Task ProcessNewNotificationsAsync(CancellationToken cancellationToken)
        {
            var preferences = await GetActiveNotificationPreferencesAsync(cancellationToken);
            var cutoffTime = DateTime.UtcNow.AddHours(-24); // Ищем книги за последние 24 часа

            foreach (var preference in preferences)
            {
                if (!await ShouldSendNotificationAsync(preference, cancellationToken))
                    continue;

                var sinceDate = preference.LastNotificationSent?.AddMinutes(-preference.NotificationFrequencyMinutes) ?? cutoffTime;
                var matchingBooks = await FindMatchingBooksForUserAsync(preference, sinceDate, cancellationToken);

                foreach (var book in matchingBooks.Take(5)) // Максимум 5 уведомлений за раз на пользователя
                {
                    var keywords = preference.GetKeywordsList();
                    var matchedKeywords = GetMatchedKeywords(book, keywords);

                    await CreateNotificationAsync(preference, book, matchedKeywords, cancellationToken);
                }
            }
        }
    }
}
