using RareBooksService.Common.Models.Interfaces;
using RareBooksService.Common.Models.Parsing;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models
{
    public class RegularBaseCategory : IRegularBaseCategory
    {
        public int Id { get; set; }
        public int CategoryId { get; set; }//id из meshok.net
        public string Name { get; set; }
        public List<RegularBaseBook> Books { get; set; } = new List<RegularBaseBook>();
    }
}
