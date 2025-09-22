using System;
using System.Collections.Generic;

namespace RareBooksService.Common.Models
{
    /// <summary>
    /// Настройки уведомлений пользователя о появлении интересных книг
    /// </summary>
    public class UserNotificationPreference
    {
        public int Id { get; set; }

        /// <summary>
        /// Ссылка на пользователя
        /// </summary>
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }

        /// <summary>
        /// Включены ли уведомления для данного пользователя
        /// </summary>
        public bool IsEnabled { get; set; } = true;

        /// <summary>
        /// Ключевые слова для поиска интересных книг (разделенные запятой)
        /// Например: "Пушкин,прижизненное издание,автограф"
        /// </summary>
        public string Keywords { get; set; } = string.Empty;

        /// <summary>
        /// Интересующие категории книг (ID категорий через запятую)
        /// Если пусто - уведомления по всем категориям
        /// </summary>
        public string CategoryIds { get; set; } = string.Empty;

        /// <summary>
        /// Минимальная цена книги для уведомления (0 = без ограничений)
        /// </summary>
        public decimal MinPrice { get; set; } = 0;

        /// <summary>
        /// Максимальная цена книги для уведомления (0 = без ограничений)
        /// </summary>
        public decimal MaxPrice { get; set; } = 0;

        /// <summary>
        /// Минимальный год издания (0 = без ограничений)
        /// </summary>
        public int MinYear { get; set; } = 0;

        /// <summary>
        /// Максимальный год издания (0 = без ограничений)
        /// </summary>
        public int MaxYear { get; set; } = 0;

        /// <summary>
        /// Интересующие города (через запятую)
        /// Если пусто - уведомления по всем городам
        /// </summary>
        public string Cities { get; set; } = string.Empty;

        /// <summary>
        /// Частота отправки уведомлений в минутах
        /// По умолчанию: 60 минут (раз в час)
        /// </summary>
        public int NotificationFrequencyMinutes { get; set; } = 60;

        /// <summary>
        /// Способ доставки уведомлений (Email, SMS, Push и т.д.)
        /// </summary>
        public NotificationDeliveryMethod DeliveryMethod { get; set; } = NotificationDeliveryMethod.Telegram;

        /// <summary>
        /// Время последней отправки уведомления
        /// </summary>
        public DateTime? LastNotificationSent { get; set; }

        /// <summary>
        /// Дата создания настроек
        /// </summary>
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Дата последнего обновления настроек
        /// </summary>
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>
        /// Парсит строку с ключевыми словами в список
        /// </summary>
        public List<string> GetKeywordsList()
        {
            if (string.IsNullOrEmpty(Keywords))
                return new List<string>();

            return Keywords.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                          .Select(k => k.Trim().ToLower())
                          .Where(k => !string.IsNullOrEmpty(k))
                          .ToList();
        }

        /// <summary>
        /// Парсит строку с ID категорий в список чисел
        /// </summary>
        public List<int> GetCategoryIdsList()
        {
            if (string.IsNullOrEmpty(CategoryIds))
                return new List<int>();

            return CategoryIds.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                             .Select(c => c.Trim())
                             .Where(c => int.TryParse(c, out _))
                             .Select(int.Parse)
                             .ToList();
        }

        /// <summary>
        /// Парсит строку с городами в список
        /// </summary>
        public List<string> GetCitiesList()
        {
            if (string.IsNullOrEmpty(Cities))
                return new List<string>();

            return Cities.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                        .Select(c => c.Trim().ToLower())
                        .Where(c => !string.IsNullOrEmpty(c))
                        .ToList();
        }
    }

    /// <summary>
    /// Способы доставки уведомлений
    /// </summary>
    public enum NotificationDeliveryMethod
    {
        /// <summary>
        /// Электронная почта
        /// </summary>
        Email = 1,

        /// <summary>
        /// SMS
        /// </summary>
        SMS = 2,

        /// <summary>
        /// Push-уведомления в браузере
        /// </summary>
        Push = 3,

        /// <summary>
        /// Телеграм
        /// </summary>
        Telegram = 4
    }
}
