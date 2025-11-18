using System;

namespace RareBooksService.Common.Models
{
    /// <summary>
    /// Найденный аналог книги из основной базы
    /// </summary>
    public class UserCollectionBookMatch
    {
        public int Id { get; set; }

        /// <summary>
        /// Ссылка на книгу из коллекции пользователя
        /// </summary>
        public int UserCollectionBookId { get; set; }
        public UserCollectionBook UserCollectionBook { get; set; }

        /// <summary>
        /// Ссылка на найденную книгу-аналог из основной базы
        /// </summary>
        public int MatchedBookId { get; set; }
        public RegularBaseBook MatchedBook { get; set; }

        /// <summary>
        /// Степень совпадения (0.0 - 1.0)
        /// </summary>
        public double MatchScore { get; set; }

        /// <summary>
        /// Дата нахождения аналога
        /// </summary>
        public DateTime FoundDate { get; set; }

        /// <summary>
        /// Выбран ли как референс для оценки
        /// </summary>
        public bool IsSelected { get; set; }
    }
}

