using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class UserSearchHistoryDto
    {
        public int Id { get; set; }
        public string Query { get; set; }
        public DateTime SearchDate { get; set; }
        public string SearchType { get; set; }
    }

}
