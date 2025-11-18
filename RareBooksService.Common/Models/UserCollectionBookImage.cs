using System;

namespace RareBooksService.Common.Models
{
    /// <summary>
    /// Изображение книги из коллекции пользователя
    /// </summary>
    public class UserCollectionBookImage
    {
        public int Id { get; set; }

        /// <summary>
        /// Ссылка на книгу из коллекции
        /// </summary>
        public int UserCollectionBookId { get; set; }
        public UserCollectionBook UserCollectionBook { get; set; }

        /// <summary>
        /// Имя файла изображения
        /// </summary>
        public string FileName { get; set; }

        /// <summary>
        /// Путь к файлу на сервере
        /// </summary>
        public string FilePath { get; set; }

        /// <summary>
        /// Дата загрузки изображения
        /// </summary>
        public DateTime UploadedDate { get; set; }

        /// <summary>
        /// Признак главного изображения
        /// </summary>
        public bool IsMainImage { get; set; }
    }
}

