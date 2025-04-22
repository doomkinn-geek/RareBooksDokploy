using Iveonik.Stemmers;
using LanguageDetection;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Logging;

namespace RareBooksService.Data
{
    public class RegularBaseBooksRepository : IRegularBaseBooksRepository
    {
        private readonly BooksDbContext _context;
        private readonly UsersDbContext _usersContext;
        private readonly Dictionary<string, IStemmer> _stemmers;
        private readonly ILogger<RegularBaseBooksRepository> _logger;

        // Создаём статический экземпляр детектора языка один раз
        private static readonly LanguageDetector _languageDetector;

        static RegularBaseBooksRepository()
        {
            _languageDetector = new LanguageDetector();
            _languageDetector.AddAllLanguages();
        }

        public RegularBaseBooksRepository(BooksDbContext context, UsersDbContext usersContext, ILogger<RegularBaseBooksRepository> logger)
        {
            _context = context;
            _usersContext = usersContext;
            _logger = logger;

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

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByTitleAsync(
            string title, int page, int pageSize, bool exactPhrase, List<int> categoryIds)
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

            // Фильтруем по выбранным категориям, если они указаны
            if (categoryIds != null && categoryIds.Count > 0)
            {
                query = query.Where(b => categoryIds.Contains(b.CategoryId));
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

        public async Task<PagedResultDto<BookSearchResultDto>> GetBooksByDescriptionAsync(
            string description, int page, int pageSize, bool exactPhrase, List<int> categoryIds)
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

            // Фильтруем по выбранным категориям, если они указаны
            if (categoryIds != null && categoryIds.Count > 0)
            {
                query = query.Where(b => categoryIds.Contains(b.CategoryId));
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

        /// <summary>
        /// Возвращает только общее количество и первые два названия книг
        /// в заданном диапазоне цен (учитывая SoldQuantity>0).
        /// </summary>
        public async Task<(int totalFound, List<string> firstTwoTitles)> GetPartialInfoByPriceRangeAsync(
            double minPrice, double maxPrice)
        {
            var baseQuery = _context.BooksInfo
                .Where(b => b.SoldQuantity > 0)
                .Where(b => b.Price >= minPrice && b.Price <= maxPrice);

            int totalFound = await baseQuery.CountAsync();

            // Берём первые две книги (например, по цене убыванию)
            var twoTitles = await baseQuery
                .OrderByDescending(b => b.Price)
                .Take(2)
                .Select(b => b.Title)
                .ToListAsync();

            return (totalFound, twoTitles);
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
            try
            {
                _logger.LogInformation("Начало выполнения метода GetCategoriesAsync");
                
                // Проверяем доступность контекста БД
                if (_context == null)
                {
                    _logger.LogError("Контекст БД (_context) не инициализирован");
                    throw new InvalidOperationException("Контекст БД не инициализирован");
                }
                
                _logger.LogInformation("Проверяем доступность DbSet Categories");
                if (_context.Categories == null)
                {
                    _logger.LogError("DbSet Categories не инициализирован");
                    throw new InvalidOperationException("DbSet Categories не инициализирован");
                }
                
                _logger.LogDebug("Формируем запрос для получения категорий");
                var query = _context.Categories
                    .Select(c => new CategoryDto
                    {
                        Id = c.Id,
                        Name = c.Name,
                        BookCount = c.Books.Count(b => b.SoldQuantity > 0)
                    })
                    .Where(c => c.BookCount > 0);
                
                _logger.LogDebug("Выполняем запрос к БД для получения категорий");
                
                try
                {
                    var categoriesWithBooks = await query.ToListAsync();
                    _logger.LogInformation("Запрос категорий выполнен успешно. Получено {count} записей", categoriesWithBooks.Count);
                    return categoriesWithBooks;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Ошибка при выполнении запроса к БД: {Message}", ex.Message);
                    
                    // Пытаемся получить SQL-запрос для отладки
                    try
                    {
                        var queryString = query.ToQueryString();
                        _logger.LogError("SQL запрос: {sql}", queryString);
                    }
                    catch (Exception sqlEx)
                    {
                        _logger.LogError(sqlEx, "Не удалось получить SQL запрос: {Message}", sqlEx.Message);
                    }
                    
                    throw;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Критическая ошибка в методе GetCategoriesAsync: {Message}", ex.Message);
                
                if (ex.InnerException != null)
                {
                    _logger.LogError("Inner Exception: {InnerMessage}", ex.InnerException.Message);
                    _logger.LogError("Inner Stack Trace: {InnerStackTrace}", ex.InnerException.StackTrace);
                }
                
                // Проверяем состояние подключения к БД
                try
                {
                    _logger.LogWarning("Проверка состояния подключения к БД");
                    var canConnect = _context.Database.CanConnect();
                    _logger.LogInformation("Подключение к БД доступно: {canConnect}", canConnect);
                    
                    if (!canConnect)
                    {
                        _logger.LogError("Не удалось подключиться к БД. Строка подключения: {connectionString}", 
                            _context.Database.GetConnectionString()?.Replace("Password=", "Password=***"));
                    }
                }
                catch (Exception dbEx)
                {
                    _logger.LogError(dbEx, "Ошибка при проверке подключения к БД: {Message}", dbEx.Message);
                }
                
                throw;
            }
        }

        public async Task<CategoryDto> GetCategoryByIdAsync(int id)
        {
            return await _context.Categories
                .Where(b => b.Id == id)
                .Select(c => new CategoryDto
                {
                    Id = c.Id,
                    Name = c.Name,
                    BookCount = c.Books.Count(b => b.SoldQuantity > 0)
                })
                .FirstOrDefaultAsync();
        }

        public async Task SaveSearchHistoryAsync(string userId, string query, string searchType)
        {
            try
            {
                // Проверяем, существует ли уже такая запись в истории поиска
                var existingRecord = await _usersContext.UserSearchHistories
                    .FirstOrDefaultAsync(h => h.UserId == userId && 
                                             h.Query == query && 
                                             h.SearchType == searchType);
                
                if (existingRecord != null)
                {
                    // Если запись существует, обновляем дату поиска на текущую
                    existingRecord.SearchDate = DateTime.UtcNow;
                    _usersContext.UserSearchHistories.Update(existingRecord);
                    await _usersContext.SaveChangesAsync();
                }
                else
                {
                    // Если записи нет, создаем новую
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
            }
            catch (Exception ex)
            {
                // Логирование или обработка ошибки по необходимости
            }
        }

        /// <summary>
        /// Возвращает IQueryable с книгами для построения сложных запросов
        /// </summary>
        public IQueryable<RegularBaseBook> GetQueryable()
        {
            return _context.BooksInfo.Include(b => b.Category);
        }

        /// <summary>
        /// Возвращает сущность книги по идентификатору
        /// </summary>
        public async Task<RegularBaseBook> GetBookEntityByIdAsync(int id)
        {
            return await _context.BooksInfo
                .Include(b => b.Category)
                .FirstOrDefaultAsync(b => b.Id == id);
        }

        /// <summary>
        /// Возвращает сущность категории по идентификатору
        /// </summary>
        public async Task<RegularBaseCategory> GetCategoryEntityByIdAsync(int id)
        {
            return await _context.Categories.FindAsync(id);
        }
    }
}