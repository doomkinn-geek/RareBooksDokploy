using RareBooksService.Common.Models.Parsing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Interfaces
{
    //интерфейс модели книги, которая будет храниться в основной базе на PostgreeSQL
    public interface IRegularBaseBook
    {
        int Id { get; set; }
        string Title { get; set; }
        string Description { get; set; }
        DateTime BeginDate { get; set; }
        DateTime EndDate { get; set; }
        List<string> ImageUrls { get; set; }
        List<string> ThumbnailUrls { get; set; }
        double Price { get; set; }
        string City { get; set; }
        bool IsMonitored { get; set; }
        double? FinalPrice { get; set; }
        int? YearPublished { get; set; }
        List<string> Tags { get; set; }
        int CategoryId { get; set; }
        public RegularBaseCategory Category { get; set; }
        public float[] PicsRatio { get; set; }
        public int Status { get; set; }
        public int StartPrice { get; set; }
        public string Type { get; set; }
        public int SoldQuantity { get; set; }
        public int BidsCount { get; set; }
        public string SellerName { get; set; }
        public int PicsCount { get; set; }
    }
}
