using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models
{
    public class YandexKassaSettings
    {
        public string ShopId { get; set; }
        public string SecretKey { get; set; }
        public string ReturnUrl { get; set; }
        public string WebhookUrl { get; set; }
    }
}
