using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using RareBooksService.Data.Interfaces;
using RareBooksService.Parser.Services;
using RareBooksService.WebApi.Helpers;
using Microsoft.AspNetCore.Mvc; // для FileResult
using System.Text.RegularExpressions;
using System.Text;
using System;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public interface IBooksService
    {
        Task<(bool hasSubscription, int? remainingRequests)> CheckIfNewSearchAndConsumeLimit(
            ApplicationUser user, string searchType, string queryText);

        void ApplyNoSubscriptionRulesToSearchResults(List<BookSearchResultDto> books);

        Task<PagedResultDto<BookSearchResultDto>> SearchByTitleAsync(
            ApplicationUser user, string title, bool exactPhrase, int page, int pageSize);

        Task<PagedResultDto<BookSearchResultDto>> SearchByDescriptionAsync(
            ApplicationUser user, string description, bool exactPhrase, int page, int pageSize);

        Task<PagedResultDto<BookSearchResultDto>> SearchByCategoryAsync(
            ApplicationUser user, int categoryId, int page, int pageSize);

        Task<PagedResultDto<BookSearchResultDto>> SearchBySellerAsync(
            ApplicationUser user, string sellerName, int page, int pageSize);

        Task<object> SearchByPriceRangeAsync(
            ApplicationUser user, double minPrice, double maxPrice, int page, int pageSize);

        Task<BookDetailDto> GetBookByIdAsync(ApplicationUser user, int id);

        Task<(List<string> images, List<string> thumbnails)> GetBookImagesAsync(
            ApplicationUser user, int id);

        Task<ActionResult> GetImageAsync(
            ApplicationUser user, int id, string imageName);

        Task<ActionResult> GetThumbnailAsync(
            ApplicationUser user, int id, string thumbnailName);

        Task<PriceStatisticsDto> GetPriceStatisticsAsync(
            ApplicationUser user, int? categoryId = null);

        Task<List<RecentSaleDto>> GetRecentSalesAsync(
            ApplicationUser user, int limit = 5);

        Task<PriceHistoryDto> GetPriceHistoryAsync(
            ApplicationUser user, int id);

        Task<BookValueEstimateDto> EstimateBookValueAsync(
            ApplicationUser user, BookValueEstimateRequest request);

        Task<bool> AddBookToFavoritesAsync(string userId, int bookId);
        Task<bool> RemoveBookFromFavoritesAsync(string userId, int bookId);
        Task<bool> IsBookInFavoritesAsync(string userId, int bookId);
        Task<PagedResultDto<BookDetailDto>> GetFavoriteBooksAsync(string userId, int page, int pageSize);
        Task<BookDetailDto> GetBookByIdAsync(int id);
    }

    public class BooksService : IBooksService
    {
        private readonly IRegularBaseBooksRepository _booksRepository;
        private readonly ISearchHistoryService _searchHistoryService;
        private readonly IBookImagesService _bookImagesService;
        private readonly ILogger<BooksService> _logger;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _env;
        private readonly ISubscriptionService _subscriptionService;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly UsersDbContext _usersDbContext;
        private readonly IUserService _userService;

        public BooksService(
            IRegularBaseBooksRepository booksRepository,
            ISearchHistoryService searchHistoryService,
            IBookImagesService bookImagesService,
            ILogger<BooksService> logger,
            IConfiguration configuration,
            IWebHostEnvironment env,
            ISubscriptionService subscriptionService,
            UserManager<ApplicationUser> userManager,
            UsersDbContext usersDbContext,
            IUserService userService)
        {
            _booksRepository = booksRepository;
            _searchHistoryService = searchHistoryService;
            _bookImagesService = bookImagesService;
            _logger = logger;
            _configuration = configuration;
            _env = env;
            _subscriptionService = subscriptionService;
            _userManager = userManager;
            _usersDbContext = usersDbContext;
            _userService = userService;
        }

        public async Task<(bool hasSubscription, int? remainingRequests)>
            CheckIfNewSearchAndConsumeLimit(ApplicationUser user, string searchType, string queryText)
        {
            // Вся логика, ранее была в BooksController.CheckIfNewSearchAndConsumeLimit
            // ---
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (subDto == null || !subDto.IsActive)
            {
                return (false, 0);
            }

            var plan = subDto.SubscriptionPlan;
            if (plan == null)
            {
                return (false, 0);
            }

            if (plan.MonthlyRequestLimit <= 0)
            {
                return (true, null);
            }

            if (subDto.UsedRequestsThisPeriod >= plan.MonthlyRequestLimit)
            {
                subDto.IsActive = false;
                var userEntity = await _usersDbContext.Users.FindAsync(user.Id);
                if (userEntity != null)
                {
                    userEntity.HasSubscription = false;
                }

                await _subscriptionService.UpdateSubscriptionAsync(subDto);
                return (false, 0);
            }

            var state = await _usersDbContext.UserSearchStates
                .FirstOrDefaultAsync(s => s.UserId == user.Id && s.SearchType == searchType);

            bool isNewSearch = false;
            if (state == null)
            {
                isNewSearch = true;
                var newState = new UserSearchState
                {
                    UserId = user.Id,
                    SearchType = searchType,
                    LastQuery = queryText,
                    UpdatedAt = DateTime.UtcNow
                };
                _usersDbContext.UserSearchStates.Add(newState);
            }
            else
            {
                if (state.LastQuery != queryText)
                {
                    isNewSearch = true;
                    state.LastQuery = queryText;
                    state.UpdatedAt = DateTime.UtcNow;
                    _usersDbContext.UserSearchStates.Update(state);
                }
            }

            if (isNewSearch)
            {
                subDto.UsedRequestsThisPeriod++;
                await _subscriptionService.UpdateSubscriptionAsync(subDto);
            }

            await _usersDbContext.SaveChangesAsync();

            var used = subDto.UsedRequestsThisPeriod;
            var limit = plan.MonthlyRequestLimit;
            var remain = limit - used;
            if (remain < 0) remain = 0;

            if (remain == 0)
            {
                subDto.IsActive = false;
                var userEntity = await _usersDbContext.Users.FindAsync(user.Id);
                if (userEntity != null)
                {
                    userEntity.HasSubscription = false;
                }

                await _subscriptionService.UpdateSubscriptionAsync(subDto);
            }

            if (!subDto.IsActive)
            {
                return (false, 0);
            }

            return (true, remain);
        }

        public void ApplyNoSubscriptionRulesToSearchResults(List<BookSearchResultDto> books)
        {
            // Вся логика, ранее была в BooksController.ApplyNoSubscriptionRulesToSearchResults
            foreach (var b in books)
            {
                b.Price = 0;
                b.Date = "Только для подписчиков";
                b.FirstImageName = "";
            }
        }

        public async Task<PagedResultDto<BookSearchResultDto>> SearchByTitleAsync(
            ApplicationUser user, string title, bool exactPhrase, int page, int pageSize)
        {
            _logger.LogInformation("Поиск по названию: {Title}, page={Page}", title, page);

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Title", title);
            var books = await _booksRepository.GetBooksByTitleAsync(title, page, pageSize, exactPhrase);

            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            await _searchHistoryService.SaveSearchHistory(user.Id, title, "Title");

            return new PagedResultDto<BookSearchResultDto>
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain
            };
        }

        public async Task<PagedResultDto<BookSearchResultDto>> SearchByDescriptionAsync(
            ApplicationUser user, string description, bool exactPhrase, int page, int pageSize)
        {
            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Description", description);
            var books = await _booksRepository.GetBooksByDescriptionAsync(description, page, pageSize, exactPhrase);

            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            await _searchHistoryService.SaveSearchHistory(user.Id, description, "Description");

            return new PagedResultDto<BookSearchResultDto>
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain
            };
        }

        public async Task<PagedResultDto<BookSearchResultDto>> SearchByCategoryAsync(
            ApplicationUser user, int categoryId, int page, int pageSize)
        {
            var category = await _booksRepository.GetCategoryByIdAsync(categoryId);
            var queryText = category != null ? category.Name : categoryId.ToString();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Category", queryText);
            var books = await _booksRepository.GetBooksByCategoryAsync(categoryId, page, pageSize);

            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            await _searchHistoryService.SaveSearchHistory(user.Id, queryText, "Category");

            return new PagedResultDto<BookSearchResultDto>
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain
            };
        }

        public async Task<PagedResultDto<BookSearchResultDto>> SearchBySellerAsync(
            ApplicationUser user, string sellerName, int page, int pageSize)
        {
            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Seller", sellerName);
            var books = await _booksRepository.GetBooksBySellerAsync(sellerName, page, pageSize);

            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            await _searchHistoryService.SaveSearchHistory(user.Id, sellerName, "Seller");

            return new PagedResultDto<BookSearchResultDto>
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain
            };
        }

        public async Task<object> SearchByPriceRangeAsync(
            ApplicationUser user, double minPrice, double maxPrice, int page, int pageSize)
        {
            var queryText = $"range:{minPrice}-{maxPrice}";
            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "PriceRange", queryText);

            if (!hasSub || remain == 0)
            {
                var (total, firstTwoTitles) = await _booksRepository.GetPartialInfoByPriceRangeAsync(minPrice, maxPrice);
                await _searchHistoryService.SaveSearchHistory(user.Id, queryText, "PriceRange");

                return new
                {
                    partialResults = true,
                    totalFound = total,
                    firstBookTitles = firstTwoTitles,
                    RemainingRequests = remain
                };
            }
            else
            {
                var books = await _booksRepository.GetBooksByPriceRangeAsync(minPrice, maxPrice, page, pageSize);
                await _searchHistoryService.SaveSearchHistory(user.Id, queryText, "PriceRange");

                return new
                {
                    partialResults = false,
                    Items = books.Items,
                    books.TotalPages,
                    RemainingRequests = remain
                };
            }
        }

        public async Task<BookDetailDto> GetBookByIdAsync(ApplicationUser user, int id)
        {
            bool hasSub = false;
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (subDto != null && subDto.IsActive)
                hasSub = true;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return null; // Или вернуть DTO c каким-то флагом "not found"

            if (!hasSub)
            {
                book.FinalPrice = null;
                book.Price = 0;
                book.EndDate = "Только для подписчиков";
                book.ImageArchiveUrl = null;
                book.IsImagesCompressed = false;
            }

            return book;
        }

        public async Task<(List<string> images, List<string> thumbnails)> GetBookImagesAsync(
            ApplicationUser user, int id)
        {
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return (new List<string>(), new List<string>());

            if (!hasSubscription)
            {
                return (new List<string>(), new List<string>());
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal)
                                 && useLocal;

            return await _bookImagesService.GetBookImagesAsync(book, hasSubscription, useLocalFiles);
        }

        public async Task<ActionResult> GetImageAsync(
            ApplicationUser user, int id, string imageName)
        {
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return null; // Аналог NotFound
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal)
                                 && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return null;

            return await _bookImagesService.GetImageAsync(book, imageName, hasSubscription, useLocalFiles);
        }

        public async Task<ActionResult> GetThumbnailAsync(
            ApplicationUser user, int id, string thumbnailName)
        {
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return null;
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal)
                                 && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return null;

            return await _bookImagesService.GetThumbnailAsync(book, thumbnailName, hasSubscription, useLocalFiles);
        }

        public async Task<PriceStatisticsDto> GetPriceStatisticsAsync(
            ApplicationUser user, int? categoryId = null)
        {
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                // Аналог Unauthorized
                return null;
            }

            var statistics = new PriceStatisticsDto();
            var query = _booksRepository.GetQueryable();

            if (categoryId.HasValue)
            {
                query = query.Where(b => b.CategoryId == categoryId.Value);
            }

            query = query.Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value > 0);
            var books = await query.ToListAsync();

            if (books.Any())
            {
                var prices = books.Select(b => b.FinalPrice.Value).ToList();
                statistics.AveragePrice = prices.Average();
                statistics.MedianPrice = CalculateMedian(prices);
                statistics.MaxPrice = prices.Max();
                statistics.MinPrice = prices.Min();
                statistics.TotalBooks = books.Count;
                statistics.TotalSales = books.Count(b => b.FinalPrice.HasValue && b.Status == 2);

                statistics.PriceRanges = CalculatePriceRanges(prices);

                if (!categoryId.HasValue)
                {
                    statistics.CategoryAveragePrices = await CalculateCategoryAveragePrices();
                }
            }

            return statistics;
        }

        private double CalculateMedian(List<double> values)
        {
            var sortedValues = values.OrderBy(v => v).ToList();
            int count = sortedValues.Count;

            if (count == 0)
                return 0;

            if (count % 2 == 0)
            {
                return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2;
            }
            else
            {
                return sortedValues[count / 2];
            }
        }

        private Dictionary<string, int> CalculatePriceRanges(List<double> prices)
        {
            var ranges = new Dictionary<string, int>
            {
                { "0-1000", 0 },
                { "1000-5000", 0 },
                { "5000-10000", 0 },
                { "10000-50000", 0 },
                { "50000+", 0 }
            };

            foreach (var price in prices)
            {
                if (price < 1000) ranges["0-1000"]++;
                else if (price < 5000) ranges["1000-5000"]++;
                else if (price < 10000) ranges["5000-10000"]++;
                else if (price < 50000) ranges["10000-50000"]++;
                else ranges["50000+"]++;
            }

            return ranges;
        }

        private async Task<Dictionary<string, double>> CalculateCategoryAveragePrices()
        {
            var result = new Dictionary<string, double>();

            var categoriesWithPrices = await _booksRepository.GetQueryable()
                .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value > 0)
                .GroupBy(b => b.CategoryId)
                .Select(g => new
                {
                    CategoryId = g.Key,
                    AveragePrice = g.Average(b => b.FinalPrice.Value)
                })
                .ToListAsync();

            foreach (var item in categoriesWithPrices)
            {
                var category = await _booksRepository.GetCategoryByIdAsync(item.CategoryId);
                if (category != null)
                {
                    result[category.Name] = item.AveragePrice;
                }
            }

            return result;
        }

        public async Task<List<RecentSaleDto>> GetRecentSalesAsync(ApplicationUser user, int limit = 5)
        {
            // Если клиент запрашивает слишком большой лимит, ограничиваем его
            if (limit > 20) limit = 20;

            // Базовая дата "три месяца назад"
            var threeMonthsAgo = DateTime.UtcNow.AddMonths(-3);

            try
            {
                // Проверяем, есть ли у пользователя активная подписка
                var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
                bool hasSubscription = (subDto != null && subDto.IsActive);

                // Список, который вернём в результате
                var recentSales = new List<RecentSaleDto>();

                // Для начала пытаемся найти продажи за последние 3 месяца
                var eligibleBooks = await _booksRepository.GetQueryable()
                    .Where(b => b.SoldQuantity > 0)                           // Книга продана
                    .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value >= 5000) // Цена >= 5000
                    .Where(b => b.EndDate >= threeMonthsAgo)                  // За последние 3 месяца
                    .ToListAsync();

                // Если в этой выборке что-то есть
                if (eligibleBooks.Any())
                {
                    if (hasSubscription)
                    {
                        // При наличии подписки рандомизируем
                        var random = new Random();
                        var randomized = eligibleBooks
                            .OrderBy(x => random.Next())
                            .Take(limit)
                            .ToList();

                        recentSales = randomized.Select(MapToDto).ToList();

                        _logger.LogInformation($"[Sub ON] Выбрано {recentSales.Count} продаж за последние 3 месяца (рандом).");
                    }
                    else
                    {
                        // Без подписки — никакой рандомизации
                        // Допустим, сортируем по дате убывания, берем Top-N
                        var notRandom = eligibleBooks
                            .OrderByDescending(b => b.EndDate)
                            .Take(limit)
                            .ToList();

                        recentSales = notRandom.Select(MapToDto).ToList();

                        _logger.LogInformation($"[Sub OFF] Выбрано {recentSales.Count} продаж за последние 3 месяца (без рандома).");
                    }
                }
                else
                {
                    // Если за 3 месяца ничего не нашли, снимаем ограничение по дате
                    var allEligible = await _booksRepository.GetQueryable()
                        .Where(b => b.Status == 2) // Статус "продано" (или SoldQuantity > 0)
                        .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value >= 5000)
                        .ToListAsync();

                    if (allEligible.Any())
                    {
                        if (hasSubscription)
                        {
                            var random = new Random();
                            var randomized = allEligible
                                .OrderBy(x => random.Next())
                                .Take(limit)
                                .ToList();

                            recentSales = randomized.Select(MapToDto).ToList();

                            _logger.LogWarning($"[Sub ON] За последние 3 месяца не нашли, " +
                                               $"после снятия ограничения выбрано {recentSales.Count} продаж (рандом).");
                        }
                        else
                        {
                            var notRandom = allEligible
                                .OrderByDescending(b => b.EndDate)
                                .Take(limit)
                                .ToList();

                            recentSales = notRandom.Select(MapToDto).ToList();

                            _logger.LogWarning($"[Sub OFF] За последние 3 месяца не нашли, " +
                                               $"после снятия ограничения выбрано {recentSales.Count} продаж (без рандома).");
                        }
                    }
                    else
                    {
                        // Вообще ничего не нашли
                        _logger.LogInformation("Не найдено ни одной продажи, удовлетворя критериям.");
                    }
                }

                return recentSales;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении недавних продаж");
                // Вместо null вернём пустой список, чтобы не падать на клиенте
                return new List<RecentSaleDto>();
            }
        }

        /// <summary>
        /// Вспомогательный метод для маппинга RegularBaseBook -> RecentSaleDto.
        /// </summary>
        private RecentSaleDto MapToDto(RegularBaseBook b)
        {
            return new RecentSaleDto
            {
                BookId = b.Id,
                Title = b.Title,
                FinalPrice = b.FinalPrice ?? 0,
                ThumbnailUrl = b.ThumbnailUrls.FirstOrDefault() ?? "",
                ImageUrl = b.ImageUrls.FirstOrDefault() ?? "",
                SaleDate = b.EndDate,
                SellerName = b.SellerName,
                Category = b.Category?.Name
            };
        }


        public async Task<PriceHistoryDto> GetPriceHistoryAsync(ApplicationUser user, int id)
        {
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return null;
            }

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return null;

            _logger.LogInformation($"Получение истории цен для книги {id} - {book.Title}");

            var titleWords = book.Title
                .Split(new[] { ' ', ',', '.', ':', ';', '-', '!', '?', '(', ')', '[', ']', '{', '}' }, StringSplitOptions.RemoveEmptyEntries)
                .Where(word => word.Length > 3)
                .Select(word => word.ToLowerInvariant())
                .ToList();

            var similarBooks = new List<RegularBaseBook>();
            if (titleWords.Any())
            {
                var query = _booksRepository.GetQueryable()
                    .Where(b => b.Id != id && b.FinalPrice.HasValue && b.FinalPrice.Value > 0);

                var predicate = PredicateBuilder.False<RegularBaseBook>();
                foreach (var word in titleWords)
                {
                    predicate = predicate.Or(b => b.NormalizedTitle.Contains(word));
                }

                similarBooks = await query
                    .Where(predicate)
                    .OrderByDescending(b => b.EndDate)
                    .Take(15)
                    .ToListAsync();
            }

            var history = new PriceHistoryDto
            {
                BookId = book.Id,
                Title = book.Title,
                PricePoints = new List<PricePoint>(),
                AveragePrice = 0,
                PriceChange = 0,
                PriceChangePercentage = 0,
                KeywordsUsed = titleWords
            };

            if (book.FinalPrice.HasValue && book.FinalPrice.Value > 0)
            {
                history.PricePoints.Add(new PricePoint
                {
                    Date = book.EndDate.ToString(),
                    Price = book.FinalPrice.Value,
                    Source = "Текущая книга",
                    BookId = book.Id,
                    Title = book.Title,
                    FirstImageName = book.ImageUrls.FirstOrDefault()
                });
            }
            else if (book.Price > 0)
            {
                history.PricePoints.Add(new PricePoint
                {
                    Date = book.BeginDate.ToString("dd.MM.yyyy"),
                    Price = book.Price,
                    Source = "Начальная цена",
                    BookId = book.Id,
                    Title = book.Title,
                    FirstImageName = book.ImageUrls.FirstOrDefault()
                });
            }

            foreach (var similar in similarBooks)
            {
                if (similar.FinalPrice.HasValue && similar.FinalPrice.Value > 0)
                {
                    var matchingKeywords = titleWords
                        .Where(word => similar.NormalizedTitle.Contains(word))
                        .ToList();

                    string matchInfo = matchingKeywords.Any()
                        ? $"Совпадения: {string.Join(", ", matchingKeywords)}"
                        : "Другие совпадения";

                    history.PricePoints.Add(new PricePoint
                    {
                        Date = similar.EndDate.ToString("dd.MM.yyyy"),
                        Price = similar.FinalPrice.Value,
                        Source = matchInfo,
                        BookId = similar.Id,
                        Title = similar.Title,
                        FirstImageName = similar.ImageUrls.FirstOrDefault()
                    });
                }
            }

            if (!history.PricePoints.Any() && book.Price > 0)
            {
                history.PricePoints.Add(new PricePoint
                {
                    Date = DateTime.Now.ToString("dd.MM.yyyy"),
                    Price = book.Price,
                    Source = "Текущая книга (прогноз)",
                    BookId = book.Id,
                    Title = book.Title,
                    FirstImageName = book.ImageUrls.FirstOrDefault()
                });
            }

            history.PricePoints = history.PricePoints
                .OrderBy(p => DateTime.Parse(p.Date))
                .ToList();

            if (history.PricePoints.Any())
            {
                var prices = history.PricePoints.Select(p => p.Price).ToList();
                history.AveragePrice = prices.Average();

                if (history.PricePoints.Count > 1)
                {
                    var firstPrice = history.PricePoints.First().Price;
                    var lastPrice = history.PricePoints.Last().Price;
                    history.PriceChange = lastPrice - firstPrice;
                    history.PriceChangePercentage = (firstPrice > 0)
                        ? (lastPrice - firstPrice) / firstPrice * 100
                        : 0;
                }
            }

            return history;
        }

        public async Task<BookValueEstimateDto> EstimateBookValueAsync(
            ApplicationUser user, BookValueEstimateRequest request)
        {
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return null;
            }

            if (request == null || string.IsNullOrWhiteSpace(request.Title))
            {
                // В реальном проекте можно бросить исключение или вернуть ошибку
                return null;
            }

            var estimate = new BookValueEstimateDto();
            var factors = new List<string>();
            var factorWeights = new Dictionary<string, double>();

            double baseValue = 1000;
            estimate.Confidence = 0.5;

            var query = _booksRepository.GetQueryable()
                .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value > 0);

            if (!string.IsNullOrWhiteSpace(request.Title))
            {
                var normalizedTitle = request.Title.ToLower();
                query = query.Where(b => b.NormalizedTitle.Contains(normalizedTitle));

                factors.Add("Поиск по названию");
                factorWeights["Название"] = 0.3;
                estimate.Confidence += 0.1;
            }

            if (request.CategoryId.HasValue)
            {
                query = query.Where(b => b.CategoryId == request.CategoryId.Value);
                factors.Add("Категория учтена");
                factorWeights["Категория"] = 0.2;
                estimate.Confidence += 0.1;
            }

            if (request.YearPublished.HasValue)
            {
                int year = request.YearPublished.Value;
                query = query.Where(b => b.YearPublished.HasValue && 
                                         Math.Abs(b.YearPublished.Value - year) <= 5);

                factors.Add($"Год издания: {year}");
                factorWeights["Год издания"] = 0.15;
                estimate.Confidence += 0.1;

                int currentYear = DateTime.Now.Year;
                int age = currentYear - year;

                if (age > 100)
                {
                    baseValue *= 2;
                    factors.Add("Книга старше 100 лет");
                    factorWeights["Возраст > 100 лет"] = 0.5;
                }
                else if (age > 50)
                {
                    baseValue *= 1.5;
                    factors.Add("Книга старше 50 лет");
                    factorWeights["Возраст > 50 лет"] = 0.3;
                }
            }

            if (request.IsFirstEdition)
            {
                baseValue *= 1.7;
                factors.Add("Первое издание");
                factorWeights["Первое издание"] = 0.4;
                estimate.Confidence += 0.05;
            }

            if (request.IsSigned)
            {
                baseValue *= 1.5;
                factors.Add("С подписью автора");
                factorWeights["Подпись автора"] = 0.3;
                estimate.Confidence += 0.05;
            }

            if (!string.IsNullOrWhiteSpace(request.Condition))
            {
                factors.Add($"Состояние: {request.Condition}");
                factorWeights["Состояние"] = 0.25;

                switch (request.Condition.ToLower())
                {
                    case "mint":
                    case "отличное":
                        baseValue *= 1.3;
                        break;
                    case "good":
                    case "хорошее":
                        baseValue *= 1.0;
                        break;
                    case "fair":
                    case "среднее":
                        baseValue *= 0.7;
                        break;
                    case "poor":
                    case "плохое":
                        baseValue *= 0.4;
                        break;
                }

                estimate.Confidence += 0.1;
            }

            var similarBooks = await query.Take(10).ToListAsync();

            if (similarBooks.Any())
            {
                var prices = similarBooks.Select(b => b.FinalPrice.Value).ToList();
                double similarBooksAvg = prices.Average();

                double weight = Math.Min(0.7, similarBooks.Count * 0.1);
                baseValue = baseValue * (1 - weight) + similarBooksAvg * weight;

                factors.Add($"Учтено {similarBooks.Count} аналогичных книг");
                factorWeights["Аналогичные книги"] = weight;
                estimate.Confidence += Math.Min(0.3, similarBooks.Count * 0.03);

                estimate.SimilarBooks = similarBooks
                    .Take(5)
                    .Select(b => new SimilarBookReference
                    {
                        BookId = b.Id,
                        Title = b.Title,
                        SalePrice = b.FinalPrice.Value,
                        Similarity = CalculateSimilarity(request, b)
                    })
                    .ToList();
            }
            else
            {
                estimate.Confidence -= 0.2;
                if (estimate.Confidence < 0.2) estimate.Confidence = 0.2;
            }

            if (estimate.Confidence > 0.95) estimate.Confidence = 0.95;
            if (estimate.Confidence < 0.1) estimate.Confidence = 0.1;

            estimate.EstimatedValue = Math.Round(baseValue, 2);
            estimate.MinimumValue = Math.Round(baseValue * 0.7, 2);
            estimate.MaximumValue = Math.Round(baseValue * 1.3, 2);
            estimate.Factors = factors;
            estimate.FactorWeights = factorWeights;

            return estimate;
        }

        private double CalculateSimilarity(BookValueEstimateRequest request, RegularBaseBook book)
        {
            double similarity = 0.5;

            if (!string.IsNullOrWhiteSpace(request.Title) &&
                book.Title.Contains(request.Title, StringComparison.OrdinalIgnoreCase))
            {
                similarity += 0.3;
            }

            if (request.YearPublished.HasValue && book.YearPublished.HasValue &&
                Math.Abs(request.YearPublished.Value - book.YearPublished.Value) <= 3)
            {
                similarity += 0.2;
            }

            if (request.CategoryId.HasValue && book.CategoryId == request.CategoryId.Value)
            {
                similarity += 0.2;
            }

            return Math.Min(similarity, 0.99);
        }

        public async Task<bool> AddBookToFavoritesAsync(string userId, int bookId)
        {
            try
            {
                // Проверяем, существует ли книга
                var book = await _booksRepository.GetBookByIdAsync(bookId);
                if (book == null)
                    return false;

                // Добавляем книгу в избранное через UserService
                return await _userService.AddBookToFavoritesAsync(userId, bookId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при добавлении книги {BookId} в избранное для пользователя {UserId}", bookId, userId);
                return false;
            }
        }

        public async Task<bool> RemoveBookFromFavoritesAsync(string userId, int bookId)
        {
            try
            {
                return await _userService.RemoveBookFromFavoritesAsync(userId, bookId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении книги {BookId} из избранного для пользователя {UserId}", bookId, userId);
                return false;
            }
        }

        public async Task<bool> IsBookInFavoritesAsync(string userId, int bookId)
        {
            try
            {
                return await _userService.IsBookInFavoritesAsync(userId, bookId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при проверке наличия книги {BookId} в избранном пользователя {UserId}", bookId, userId);
                return false;
            }
        }

        public async Task<PagedResultDto<BookDetailDto>> GetFavoriteBooksAsync(string userId, int page, int pageSize)
        {
            try
            {
                // Получаем список избранных книг пользователя
                var favoriteBooks = await _userService.GetUserFavoriteBooksAsync(userId);
                
                // Получаем только ID книг
                var bookIds = favoriteBooks.Select(fb => fb.BookId).ToList();
                
                // Определяем, сколько всего книг и сколько страниц
                int totalCount = bookIds.Count;
                int totalPages = (int)Math.Ceiling(totalCount / (double)pageSize);
                
                // Применяем пагинацию к списку ID
                var pagedBookIds = bookIds
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToList();
                
                // Загружаем полную информацию о книгах
                var detailedBooks = new List<BookDetailDto>();
                foreach (var id in pagedBookIds)
                {
                    var book = await _booksRepository.GetBookByIdAsync(id);
                    if (book != null)
                    {
                        detailedBooks.Add(book);
                    }
                }
                
                return new PagedResultDto<BookDetailDto>
                {
                    Items = detailedBooks,
                    TotalCount = totalCount,
                    TotalPages = totalPages
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении списка избранных книг для пользователя {UserId}", userId);
                return new PagedResultDto<BookDetailDto>
                {
                    Items = new List<BookDetailDto>(),
                    TotalCount = 0,
                    TotalPages = 0
                };
            }
        }

        public async Task<BookDetailDto> GetBookByIdAsync(int id)
        {
            try
            {
                return await _booksRepository.GetBookByIdAsync(id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении книги по ID {BookId}", id);
                return null;
            }
        }
    }
}
