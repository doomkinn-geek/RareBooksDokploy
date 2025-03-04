using System;

namespace RareBooksService.Common.Models.Dto
{
    public class RecentSaleDto
    {
        public int BookId { get; set; }
        public string Title { get; set; }
        public double FinalPrice { get; set; }
        public string ThumbnailUrl { get; set; }
        public string ImageUrl { get; set; }
        public DateTime SaleDate { get; set; }
        public string Category { get; set; }
        public string SellerName { get; set; }
    }
} 