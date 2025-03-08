using RareBooksService.Common.Models.Interfaces;
using RareBooksService.Common.Models.Parsing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models
{
    public class RegularBaseBook : IRegularBaseBook
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string NormalizedTitle { get; set; }
        public string Description { get; set; }
        public string NormalizedDescription {  get; set; }
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
        public int CategoryId { get; set; }//id из табицы categories (НЕ из meshok.net )
        public RegularBaseCategory Category { get; set; }        
        public float[] PicsRatio { get; set; }
        public int Status { get; set; }
        public int StartPrice { get; set; }
        public string Type { get; set; }
        public int SoldQuantity { get; set; }
        public int BidsCount { get; set; }
        public string SellerName { get; set; }
        public int PicsCount { get; set; }

        //08.11.2024 - добавил поддержку малоценных лотов (советские до 1500) и сжатие изображений в object storage
        public bool IsImagesCompressed { get; set; }
        public string? ImageArchiveUrl { get; set; }

        //22.01.2025 - т.к. малоценных лотов очень много, храним их без загрузки изображений
        //изображения будем получать по тем ссылкам, что есть на мешке
        public bool IsLessValuable { get; set; }  

    }
}
