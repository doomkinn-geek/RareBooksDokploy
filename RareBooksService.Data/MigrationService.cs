using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.FromMeshok;
using RareBooksService.Common.Models.Parsing;
using RareBooksService.Data.Parsing;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace RareBooksService.Data
{
    public class MigrationService
    {
        private readonly DbContextOptions<BooksDbContext> _options;

        public MigrationService()
        {
            var optionsBuilder = new DbContextOptionsBuilder<BooksDbContext>();
            optionsBuilder.UseNpgsql("Host=localhost;Database=RareBooks;Username=postgres;Password=123456");
            _options = optionsBuilder.Options;
        }
        public MigrationService(DbContextOptions<BooksDbContext> options)
        {
            _options = options;
        }

        public async Task MigrateDataAsync()
        {
            try
            {
                using (var sourceContext = new ExtendedBooksContext())
                using (var targetContext = new BooksDbContext(_options))
                {
                    targetContext.Database.Migrate();

                    var allCats = targetContext.Categories.ToList();
                    targetContext.Categories.RemoveRange(allCats);

                    // Перенос категорий
                    var categories = await sourceContext.Categories.ToListAsync();
                    foreach (var category in categories)
                    {
                        if (!targetContext.Categories.Any(c => c.CategoryId == category.CategoryId))
                        {
                            Console.WriteLine($"Добавлена категория {category.Name}");
                            targetContext.Categories.Add(new RegularBaseCategory
                            {
                                CategoryId = category.CategoryId,
                                Name = category.Name
                            });
                        }
                    }

                    await targetContext.SaveChangesAsync();

                    // Перенос книг
                    var books = await sourceContext.BooksInfo.Include(b => b.Category).ToListAsync();
                    foreach (var book in books)
                    {
                        if (!targetContext.BooksInfo.Any(b => b.Id == book.Id))
                        {
                            Console.WriteLine($"Добавлена книга {book.Title}");
                            targetContext.BooksInfo.Add(new RegularBaseBook
                            {
                                Id = book.Id,
                                Title = book.Title,
                                NormalizedTitle = book.Title.ToLower(),
                                Description = book.Description,
                                NormalizedDescription = book.Description.ToLower(),
                                BeginDate = DateTime.SpecifyKind(book.BeginDate, DateTimeKind.Utc),
                                EndDate = DateTime.SpecifyKind(book.EndDate, DateTimeKind.Utc),
                                ImageUrls = book.ImageUrls,
                                ThumbnailUrls = book.ThumbnailUrls,
                                Price = book.Price,
                                City = book.City,
                                IsMonitored = book.IsMonitored,
                                FinalPrice = book.FinalPrice,
                                YearPublished = book.YearPublished,
                                CategoryId = book.CategoryId,
                                Tags = book.Tags,
                                PicsRatio = book.PicsRatio,
                                Status = book.Status,
                                StartPrice = book.StartPrice,
                                Type = book.Type,
                                SoldQuantity = book.SoldQuantity,
                                BidsCount = book.BidsCount,
                                SellerName = book.SellerName,
                                PicsCount = book.PicsCount
                            });
                        }
                    }

                    await targetContext.SaveChangesAsync();
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ОШИБКА миграции: {ex.ToString()}");
            }
        }
    }
}
