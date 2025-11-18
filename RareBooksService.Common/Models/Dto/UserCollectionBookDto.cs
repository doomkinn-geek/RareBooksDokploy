using System;

namespace RareBooksService.Common.Models.Dto
{
    /// <summary>
    /// DTO для книги из коллекции пользователя (список)
    /// </summary>
    public class UserCollectionBookDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string? Author { get; set; }
        public int? YearPublished { get; set; }
        public decimal? EstimatedPrice { get; set; }
        public bool IsManuallyPriced { get; set; }
        public DateTime AddedDate { get; set; }
        public DateTime UpdatedDate { get; set; }
        public string? MainImageUrl { get; set; }
        public int ImagesCount { get; set; }
        public bool HasReferenceBook { get; set; }
    }
}

