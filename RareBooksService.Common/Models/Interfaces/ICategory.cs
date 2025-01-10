using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Interfaces
{
    public interface ICategory
    {
        int Id { get; set; }
        int CategoryId { get; set; } // ID из meshok.net
        string Name { get; set; }
        List<IBook> Books { get; set; }
    }
}