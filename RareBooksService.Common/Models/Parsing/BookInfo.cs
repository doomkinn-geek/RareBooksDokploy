using RareBooksService.Common.Models.Interfaces.Parsing;

namespace RareBooksService.Common.Models.Parsing
{
    public class BookInfo : IBookInfo
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public DateTime BeginDate { get; set; }
        public DateTime EndDate { get; set; }
        public List<string> ImageUrls { get; set; } = new List<string>();
        public List<string> ThumbnailUrls { get; set; } = new List<string>();
        public double Price { get; set; }
        public string City { get; set; }
        public bool IsMonitored { get; set; }
        public double? FinalPrice { get; set; }
        public int? YearPublished { get; set; }
        public List<string> Tags { get; set; } = new List<string>();
        public int CategoryId { get; set; }
        public Category Category { get; set; }
    }
}
