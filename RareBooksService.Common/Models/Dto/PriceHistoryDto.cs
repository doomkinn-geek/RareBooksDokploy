using System;
using System.Collections.Generic;

namespace RareBooksService.Common.Models.Dto
{
    public class PriceHistoryDto
    {
        public int BookId { get; set; }
        public string Title { get; set; }
        public List<PricePoint> PricePoints { get; set; } = new List<PricePoint>();
        public double AveragePrice { get; set; }
        public double PriceChange { get; set; }
        public double PriceChangePercentage { get; set; }
        public List<string> KeywordsUsed { get; set; } = new List<string>();
    }

    public class PricePoint
    {
        public string Date { get; set; }
        public double Price { get; set; }
        public string Source { get; set; }
        public int? BookId { get; set; }
        public string Title { get; set; }
        public string FirstImageName { get; set; }
    }
} 