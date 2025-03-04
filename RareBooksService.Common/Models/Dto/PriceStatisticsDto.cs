using System;
using System.Collections.Generic;

namespace RareBooksService.Common.Models.Dto
{
    public class PriceStatisticsDto
    {
        public double AveragePrice { get; set; }
        public double MedianPrice { get; set; }
        public double MaxPrice { get; set; }
        public double MinPrice { get; set; }
        public int TotalBooks { get; set; }
        public int TotalSales { get; set; }
        public Dictionary<string, int> PriceRanges { get; set; } = new Dictionary<string, int>();
        public Dictionary<string, double> CategoryAveragePrices { get; set; } = new Dictionary<string, double>();
        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;
    }
} 