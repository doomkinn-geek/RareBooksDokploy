namespace RareBooksService.Common.Models.Dto
{
    /// <summary>
    /// DTO для статистики коллекции пользователя
    /// </summary>
    public class CollectionStatisticsDto
    {
        public int TotalBooks { get; set; }
        public decimal TotalEstimatedValue { get; set; }
        public int BooksWithEstimate { get; set; }
        public int BooksWithoutEstimate { get; set; }
        public int BooksWithReferenceBook { get; set; }
        public int TotalImages { get; set; }
    }
}

