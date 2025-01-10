using RareBooksService.Common.Models.Interfaces.Parsing;

namespace RareBooksService.Data.Parsing.Repositories
{
    public interface ILotRepository<TBookInfo, TCategory>
        where TBookInfo : class, IBookInfo, new()
        where TCategory : class, ICategoryInfo, new()
    {
        Task SaveLotAsync(TBookInfo bookInfo, TCategory category, bool downloadImages);
        Task<bool> BookExistsAsync(int bookId);
        Task<TCategory> GetOrCreateCategoryAsync(int categoryId, string categoryName);
        Task<List<TBookInfo>> SearchBooksAsync(string searchPhrase);
        Task<List<TBookInfo>> SearchBooksSQLAsync(string searchPhrase);
        Task DownloadImagesForBookAsync(int bookId, List<string> imageUrls, List<string> thumbnailUrls);
    }
}
