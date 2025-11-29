using System;
using System.Collections.Generic;

namespace RareBooksService.Common.Models.Dto
{
    /// <summary>
    /// DTO для детальной информации о книге из коллекции
    /// </summary>
    public class UserCollectionBookDetailsDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string? Author { get; set; }
        public int? YearPublished { get; set; }
        public string? Description { get; set; }
        public string? Notes { get; set; }
        public decimal? EstimatedPrice { get; set; }
        public decimal? PurchasePrice { get; set; }
        public DateTime? PurchaseDate { get; set; }
        public bool IsSold { get; set; }
        public decimal? SoldPrice { get; set; }
        public DateTime? SoldDate { get; set; }
        public bool IsManuallyPriced { get; set; }
        public int? ReferenceBookId { get; set; }
        public DateTime AddedDate { get; set; }
        public DateTime UpdatedDate { get; set; }
        public List<UserCollectionBookImageDto> Images { get; set; } = new List<UserCollectionBookImageDto>();
        public List<BookMatchDto> SuggestedMatches { get; set; } = new List<BookMatchDto>();
        public BookDetailDto? ReferenceBook { get; set; }
    }
}

