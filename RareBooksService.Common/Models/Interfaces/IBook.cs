﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using RareBooksService.Common.Models.Interfaces.Parsing;

namespace RareBooksService.Common.Models.Interfaces
{
    public interface IBook
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
        ICategory Category { get; set; }
    }
}
