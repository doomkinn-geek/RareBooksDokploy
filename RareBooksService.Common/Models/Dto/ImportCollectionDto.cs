using System;
using System.Collections.Generic;

namespace RareBooksService.Common.Models.Dto
{
    public class ImportCollectionRequest
    {
        public DateTime ExportDate { get; set; }
        public int TotalBooks { get; set; }
        public List<ImportBookData> Books { get; set; }
    }

    public class ImportBookData
    {
        public string Title { get; set; }
        public string Author { get; set; }
        public int? YearPublished { get; set; }
        public DateTime? PurchaseDate { get; set; }
        public decimal? PurchasePrice { get; set; }
        public decimal? DeliveryCost { get; set; }
        public decimal? TotalPurchasePrice { get; set; }
        public decimal? SoldPrice { get; set; }
        public DateTime? SoldDate { get; set; }
        public string SaleNotes { get; set; }
        public string Comments { get; set; }
        public string Notes { get; set; }
        public bool IsSold { get; set; }
    }

    public class ImportCollectionResponse
    {
        public bool Success { get; set; }
        public int ImportedBooks { get; set; }
        public int SkippedBooks { get; set; }
        public List<string> Errors { get; set; } = new List<string>();
        public string Message { get; set; }
    }
}

