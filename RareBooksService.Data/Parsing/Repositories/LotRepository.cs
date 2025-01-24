using Microsoft.EntityFrameworkCore;
using System.Net;
using RareBooksService.Common.Models.Interfaces.Parsing;

namespace RareBooksService.Data.Parsing.Repositories
{
    public class LotRepository<TContext, TBookInfo, TCategory> : ILotRepository<TBookInfo, TCategory>
        where TContext : DbContext, new()
        where TBookInfo : class, IBookInfo, new()
        where TCategory : class, ICategoryInfo, new()
    {
        public async Task SaveLotAsync(TBookInfo bookInfo, TCategory category, bool downloadImages)
        {
            using (var context = new TContext())
            {
                var booksSet = context.Set<TBookInfo>();
                var categoriesSet = context.Set<TCategory>();

                // Поиск существующей категории по ID
                //var existingCategory = await categoriesSet.FindAsync(category.CategoryId);
                var existingCategory = await categoriesSet.AsNoTracking().FirstOrDefaultAsync(c => c.CategoryId == category.CategoryId);
                if (existingCategory == null)
                {
                    // Если категория не найдена, добавляем новую
                    context.Add(category);
                    await context.SaveChangesAsync();
                    bookInfo.CategoryId = category.CategoryId;
                    ((dynamic)bookInfo).Category = category;
                }
                else
                {
                    // Если категория найдена, прикрепляем её к контексту
                    categoriesSet.Attach(existingCategory);
                    bookInfo.CategoryId = existingCategory.CategoryId; // Устанавливаем ID категории
                    ((dynamic)bookInfo).Category = existingCategory;
                }
                
                var existingBook = await booksSet.AsNoTracking().FirstOrDefaultAsync(b => b.Id == bookInfo.Id); //await booksSet.FindAsync(bookInfo.Id);

                if (existingBook == null)
                {
                    booksSet.Add(bookInfo);
                }
                else
                {
                    context.Entry(existingBook).CurrentValues.SetValues(bookInfo);
                }
                await context.SaveChangesAsync();


                if (downloadImages)
                {
                    await DownloadImagesForBookAsync(bookInfo.Id, bookInfo.ImageUrls, bookInfo.ThumbnailUrls);
                }
            }
        }


        public async Task<bool> BookExistsAsync(int bookId)
        {
            using (var context = new TContext())
            {
                return await context.Set<TBookInfo>().AnyAsync(b => ((IBookInfo)b).Id == bookId);
            }
        }

        public async Task<TCategory> GetOrCreateCategoryAsync(int categoryId, string categoryName)
        {
            using (var context = new TContext())
            {
                var categoriesSet = context.Set<TCategory>();
                var category = await categoriesSet.FirstOrDefaultAsync(c => EF.Property<int>(c, "CategoryId") == categoryId);
                return category ?? new TCategory { Name = categoryName, CategoryId = categoryId };
            }
        }
        public async Task<List<TBookInfo>> SearchBooksAsync(string searchPhrase)
        {
            using (var context = new TContext())
            {
                var booksSet = context.Set<TBookInfo>();

                return await booksSet
                    .Where(b => EF.Functions.Like(b.Title.ToLower(), $"%{searchPhrase.ToLower()}%")
                                || EF.Functions.Like(b.Description.ToLower(), $"%{searchPhrase.ToLower()}%"))
                    .ToListAsync();
            }
        }
        public async Task<List<TBookInfo>> SearchBooksSQLAsync(string searchPhrase)
        {
            using (var context = new TContext())
            {
                var query = $"SELECT * FROM BooksInfo WHERE UPPER(Title) LIKE '%{searchPhrase.ToUpper()}%' OR UPPER(Description) LIKE '%{searchPhrase.ToUpper()}%' COLLATE NOCASE";
                var books = await context.Set<TBookInfo>().FromSqlRaw(query).ToListAsync();
                return books;
            }
        }

        public async Task DownloadImagesForBookAsync(int bookId, List<string> imageUrls, List<string> thumbnailUrls)
        {
            var basePath = Path.Combine("books_photos", bookId.ToString());
            var imagesPath = Path.Combine(basePath, "images");
            var thumbnailsPath = Path.Combine(basePath, "thumbnails");

            Directory.CreateDirectory(imagesPath);
            Directory.CreateDirectory(thumbnailsPath);

            // Скачивание полноразмерных изображений
            foreach (var imageUrl in imageUrls)
            {
                try
                {
                    //Console.WriteLine($"Attempting to download image from: {imageUrl}");
                    var filename = Path.GetFileName(new Uri(imageUrl).AbsolutePath);
                    var filePath = Path.Combine(imagesPath, filename);
                    if (!File.Exists(filePath))
                        await DownloadFileAsync(imageUrl, filePath);
                }
                catch (Exception e)
                {
                    Console.WriteLine($"Error while downloading an image file from {imageUrl}: {e}");
                }
            }

            // Скачивание миниатюр
            foreach (var thumbnailUrl in thumbnailUrls)
            {
                try
                {
                    //Console.WriteLine($"Attempting to download thumbnail from: {thumbnailUrl}");
                    var filename = Path.GetFileName(new Uri(thumbnailUrl).AbsolutePath);
                    var filePath = Path.Combine(thumbnailsPath, filename);
                    if (!File.Exists(filePath))
                        await DownloadFileAsync(thumbnailUrl, filePath);
                }
                catch (Exception e)
                {
                    Console.WriteLine($"Error while downloading a thumbnail file from {thumbnailUrl}: {e}");
                }
            }
        }


        private static async Task DownloadFileAsync(string url, string outputPath)
        {
            try
            {
                using (var webClient = new WebClient())
                {
                    webClient.Headers.Add("User-Agent: Other"); // Добавить заголовок User-Agent, если требуется
                    await webClient.DownloadFileTaskAsync(new Uri(url), outputPath);
                }
            }
            catch (Exception ex)
            {
                //Console.WriteLine($"Failed to download file from {url}. Exception: {ex}");
                throw;
            }
        }
        private static async Task<bool> IsUrlAccessibleAsync(string url)
        {
            try
            {
                using (var httpClient = new HttpClient())
                {
                    var response = await httpClient.GetAsync(url);
                    return response.IsSuccessStatusCode;
                }
            }
            catch
            {
                return false;
            }
        }
    }
}
