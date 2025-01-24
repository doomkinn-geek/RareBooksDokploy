using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using RareBooksService.Common.Models.Interfaces.Parsing;

namespace RareBooksService.Common.Models.Parsing
{
    //этот класс - расширение первой модели, которая была расширена от IBookInfo для парсинга данных, 
    //Его необходимо сохранить для парсинга данных с сайта
    //а для работы с книгой внутри уже регулярной базы, в которую будет доступ извне
    //нужна другая модель с другим интерфейсом
    public class ExtendedBookInfo : IBookInfo
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
        public ExtendedCategory Category { get; set; }

        // Дополнительные свойства специфичные для ExtendedBookInfo
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
