using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models
{
    public class UserSearchHistory
    {
        public int Id { get; set; }
        public string Query { get; set; }
        public DateTime SearchDate { get; set; }
        public string SearchType { get; set; } // e.g., Title, Description, Category, etc.
        public ApplicationUser User { get; set; }
        public string UserId { get; set; }
    }
}
