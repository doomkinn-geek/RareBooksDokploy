using RareBooksService.Common.Models.Interfaces.Parsing;

namespace RareBooksService.Common.Models.Parsing
{
    public class Category : ICategoryInfo
    {
        public int Id { get; set; }
        public int CategoryId { get; set; }//id из meshok.net
        public string Name { get; set; }
        public List<BookInfo> Books { get; set; } = new List<BookInfo>();
    }
}
