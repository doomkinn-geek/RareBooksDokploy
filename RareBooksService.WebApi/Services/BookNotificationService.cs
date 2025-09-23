using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models;
using RareBooksService.Data;

namespace RareBooksService.WebApi.Services
{
    public interface IBookNotificationService
    {
        Task<List<UserNotificationPreference>> GetActiveNotificationPreferencesAsync(CancellationToken cancellationToken = default);
        Task<BookNotification> CreateNotificationAsync(UserNotificationPreference preference, RegularBaseBook book, List<string> matchedKeywords, CancellationToken cancellationToken = default);
        Task<bool> SendNotificationAsync(BookNotification notification, CancellationToken cancellationToken = default);
        Task MarkNotificationAsSentAsync(int notificationId, bool success, string errorMessage = null, CancellationToken cancellationToken = default);
        Task ProcessPendingNotificationsAsync(CancellationToken cancellationToken = default);
    }

    /// <summary>
    /// Упрощенный сервис уведомлений - только работа с БД
    /// Вся логика поиска и отправки перенесена в TelegramBotService
    /// </summary>
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

        public async Task<BookNotification> CreateNotificationAsync(UserNotificationPreference preference, RegularBaseBook book, List<string> matchedKeywords, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var notification = new BookNotification
            {
                UserId = preference.UserId,
                UserNotificationPreferenceId = preference.Id,
                BookId = book.Id,
                BookTitle = book.Title,
                BookPrice = (decimal)book.Price,
                BookEndDate = book.EndDate,
                MatchedKeywords = string.Join(", ", matchedKeywords),
                Status = NotificationStatus.Pending,
                CreatedAt = DateTime.UtcNow,
                DeliveryMethod = preference.DeliveryMethod
            };

            context.BookNotifications.Add(notification);
            await context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Создано уведомление {NotificationId} для пользователя {UserId} о книге {BookId}", 
                notification.Id, preference.UserId, book.Id);

            return notification;
        }

        public async Task<bool> SendNotificationAsync(BookNotification notification, CancellationToken cancellationToken = default)
        {
            try
            {
                // Для Telegram уведомлений используем TelegramNotificationService
                if (notification.DeliveryMethod == NotificationDeliveryMethod.Telegram)
                {
                    using var scope = _scopeFactory.CreateScope();
                    var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();
                    
                    var user = await context.Users.FirstOrDefaultAsync(u => u.Id == notification.UserId, cancellationToken);
                    
                    if (user?.TelegramId == null)
                    {
                        await MarkNotificationAsSentAsync(notification.Id, false, "Пользователь не имеет привязанного Telegram ID", cancellationToken);
                        return false;
                    }

                    var message = FormatNotificationMessage(notification);
                    var success = await _telegramService.SendNotificationAsync(user.TelegramId, message, cancellationToken);
                    
                    await MarkNotificationAsSentAsync(notification.Id, success, success ? null : "Ошибка отправки в Telegram", cancellationToken);
                    return success;
                }
                
                // Для других типов уведомлений (Email, etc.) - заглушка
                await MarkNotificationAsSentAsync(notification.Id, false, "Тип уведомления не поддерживается", cancellationToken);
                return false;
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
            if (notification != null)
            {
                notification.Status = success ? NotificationStatus.Sent : NotificationStatus.Failed;
                notification.SentAt = DateTime.UtcNow;
                notification.ErrorMessage = errorMessage;

                await context.SaveChangesAsync(cancellationToken);
            }
        }

        public async Task ProcessPendingNotificationsAsync(CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var pendingNotifications = await context.BookNotifications
                .Where(n => n.Status == NotificationStatus.Pending)
                .OrderBy(n => n.CreatedAt)
                .Take(50) // Обрабатываем по 50 уведомлений за раз
                .ToListAsync(cancellationToken);

            _logger.LogInformation("Обрабатываем {Count} отложенных уведомлений", pendingNotifications.Count);

            foreach (var notification in pendingNotifications)
            {
                await SendNotificationAsync(notification, cancellationToken);
            }
        }

        private string FormatNotificationMessage(BookNotification notification)
        {
            var timeLeft = notification.BookEndDate - DateTime.UtcNow;
            var timeLeftStr = timeLeft.TotalDays >= 1 
                ? $"{(int)timeLeft.TotalDays} дн."
                : $"{(int)timeLeft.TotalHours} ч.";

            return $"🔔 <b>Новый лот по вашим критериям!</b>\n\n" +
                   $"📚 <b>{notification.BookTitle}</b>\n" +
                   $"💰 {notification.BookPrice:N0} ₽\n" +
                   $"⏰ До окончания: {timeLeftStr}\n" +
                   $"🔗 <a href=\"https://meshok.net/item/{notification.BookId}\">Открыть лот №{notification.BookId}</a>\n\n" +
                   $"🔍 Найден по: {notification.MatchedKeywords}\n\n" +
                   $"⚙️ <code>/settings</code> - управление настройками";
        }
    }
}