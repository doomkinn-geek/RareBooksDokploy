using System;
using System.Collections.Generic;

namespace RareBooksService.Common.Models
{
    /// <summary>
    /// Книга из личной коллекции пользователя
    /// </summary>
    public class UserCollectionBook
    {
        public int Id { get; set; }

        /// <summary>
        /// Идентификатор пользователя-владельца
        /// </summary>
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }

        /// <summary>
        /// Название книги
        /// </summary>
        public string Title { get; set; }

        /// <summary>
        /// Автор книги
        /// </summary>
        public string? Author { get; set; }

        /// <summary>
        /// Год издания
        /// </summary>
        public int? YearPublished { get; set; }

        /// <summary>
        /// Описание и состояние книги
        /// </summary>
        public string? Description { get; set; }

        /// <summary>
        /// Личные заметки пользователя
        /// </summary>
        public string? Notes { get; set; }

        /// <summary>
        /// Оценочная стоимость книги
        /// </summary>
        public decimal? EstimatedPrice { get; set; }

        /// <summary>
        /// Признак, что цена установлена вручную
        /// </summary>
        public bool IsManuallyPriced { get; set; }

        /// <summary>
        /// Ссылка на книгу-референс из основной базы
        /// </summary>
        public int? ReferenceBookId { get; set; }
        public RegularBaseBook? ReferenceBook { get; set; }

        /// <summary>
        /// Дата добавления книги в коллекцию
        /// </summary>
        public DateTime AddedDate { get; set; }

        /// <summary>
        /// Дата последнего обновления
        /// </summary>
        public DateTime UpdatedDate { get; set; }

        /// <summary>
        /// Изображения книги
        /// </summary>
        public List<UserCollectionBookImage> Images { get; set; } 
            = new List<UserCollectionBookImage>();

        /// <summary>
        /// Предложенные аналоги из базы
        /// </summary>
        public List<UserCollectionBookMatch> SuggestedMatches { get; set; }
            = new List<UserCollectionBookMatch>();
    }
}

