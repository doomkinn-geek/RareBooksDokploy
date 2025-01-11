using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class YandexCloudDto
    {
        public string? AccessKey { get; set; }
        public string? SecretKey { get; set; }
        public string? ServiceUrl { get; set; }
        public string? BucketName { get; set; }
    }
}
