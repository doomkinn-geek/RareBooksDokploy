namespace RareBooksService.Common.Models.Dto
{
    using System;

    /// <summary>
    /// Запрос на обновление книги в коллекции
    /// </summary>
    public class UpdateCollectionBookRequest
    {
        public string Title { get; set; }
        public string? Author { get; set; }
        public int? YearPublished { get; set; }
        public string? Description { get; set; }
        public string? Notes { get; set; }
        public decimal? EstimatedPrice { get; set; }
        public bool IsManuallyPriced { get; set; }
        public decimal? PurchasePrice { get; set; }
        public DateTime? PurchaseDate { get; set; }
        public bool IsSold { get; set; }
        public decimal? SoldPrice { get; set; }
        public DateTime? SoldDate { get; set; }
    }
}

