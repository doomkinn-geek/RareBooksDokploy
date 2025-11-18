using System;

namespace RareBooksService.Common.Models.Dto
{
    /// <summary>
    /// DTO для изображения книги из коллекции
    /// </summary>
    public class UserCollectionBookImageDto
    {
        public int Id { get; set; }
        public int UserCollectionBookId { get; set; }
        public string FileName { get; set; }
        public string ImageUrl { get; set; }
        public DateTime UploadedDate { get; set; }
        public bool IsMainImage { get; set; }
    }
}

