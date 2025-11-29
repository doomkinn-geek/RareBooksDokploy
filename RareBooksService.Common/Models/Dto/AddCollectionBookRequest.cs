namespace RareBooksService.Common.Models.Dto
{
    using System;

    /// <summary>
    /// Запрос на добавление книги в коллекцию
    /// </summary>
    public class AddCollectionBookRequest
    {
        public string Title { get; set; }
        public string? Author { get; set; }
        public int? YearPublished { get; set; }
        public string? Description { get; set; }
        public string? Notes { get; set; }
        public decimal? PurchasePrice { get; set; }
        public DateTime? PurchaseDate { get; set; }
    }
}

