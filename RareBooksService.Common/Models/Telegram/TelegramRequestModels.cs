using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Telegram
{
    public class SetupWebhookRequest
    {
        public string BaseUrl { get; set; } = string.Empty;
    }

    public class TestSendRequest
    {
        public string ChatId { get; set; } = string.Empty;
        public string? Message { get; set; }
    }
}

