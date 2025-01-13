using Iveonik.Stemmers;
using LanguageDetection;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;
using System.Text.RegularExpressions;

namespace RareBooksService.Data
{
    public class RegularBaseBooksRepository : IRegularBaseBooksRepository
    {
        private readonly RegularBaseBooksContext _context;
        private readonly Dictionary<string, IStemmer> _stemmers;

        public RegularBaseBooksRepository(RegularBaseBooksContext context)
        {
            _context = context;

            _stemmers = new Dictionary<string, IStemmer>
            {
                { "rus", new RussianStemmer() },
                { "eng", new EnglishStemmer() },
                { "fra", new FrenchStemmer() },
                { "deu", new GermanStemmer() },
                { "ita", new ItalianStemmer() },
                { "fin", new FinnishStemmer() }
            };
        }

        // ------------------ НОВЫЙ ПОМОГАЮЩИЙ МЕТОД ------------------
        private static string? ExtractImageName(string? fullUrl)
        {
            if (string.IsNullOrWhiteSpace(fullUrl))
                return null;

            // Отсекаем всё до последнего слэша
            int lastSlash = fullUrl.LastIndexOf('/');
            var fileName = (lastSlash >= 0)
                ? fullUrl.Substring(lastSlash + 1)
                : fullUrl;

            // Убираем query‑параметры, если есть '?'
            int qPos = fileName.IndexOf('?');
            if (qPos >= 0)
                fileName = fileName.Substring(0, qPos);

            return fileName;
        }
        // ----------------------------------------------------------

        private string PreprocessText(string text, out string detectedLanguage)
        {
            detectedLanguage = DetectLanguage(text);
            if (detectedLanguage == "bul" || detectedLanguage == "ukr" || detectedLanguage == "mkd")
                detectedLanguage = "rus";

            if (!_stemmers.ContainsKey(detectedLanguage))
            {
                throw new NotSupportedException($"Language {detectedLanguage} is not supported.");
            }

            var stemmer = _stemmers[detectedLanguage];
            var normalizedText = Regex.Replace(text.ToLower(), @"\p{P}", " ");
            var words = normalizedText.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                                      .Select(word => stemmer.Stem(word));
            return string.Join(" ", words);
        }

        private string DetectLanguage(string text)
        {
            LanguageDetector detector = new LanguageDetector();
            detector.AddAllLanguages();
            string res = detector.Detect(text);
            return res;
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByTitleAsync(string title, int page, int pageSize, bool exactPhrase = false)
        {
            string detectedLanguage;
            string processedTitle;
            if (!exactPhrase)
                processedTitle = PreprocessText(title.ToLower(), out detectedLanguage);
            else
                processedTitle = title.ToLower();

            var searchWords = processedTitle.Split(' ', StringSplitOptions.RemoveEmptyEntries);

            var query = _context.BooksInfo.AsQueryable();

            foreach (var word in searchWords)
            {
                query = query.Where(b => EF.Functions.Like(b.NormalizedTitle, $"%{word}%"));
            }

            query = query.OrderBy(b => b.EndDate);

            var totalItems = await query.CountAsync();
            var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

            var books = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(b => new BookSearchResultDto
                {
                    Id = b.Id,
                    Title = b.Title,
                    Price = b.Price,
                    SellerName = b.SellerName,
                    Date = b.EndDate.ToShortDateString(),
                    Type = b.Type,
                    FirstThumbnailName = b.ThumbnailUrls
                        .Select(url => ExtractImageName(url))
                        .FirstOrDefault()
                })
                .ToListAsync();

            return new PagedResultDto<BookSearchResultDto> { Items = books, TotalPages = totalPages };
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByDescriptionAsync(string description, int page, int pageSize, bool exactPhrase = false)
        {
            string detectedLanguage;
            string processedDescription;
            if (!exactPhrase)
                processedDescription = PreprocessText(description.ToLower(), out detectedLanguage);
            else
                processedDescription = description.ToLower();

            var searchWords = processedDescription.Split(' ', StringSplitOptions.RemoveEmptyEntries);

            var query = _context.BooksInfo.AsQueryable();

            foreach (var word in searchWords)
            {
                query = query.Where(b => EF.Functions.Like(b.NormalizedDescription, $"%{word}%"));
            }

            query = query.OrderBy(b => b.EndDate);

            var totalItems = await query.CountAsync();
            var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

            var books = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(b => new BookSearchResultDto
                {
                    Id = b.Id,
                    Title = b.Title,
                    Price = b.Price,
                    SellerName = b.SellerName,
                    Date = b.EndDate.ToShortDateString(),
                    Type = b.Type,
                    FirstThumbnailName = b.ThumbnailUrls
                        .Select(url => ExtractImageName(url))
                        .FirstOrDefault()
                })
                .ToListAsync();

            return new PagedResultDto<BookSearchResultDto> { Items = books, TotalPages = totalPages };
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByCategoryAsync(int categoryId, int page, int pageSize)
        {
            var query = _context.BooksInfo.Where(b => b.CategoryId == categoryId)
                                          .OrderBy(b => b.EndDate);

            var totalItems = await query.CountAsync();
            var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

            var books = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(b => new BookSearchResultDto
                {
                    Id = b.Id,
                    Title = b.Title,
                    Price = b.Price,
                    SellerName = b.SellerName,
                    Date = b.EndDate.ToShortDateString(),
                    Type = b.Type,
                    FirstThumbnailName = b.ThumbnailUrls
                        .Select(url => ExtractImageName(url))
                        .FirstOrDefault()
                })
                .ToListAsync();

            return new PagedResultDto<BookSearchResultDto> { Items = books, TotalPages = totalPages };
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByPriceRangeAsync(double minPrice, double maxPrice, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.Price >= minPrice && b.Price <= maxPrice)
                .OrderBy(b => b.Price);

            var totalItems = await query.CountAsync();
            var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

            var books = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(b => new BookSearchResultDto
                {
                    Id = b.Id,
                    Title = b.Title,
                    Price = b.Price,
                    SellerName = b.SellerName,
                    Date = b.EndDate.ToShortDateString(),
                    Type = b.Type,
                    FirstThumbnailName = b.ThumbnailUrls
                        .Select(url => ExtractImageName(url))
                        .FirstOrDefault()
                })
                .ToListAsync();

            return new PagedResultDto<BookSearchResultDto> { Items = books, TotalPages = totalPages };
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksBySellerAsync(string sellerName, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.SellerName == sellerName)
                .OrderBy(b => b.EndDate);

            var totalItems = await query.CountAsync();
            var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

            var books = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(b => new BookSearchResultDto
                {
                    Id = b.Id,
                    Title = b.Title,
                    Price = b.Price,
                    SellerName = b.SellerName,
                    Date = b.EndDate.ToShortDateString(),
                    Type = b.Type,
                    FirstThumbnailName = b.ThumbnailUrls
                        .Select(url => ExtractImageName(url))
                        .FirstOrDefault()
                })
                .ToListAsync();

            return new PagedResultDto<BookSearchResultDto> { Items = books, TotalPages = totalPages };
        }

        public async Task<BookDetailDto> GetBookByIdAsync(int id)
        {
            return await _context.BooksInfo
                .Where(b => b.Id == id)
                .Select(b => new BookDetailDto
                {
                    Id = b.Id,
                    Title = b.Title,
                    Description = b.Description,
                    BeginDate = b.BeginDate,
                    EndDate = b.EndDate.ToShortDateString(),
                    Price = b.Price,
                    City = b.City,
                    FinalPrice = b.FinalPrice,
                    YearPublished = b.YearPublished,
                    Tags = b.Tags,
                    CategoryName = b.Category.Name,
                    Status = b.Status,
                    Type = b.Type,
                    SellerName = b.SellerName,
                    ImageArchiveUrl = b.ImageArchiveUrl,
                    IsImagesCompressed = b.IsImagesCompressed
                })
                .FirstOrDefaultAsync();
        }

        public async Task<List<CategoryDto>> GetCategoriesAsync()
        {
            return await _context.Categories
                .Select(c => new CategoryDto
                {
                    Id = c.Id,
                    Name = c.Name
                })
                .ToListAsync();
        }

        public async Task<CategoryDto> GetCategoryByIdAsync(int id)
        {
            return await _context.Categories
                .Where(b => b.Id == id)
                .Select(c => new CategoryDto
                {
                    Id = c.Id,
                    Name = c.Name
                })
                .FirstOrDefaultAsync();
        }

        public async Task SaveSearchHistoryAsync(string userId, string query, string searchType)
        {
            try
            {
                var searchHistory = new UserSearchHistory
                {
                    UserId = userId,
                    Query = query,
                    SearchDate = DateTime.UtcNow,
                    SearchType = searchType
                };

                _context.UserSearchHistories.Add(searchHistory);
                await _context.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                // Логируем, игнорируем или пробрасываем выше по необходимости
            }
        }
    }
}
