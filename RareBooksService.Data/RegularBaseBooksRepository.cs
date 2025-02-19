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
        private readonly BooksDbContext _context;
        private readonly UsersDbContext _usersContext;
        private readonly Dictionary<string, IStemmer> _stemmers;

        // Создаём статический экземпляр детектора языка один раз
        private static readonly LanguageDetector _languageDetector;

        static RegularBaseBooksRepository()
        {
            _languageDetector = new LanguageDetector();
            _languageDetector.AddAllLanguages();
        }

        public RegularBaseBooksRepository(BooksDbContext context, UsersDbContext usersContext)
        {
            _context = context;
            _usersContext = usersContext;

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

        // ------------------ ПОМОГАЮЩИЙ МЕТОД: извлечение имени файла --------------
        private static string? ExtractImageName(string? fullUrl)
        {
            if (string.IsNullOrWhiteSpace(fullUrl))
                return null;

            int lastSlash = fullUrl.LastIndexOf('/');
            var fileName = (lastSlash >= 0)
                ? fullUrl.Substring(lastSlash + 1)
                : fullUrl;

            int qPos = fileName.IndexOf('?');
            if (qPos >= 0)
                fileName = fileName.Substring(0, qPos);

            return fileName;
        }

        // ------------------- ПОМОГАЮЩИЙ МЕТОД: детект языка + стемминг -----------        
        private string PreprocessText(string text, out string detectedLanguage)
        {
            // Используем статический детектор
            detectedLanguage = DetectLanguage(text);
            if (detectedLanguage == "bul" || detectedLanguage == "ukr" || detectedLanguage == "mkd")
                detectedLanguage = "rus";

            if (!_stemmers.ContainsKey(detectedLanguage))
            {
                throw new NotSupportedException($"Language {detectedLanguage} is not supported.");
            }

            var stemmer = _stemmers[detectedLanguage];
            // Приводим к нижнему регистру с помощью ToLowerInvariant для производительности и предсказуемости
            var normalizedText = Regex.Replace(text.ToLowerInvariant(), @"\p{P}", " ");
            var words = normalizedText.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                                      .Select(word => stemmer.Stem(word));
            return string.Join(" ", words);
        }

        private string DetectLanguage(string text)
        {
            return _languageDetector.Detect(text);
        }

        // -------------------- ГЛАВНЫЙ ОПТИМИЗИРОВАННЫЙ МЕТОД --------------------
        /// <summary>
        /// Общая логика постраничного вывода, 
        /// которая вызывается во всех GetBooksByXXX методах.
        /// </summary>
        private async Task<PagedResultDto<BookSearchResultDto>> BuildPagedBookResult(
            IQueryable<RegularBaseBook> baseQuery,
            int page,
            int pageSize)
        {
            // Фильтруем только проданные книги
            baseQuery = baseQuery.Where(x => x.SoldQuantity > 0);
            // Считаем общее кол-во
            var totalItems = await baseQuery.CountAsync();
            var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

            // Выбираем нужные данные
            var rawData = await baseQuery
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(b => new
                {
                    b.Id,
                    b.Title,
                    b.Price,
                    b.SellerName,
                    b.EndDate,
                    b.Type,
                    b.ImageUrls
                })
                .ToListAsync();

            // Формируем результирующие DTO
            var books = rawData.Select(b => new BookSearchResultDto
            {
                Id = b.Id,
                Title = b.Title,
                Price = b.Price,
                SellerName = b.SellerName,
                Date = b.EndDate.ToShortDateString(),
                Type = b.Type,
                FirstImageName = b.ImageUrls
                    .Select(url => ExtractImageName(url))
                    .FirstOrDefault()
            })
            .ToList();

            return new PagedResultDto<BookSearchResultDto>
            {
                Items = books,
                TotalPages = totalPages
            };
        }

        // -------------------------- REAL METHODS -----------------------------

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByTitleAsync(
            string title, int page, int pageSize, bool exactPhrase = false)
        {
            string processedTitle;
            if (exactPhrase)
            {
                processedTitle = title.ToLowerInvariant();
            }
            else
            {
                string detectedLanguage;
                processedTitle = PreprocessText(title, out detectedLanguage);
            }

            var searchWords = processedTitle.Split(' ', StringSplitOptions.RemoveEmptyEntries);

            IQueryable<RegularBaseBook> query = _context.BooksInfo.AsQueryable();

            // Формируем условие поиска: для каждого слова должно содержаться в NormalizedTitle
            foreach (var word in searchWords)
            {
                query = query.Where(b => b.NormalizedTitle.Contains(word));
            }

            // Сортируем по дате завершения
            query = query.OrderByDescending(b => b.EndDate);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByDescriptionAsync(
            string description, int page, int pageSize, bool exactPhrase = false)
        {
            string processedDesc;
            if (exactPhrase)
            {
                processedDesc = description.ToLowerInvariant();
            }
            else
            {
                string detectedLanguage;
                processedDesc = PreprocessText(description, out detectedLanguage);
            }

            var searchWords = processedDesc.Split(' ', StringSplitOptions.RemoveEmptyEntries);

            IQueryable<RegularBaseBook> query = _context.BooksInfo.AsQueryable();

            // Исправлено: теперь фильтруем по NormalizedDescription
            foreach (var word in searchWords)
            {
                query = query.Where(b => b.NormalizedDescription.Contains(word));
            }

            query = query.OrderByDescending(b => b.EndDate);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByCategoryAsync(
            int categoryId, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.CategoryId == categoryId)
                .OrderByDescending(b => b.EndDate);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByPriceRangeAsync(
            double minPrice, double maxPrice, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.Price >= minPrice && b.Price <= maxPrice)
                .OrderByDescending(b => b.Price);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksBySellerAsync(
            string sellerName, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.SellerName == sellerName)
                .OrderByDescending(b => b.EndDate);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<BookDetailDto> GetBookByIdAsync(int id)
        {
            try
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
                        IsImagesCompressed = b.IsImagesCompressed,
                        IsLessValuable = b.IsLessValuable,
                        ImageUrls = b.ImageUrls,
                        ThumbnailUrls = b.ThumbnailUrls
                    })
                    .FirstOrDefaultAsync();
            }
            catch (Exception e)
            {
                return new BookDetailDto();
            }
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

                _usersContext.UserSearchHistories.Add(searchHistory);
                await _usersContext.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                // Логирование или обработка ошибки по необходимости
            }
        }
    }
}







/*using Iveonik.Stemmers;
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
        private readonly BooksDbContext _context;
        private readonly UsersDbContext _usersContext;
        private readonly Dictionary<string, IStemmer> _stemmers;

        public RegularBaseBooksRepository(BooksDbContext context, UsersDbContext usersContext)
        {
            _context = context;
            _usersContext = usersContext;

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

        // ------------------ ПОМОГАЮЩИЙ МЕТОД: извлечение имени файла --------------
        private static string? ExtractImageName(string? fullUrl)
        {
            if (string.IsNullOrWhiteSpace(fullUrl))
                return null;

            int lastSlash = fullUrl.LastIndexOf('/');
            var fileName = (lastSlash >= 0)
                ? fullUrl.Substring(lastSlash + 1)
                : fullUrl;

            int qPos = fileName.IndexOf('?');
            if (qPos >= 0)
                fileName = fileName.Substring(0, qPos);

            return fileName;
        }

        // ------------------- ПОМОГАЮЩИЙ МЕТОД: детект языка + стемминг -----------
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
            return detector.Detect(text);
        }

        // -------------------- ГЛАВНЫЙ ОПТИМИЗИРОВАННЫЙ МЕТОД --------------------
        /// <summary>
        /// Общая логика постраничного вывода, 
        /// которая вызывается во всех GetBooksByXXX методах.
        /// </summary>
        private async Task<PagedResultDto<BookSearchResultDto>> BuildPagedBookResult(
            IQueryable<RegularBaseBook> baseQuery,
            int page,
            int pageSize)
        {
            baseQuery = baseQuery.Where(x => x.SoldQuantity > 0);
            // Считаем общее кол-во
            var totalItems = await baseQuery.CountAsync();
            var totalPages = (int)Math.Ceiling(totalItems / (double)pageSize);

            // Выбираем нужные данные
            var rawData = await baseQuery
                // дополнительно фильтруем: SoldQuantity>0 (как в вашем коде)
                .Where(b => b.SoldQuantity > 0)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(b => new
                {
                    b.Id,
                    b.Title,
                    b.Price,
                    b.SellerName,
                    b.EndDate,
                    b.Type,
                    b.ImageUrls
                })
                .ToListAsync();

            // Сформируем результирующие DTO
            var books = rawData.Select(b => new BookSearchResultDto
            {
                Id = b.Id,
                Title = b.Title,
                Price = b.Price,
                SellerName = b.SellerName,
                Date = b.EndDate.ToShortDateString(),
                Type = b.Type,
                FirstImageName = b.ImageUrls
                    .Select(url => ExtractImageName(url))
                    .FirstOrDefault()
            })
            .ToList();

            return new PagedResultDto<BookSearchResultDto>
            {
                Items = books,
                TotalPages = totalPages
            };
        }

        // -------------------------- REAL METHODS -----------------------------

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByTitleAsync(
            string title, int page, int pageSize, bool exactPhrase = false)
        {
            string processedTitle;
            if (exactPhrase)
            {
                processedTitle = title.ToLower();
            }
            else
            {
                // стемминг
                string detectedLanguage;
                processedTitle = PreprocessText(title.ToLower(), out detectedLanguage);
            }

            var searchWords = processedTitle.Split(' ', StringSplitOptions.RemoveEmptyEntries);

            var query = _context.BooksInfo.AsQueryable();

            // Применяем поиск по каждому слову
            
            foreach (var word in searchWords)
            {
                query = query.Where(b => b.NormalizedTitle.Contains(word));
            }


            // Сортируем
            query = query.OrderByDescending(b => b.EndDate);

            // Вызываем общий метод
            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByDescriptionAsync(
            string description, int page, int pageSize, bool exactPhrase = false)
        {
            string processedDesc;
            if (exactPhrase)
            {
                processedDesc = description.ToLower();
            }
            else
            {
                string detectedLanguage;
                processedDesc = PreprocessText(description.ToLower(), out detectedLanguage);
            }

            var searchWords = processedDesc.Split(' ', StringSplitOptions.RemoveEmptyEntries);

            var query = _context.BooksInfo.AsQueryable();

            // Применяем поиск по каждому слову            
            foreach (var word in searchWords)
            {
                query = query.Where(b => b.NormalizedDescription.Contains(word));
            }


            query = query.OrderByDescending(b => b.EndDate);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByCategoryAsync(
            int categoryId, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.CategoryId == categoryId)
                .OrderByDescending(b => b.EndDate);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByPriceRangeAsync(
            double minPrice, double maxPrice, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.Price >= minPrice && b.Price <= maxPrice)
                .OrderByDescending(b => b.Price);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksBySellerAsync(
            string sellerName, int page, int pageSize)
        {
            var query = _context.BooksInfo
                .Where(b => b.SellerName == sellerName)
                .OrderByDescending(b => b.EndDate);

            return await BuildPagedBookResult(query, page, pageSize);
        }

        public async Task<BookDetailDto> GetBookByIdAsync(int id)
        {
            try
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
                        IsImagesCompressed = b.IsImagesCompressed,
                        IsLessValuable = b.IsLessValuable,
                        ImageUrls = b.ImageUrls,
                        ThumbnailUrls = b.ThumbnailUrls
                    })
                    .FirstOrDefaultAsync();
            }
            catch(Exception e)
            {
                return new BookDetailDto();
            }
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

        // Сохраняем историю поиска в UsersDbContext (из параметра usersContext)
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

                _usersContext.UserSearchHistories.Add(searchHistory);
                await _usersContext.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                // Логируем или игнорируем
            }
        }
    }
}*/
