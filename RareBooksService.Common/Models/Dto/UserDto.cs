using RareBooksService.Common.Models.Dto.RareBooksService.Common.Models.Dto;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class UserDto
    {
        public string Id { get; set; }
        public string Email { get; set; }
        public string Role { get; set; }
        public bool HasSubscription { get; set; }
        public DateTime? CreatedAt { get; set; }
        public SubscriptionDto? CurrentSubscription { get; set; }
    }
}
