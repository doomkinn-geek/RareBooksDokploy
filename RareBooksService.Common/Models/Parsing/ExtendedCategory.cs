using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using RareBooksService.Common.Models.Interfaces.Parsing;

namespace RareBooksService.Common.Models.Parsing
{
    public class ExtendedCategory : ICategoryInfo
    {
        public int Id { get; set; }
        public int CategoryId { get; set; }//id из meshok.net
        public string Name { get; set; }
        public List<ExtendedBookInfo> Books { get; set; } = new List<ExtendedBookInfo>();
    }
}
