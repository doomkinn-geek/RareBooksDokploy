using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class PagedResultDto<T>
    {
        public List<T> Items { get; set; }
        public int TotalPages { get; set; }
    }
}
