using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models
{
    public class ApplicationUser : IdentityUser
    {
        public bool HasSubscription { get; set; }
        public List<UserSearchHistory> SearchHistory { get; set; } = new List<UserSearchHistory>();
        public string Role { get; set; } = "User"; // Default role
    }
}
