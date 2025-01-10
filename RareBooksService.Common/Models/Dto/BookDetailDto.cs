using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class BookDetailDto
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public DateTime BeginDate { get; set; }
        public string EndDate { get; set; }        
        public double Price { get; set; }
        public string City { get; set; }
        public double? FinalPrice { get; set; }
        public int? YearPublished { get; set; }
        public List<string> Tags { get; set; } = new List<string>();
        public string CategoryName { get; set; }
        public int Status { get; set; }
        public string Type { get; set; }
        public string SellerName { get; set; }

        //08.11.2024 - добавил поддержку малоценных лотов (советские до 1500) и сжатие изображений в object storage
        public bool IsImagesCompressed { get; set; } // Новое поле
        public string? ImageArchiveUrl { get; set; }  // Новое поле
    }
}
