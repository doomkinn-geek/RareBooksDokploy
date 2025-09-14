using System;

namespace RareBooksService.Common.Models
{
    /// <summary>
    /// История уведомлений о книгах, отправленных пользователям
    /// </summary>
    public class BookNotification
    {
        public int Id { get; set; }

        /// <summary>
        /// Ссылка на пользователя, которому отправлено уведомление
        /// </summary>
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }

        /// <summary>
        /// ID книги, по которой отправлено уведомление
        /// </summary>
        public int BookId { get; set; }

        /// <summary>
        /// Заголовок книги на момент отправки уведомления
        /// </summary>
        public string BookTitle { get; set; }

        /// <summary>
        /// Описание книги на момент отправки уведомления
        /// </summary>
        public string BookDescription { get; set; }

        /// <summary>
        /// Цена книги на момент отправки уведомления
        /// </summary>
        public decimal BookPrice { get; set; }

        /// <summary>
        /// Финальная цена, если аукцион завершен
        /// </summary>
        public decimal? BookFinalPrice { get; set; }

        /// <summary>
        /// Город продажи книги
        /// </summary>
        public string BookCity { get; set; }

        /// <summary>
        /// Дата начала торгов
        /// </summary>
        public DateTime BookBeginDate { get; set; }

        /// <summary>
        /// Дата окончания торгов
        /// </summary>
        public DateTime BookEndDate { get; set; }

        /// <summary>
        /// Статус книги (активная, завершена и т.д.)
        /// </summary>
        public int BookStatus { get; set; }

        /// <summary>
        /// Способ доставки уведомления
        /// </summary>
        public NotificationDeliveryMethod DeliveryMethod { get; set; }

        /// <summary>
        /// Статус доставки уведомления
        /// </summary>
        public NotificationStatus Status { get; set; }

        /// <summary>
        /// Тема письма/сообщения
        /// </summary>
        public string Subject { get; set; }

        /// <summary>
        /// Содержимое уведомления
        /// </summary>
        public string Content { get; set; }

        /// <summary>
        /// Адрес получателя (email, номер телефона, telegram id и т.д.)
        /// </summary>
        public string RecipientAddress { get; set; }

        /// <summary>
        /// Дата и время создания уведомления
        /// </summary>
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Дата и время отправки уведомления
        /// </summary>
        public DateTime? SentAt { get; set; }

        /// <summary>
        /// Дата и время доставки уведомления (если подтверждена)
        /// </summary>
        public DateTime? DeliveredAt { get; set; }

        /// <summary>
        /// Дата и время прочтения уведомления пользователем
        /// </summary>
        public DateTime? ReadAt { get; set; }

        /// <summary>
        /// Сообщение об ошибке, если доставка не удалась
        /// </summary>
        public string ErrorMessage { get; set; }

        /// <summary>
        /// Количество попыток отправки
        /// </summary>
        public int AttemptsCount { get; set; } = 0;

        /// <summary>
        /// Дата следующей попытки отправки (для повторных попыток)
        /// </summary>
        public DateTime? NextAttemptAt { get; set; }

        /// <summary>
        /// Ключевые слова, по которым сработало уведомление
        /// </summary>
        public string MatchedKeywords { get; set; }

        /// <summary>
        /// ID настройки уведомлений, по которой сработало уведомление
        /// </summary>
        public int UserNotificationPreferenceId { get; set; }
        public UserNotificationPreference UserNotificationPreference { get; set; }
    }

    /// <summary>
    /// Статус доставки уведомления
    /// </summary>
    public enum NotificationStatus
    {
        /// <summary>
        /// Создано, ожидает отправки
        /// </summary>
        Pending = 0,

        /// <summary>
        /// Отправляется
        /// </summary>
        Sending = 1,

        /// <summary>
        /// Успешно отправлено
        /// </summary>
        Sent = 2,

        /// <summary>
        /// Доставлено получателю
        /// </summary>
        Delivered = 3,

        /// <summary>
        /// Прочитано пользователем
        /// </summary>
        Read = 4,

        /// <summary>
        /// Ошибка отправки
        /// </summary>
        Failed = 5,

        /// <summary>
        /// Отменено
        /// </summary>
        Cancelled = 6
    }
}
