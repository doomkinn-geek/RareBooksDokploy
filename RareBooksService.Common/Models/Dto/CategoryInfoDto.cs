using System;

namespace RareBooksService.Common.Models.Dto
{
    /// <summary>
    /// DTO для представления информации о категории с количеством книг
    /// </summary>
    public class CategoryInfoDto
    {
        /// <summary>
        /// Идентификатор категории
        /// </summary>
        public int Id { get; set; }

        /// <summary>
        /// Название категории
        /// </summary>
        public string Name { get; set; }

        /// <summary>
        /// Общее количество книг в категории (включая дубликаты)
        /// </summary>
        public int BooksCount { get; set; }

        /// <summary>
        /// Количество уникальных книг в категории
        /// </summary>
        public int UniqueBooksCount { get; set; }

        /// <summary>
        /// Количество книг, которые присутствуют только в этой категории
        /// </summary>
        public int ExclusiveBooksCount { get; set; }

        /// <summary>
        /// Флаг, указывающий является ли категория нежелательной
        /// </summary>
        public bool IsUnwanted { get; set; }

        /// <summary>
        /// Дата создания категории
        /// </summary>
        public DateTime CreatedDate { get; set; }

        /// <summary>
        /// Дата последнего обновления категории
        /// </summary>
        public DateTime? LastUpdatedDate { get; set; }

        /// <summary>
        /// Флаг, указывающий есть ли другие категории с таким же именем
        /// </summary>
        public bool HasDuplicates { get; set; }

        /// <summary>
        /// Количество категорий с таким же именем (включая текущую)
        /// </summary>
        public int DuplicateCount { get; set; }
    }
} 