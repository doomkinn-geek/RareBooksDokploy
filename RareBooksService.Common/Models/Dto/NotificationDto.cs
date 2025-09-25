using System;
using System.ComponentModel.DataAnnotations;

namespace RareBooksService.Common.Models
{
    /// <summary>
    /// DTO для настроек уведомлений пользователя
    /// </summary>
    public class UserNotificationPreferenceDto
    {
        public int Id { get; set; }
        public bool IsEnabled { get; set; }
        public string Keywords { get; set; } = string.Empty;
        public bool IsExactMatch { get; set; } = false;
        public string CategoryIds { get; set; } = string.Empty;
        public decimal MinPrice { get; set; }
        public decimal MaxPrice { get; set; }
        public int MinYear { get; set; }
        public int MaxYear { get; set; }
        public string Cities { get; set; } = string.Empty;
        public int NotificationFrequencyMinutes { get; set; }
        public NotificationDeliveryMethod DeliveryMethod { get; set; }
        public DateTime? LastNotificationSent { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    /// <summary>
    /// DTO для создания новых настроек уведомлений
    /// </summary>
    public class CreateNotificationPreferenceDto
    {
        [Required]
        public bool IsEnabled { get; set; } = true;

        [MaxLength(2000)]
        public string? Keywords { get; set; }

        public bool IsExactMatch { get; set; } = false;

        [MaxLength(500)]
        public string? CategoryIds { get; set; }

        [Range(0, 999999.99)]
        public decimal MinPrice { get; set; } = 0;

        [Range(0, 999999.99)]
        public decimal MaxPrice { get; set; } = 0;

        [Range(0, 2100)]
        public int MinYear { get; set; } = 0;

        [Range(0, 2100)]
        public int MaxYear { get; set; } = 0;

        [MaxLength(1000)]
        public string? Cities { get; set; }

        [Range(5, 10080)] // От 5 минут до недели
        public int NotificationFrequencyMinutes { get; set; } = 60;

        [Required]
        public NotificationDeliveryMethod DeliveryMethod { get; set; } = NotificationDeliveryMethod.Email;
    }

    /// <summary>
    /// DTO для обновления настроек уведомлений
    /// </summary>
    public class UpdateNotificationPreferenceDto
    {
        [Required]
        public bool IsEnabled { get; set; }

        [MaxLength(2000)]
        public string? Keywords { get; set; }

        public bool IsExactMatch { get; set; } = false;

        [MaxLength(500)]
        public string? CategoryIds { get; set; }

        [Range(0, 999999.99)]
        public decimal MinPrice { get; set; }

        [Range(0, 999999.99)]
        public decimal MaxPrice { get; set; }

        [Range(0, 2100)]
        public int MinYear { get; set; }

        [Range(0, 2100)]
        public int MaxYear { get; set; }

        [MaxLength(1000)]
        public string? Cities { get; set; }

        [Range(5, 10080)] // От 5 минут до недели
        public int NotificationFrequencyMinutes { get; set; }

        [Required]
        public NotificationDeliveryMethod DeliveryMethod { get; set; }
    }

    /// <summary>
    /// DTO для истории уведомлений
    /// </summary>
    public class BookNotificationDto
    {
        public int Id { get; set; }
        public int BookId { get; set; }
        public string BookTitle { get; set; }
        public string BookDescription { get; set; }
        public decimal BookPrice { get; set; }
        public decimal? BookFinalPrice { get; set; }
        public string BookCity { get; set; }
        public DateTime BookBeginDate { get; set; }
        public DateTime BookEndDate { get; set; }
        public int BookStatus { get; set; }
        public NotificationDeliveryMethod DeliveryMethod { get; set; }
        public NotificationStatus Status { get; set; }
        public string Subject { get; set; }
        public string MatchedKeywords { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? SentAt { get; set; }
        public DateTime? DeliveredAt { get; set; }
        public DateTime? ReadAt { get; set; }
        public string ErrorMessage { get; set; }
        public int AttemptsCount { get; set; }
    }

    /// <summary>
    /// DTO для связывания аккаунта с Telegram
    /// </summary>
    public class ConnectTelegramDto
    {
        [Required]
        [MaxLength(50)]
        public string TelegramId { get; set; }

        [MaxLength(100)]
        public string? TelegramUsername { get; set; }
    }

    /// <summary>
    /// DTO для статуса подключения к Telegram
    /// </summary>
    public class TelegramStatusDto
    {
        public bool IsConnected { get; set; }
        public string TelegramId { get; set; }
        public string TelegramUsername { get; set; }
        public string BotUsername { get; set; }
    }

    /// <summary>
    /// DTO для отправки тестового уведомления
    /// </summary>
    public class SendTestNotificationDto
    {
        [Required]
        public NotificationDeliveryMethod DeliveryMethod { get; set; }
    }

    /// <summary>
    /// Результат с пагинацией
    /// </summary>
    public class PagedResult<T>
    {
        public List<T> Items { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
        public int TotalPages { get; set; }
        public bool HasNextPage => Page < TotalPages;
        public bool HasPreviousPage => Page > 1;
    }
}
