using Microsoft.AspNetCore.Identity;
using System.Collections.Generic;

namespace RareBooksService.Common.Models
{
    public class ApplicationUser : IdentityUser
    {
        // Оставляем, если хотите
        public bool HasSubscription { get; set; }

        public List<UserSearchHistory> SearchHistory { get; set; } = new List<UserSearchHistory>();

        public string Role { get; set; } = "User"; // Default role

        // Можно добавить ссылку на текущую активную подписку (опционально)
        public int? CurrentSubscriptionId { get; set; }
        public Subscription CurrentSubscription { get; set; }
    }
}
