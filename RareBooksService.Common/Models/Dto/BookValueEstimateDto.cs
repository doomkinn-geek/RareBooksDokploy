using System.Collections.Generic;

namespace RareBooksService.Common.Models.Dto
{
    public class BookValueEstimateDto
    {
        public double EstimatedValue { get; set; }
        public double MinimumValue { get; set; }
        public double MaximumValue { get; set; }
        public double Confidence { get; set; } // от 0 до 1
        public List<string> Factors { get; set; } = new List<string>();
        public Dictionary<string, double> FactorWeights { get; set; } = new Dictionary<string, double>();
        public List<SimilarBookReference> SimilarBooks { get; set; } = new List<SimilarBookReference>();
    }

    public class SimilarBookReference
    {
        public int BookId { get; set; }
        public string Title { get; set; }
        public double SalePrice { get; set; }
        public double Similarity { get; set; } // от 0 до 1
    }

    public class BookValueEstimateRequest
    {
        public string Title { get; set; }
        public string Author { get; set; }
        public int? YearPublished { get; set; }
        public string Publisher { get; set; }
        public string Condition { get; set; } // например: "mint", "good", "poor"
        public bool IsFirstEdition { get; set; }
        public bool IsSigned { get; set; }
        public int? CategoryId { get; set; }
        public List<string> Features { get; set; } = new List<string>();
    }
} 