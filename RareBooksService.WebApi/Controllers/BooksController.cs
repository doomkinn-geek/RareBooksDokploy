using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using RareBooksService.Data.Interfaces;
using RareBooksService.Parser.Services;
using RareBooksService.WebApi.Services;
using System.Threading.Tasks;
using System.Linq;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Text;
using System;
using RareBooksService.WebApi.Helpers;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // Требуется авторизация
    public class BooksController : BaseController
    {
        private readonly IRegularBaseBooksRepository _booksRepository;
        private readonly ISearchHistoryService _searchHistoryService;
        private readonly IBookImagesService _bookImagesService;
        private readonly ILogger<BooksController> _logger;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _env;
        private readonly ISubscriptionService _subscriptionService;

        // Для доступа к UserSearchStates
        private readonly UsersDbContext _usersDbContext;

        public BooksController(
            IRegularBaseBooksRepository booksRepository,
            ISearchHistoryService searchHistoryService,
            IBookImagesService bookImagesService,
            UserManager<ApplicationUser> userManager,
            ILogger<BooksController> logger,
            IConfiguration configuration,
            IWebHostEnvironment env,
            ISubscriptionService subscriptionService,
            UsersDbContext usersDbContext
        ) : base(userManager)
        {
            _booksRepository = booksRepository;
            _searchHistoryService = searchHistoryService;
            _bookImagesService = bookImagesService;
            _logger = logger;
            _configuration = configuration;
            _env = env;
            _subscriptionService = subscriptionService;

            _usersDbContext = usersDbContext;
        }

        /// <summary>
        /// Проверяет подписку, считает новый поиск, если запрос изменился.
        /// Если лимит исчерпан, отключает подписку (IsActive=false).
        /// Возвращает (hasSubscription, remainingRequests).
        /// </summary>
        private async Task<(bool hasSubscription, int? remainingRequests)>
            CheckIfNewSearchAndConsumeLimit(ApplicationUser user, string searchType, string queryText)
        {
            // 1) Есть ли действующая подписка
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (subDto == null || !subDto.IsActive)
            {
                // Нет подписки — возвращаем (false, 0)
                return (false, 0);
            }

            var plan = subDto.SubscriptionPlan;
            if (plan == null)
            {
                // Битые данные подписки
                return (false, 0);
            }

            // Безлимит
            if (plan.MonthlyRequestLimit <= 0)
            {
                return (true, null);
            }

            // Проверяем, не исчерпан ли уже
            if (subDto.UsedRequestsThisPeriod >= plan.MonthlyRequestLimit)
            {
                // Лимит уже исчерпан => отключаем
                subDto.IsActive = false;

                // Обновляем флажок у пользователя
                var userEntity = await _usersDbContext.Users.FindAsync(user.Id);
                if (userEntity != null)
                {
                    userEntity.HasSubscription = false;
                }

                await _subscriptionService.UpdateSubscriptionAsync(subDto);

                return (false, 0);
            }

            // 2) Проверяем, не новый ли это запрос
            var state = await _usersDbContext.UserSearchStates
                .FirstOrDefaultAsync(s => s.UserId == user.Id && s.SearchType == searchType);

            bool isNewSearch = false;
            if (state == null)
            {
                // Записи нет => новый поиск
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
                // Запись есть
                if (state.LastQuery != queryText)
                {
                    // новый поиск
                    isNewSearch = true;
                    state.LastQuery = queryText;
                    state.UpdatedAt = DateTime.UtcNow;
                    _usersDbContext.UserSearchStates.Update(state);
                }
            }

            // Если действительно новый поиск
            if (isNewSearch)
            {
                subDto.UsedRequestsThisPeriod++;
                await _subscriptionService.UpdateSubscriptionAsync(subDto);
            }

            // Сохраняем изменения в UserSearchStates
            await _usersDbContext.SaveChangesAsync();

            // Считаем остаток
            var used = subDto.UsedRequestsThisPeriod;
            var limit = plan.MonthlyRequestLimit;
            var remain = limit - used;

            // Если вдруг «ушли» в минус (не должно, но на всякий случай)
            if (remain < 0) remain = 0;

            // Если только что исчерпали лимит => отключим подписку
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

            // Если после этого подписка стала неактивной, возвращаем (false,0)
            if (!subDto.IsActive)
            {
                return (false, 0);
            }

            // Иначе (активна, есть остаток)
            return (true, remain);
        }

        /// <summary>
        /// Скрывает цены/даты/превью-картинку, если нет подписки.
        /// </summary>
        private void ApplyNoSubscriptionRulesToSearchResults(List<BookSearchResultDto> books)
        {
            foreach (var b in books)
            {
                b.Price = 0;
                b.Date = "Только для подписчиков";
                b.FirstImageName = "";
            }
        }

        // =======================
        // Методы поиска
        // =======================

        [HttpGet("searchByTitle")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchByTitle(
            string title, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Поиск по названию: {Title}, page={Page}", title, page);

            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Title", title);

            var books = await _booksRepository.GetBooksByTitleAsync(title, page, pageSize, exactPhrase);

            // Если подписки нет или лимит исчерпан => скрываем платную информацию
            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            // Пишем в историю поиска
            await _searchHistoryService.SaveSearchHistory(user.Id, title, "Title");

            // Возвращаем всегда: даже если осталось 0, frontend покажет "0" оставшихся
            return Ok(new
            {
                Items = books.Items,
                books.TotalPages,
                RemainingRequests = remain // null => безлимит 
            });
        }

        [HttpGet("searchByDescription")]
        public async Task<ActionResult> SearchByDescription(
            string description, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Description", description);

            var books = await _booksRepository.GetBooksByDescriptionAsync(description, page, pageSize, exactPhrase);

            if (!hasSub || remain == 0)
            {
                // Скрываем данные
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            await _searchHistoryService.SaveSearchHistory(user.Id, description, "Description");

            return Ok(new
            {
                Items = books.Items,
                books.TotalPages,
                RemainingRequests = remain
            });
        }

        [HttpGet("searchByCategory")]
        public async Task<ActionResult> SearchByCategory(
            int categoryId, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            // Для корректной записи в историю: берём название категории
            var category = await _booksRepository.GetCategoryByIdAsync(categoryId);
            var queryText = category != null ? category.Name : categoryId.ToString();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Category", queryText);

            var books = await _booksRepository.GetBooksByCategoryAsync(categoryId, page, pageSize);

            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            await _searchHistoryService.SaveSearchHistory(user.Id, queryText, "Category");

            return Ok(new
            {
                Items = books.Items,
                books.TotalPages,
                RemainingRequests = remain
            });
        }

        [HttpGet("searchBySeller")]
        public async Task<ActionResult> SearchBySeller(
            string sellerName, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Seller", sellerName);

            var books = await _booksRepository.GetBooksBySellerAsync(sellerName, page, pageSize);

            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            await _searchHistoryService.SaveSearchHistory(user.Id, sellerName, "Seller");

            return Ok(new
            {
                Items = books.Items,
                books.TotalPages,
                RemainingRequests = remain
            });
        }

        [HttpGet("searchByPriceRange")]
        public async Task<ActionResult> SearchByPriceRange(
    double minPrice, double maxPrice, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var queryText = $"range:{minPrice}-{maxPrice}";

            // Проверяем подписку
            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "PriceRange", queryText);

            if (!hasSub || remain == 0)
            {
                // Если подписки нет/лимит исчерпан => выдаём только частичную информацию
                // и специальное поле partialResults=true
                var (total, firstTwoTitles) = await _booksRepository.GetPartialInfoByPriceRangeAsync(minPrice, maxPrice);

                // Лог поиска
                await _searchHistoryService.SaveSearchHistory(user.Id, queryText, "PriceRange");

                return Ok(new
                {
                    partialResults = true,
                    totalFound = total,
                    firstBookTitles = firstTwoTitles,
                    RemainingRequests = remain
                });
            }
            else
            {
                // Полноценный поиск
                var books = await _booksRepository.GetBooksByPriceRangeAsync(minPrice, maxPrice, page, pageSize);

                // Лог
                await _searchHistoryService.SaveSearchHistory(user.Id, queryText, "PriceRange");

                return Ok(new
                {
                    partialResults = false,
                    Items = books.Items,
                    books.TotalPages,
                    RemainingRequests = remain
                });
            }
        }




        /// <summary>
        /// Просмотр детали книги: без подписки часть информации скрывается,
        /// но мы не запрещаем просмотр полностью.
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<BookDetailDto>> GetBookById(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            bool hasSub = false;
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (subDto != null && subDto.IsActive)
                hasSub = true;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return NotFound();

            if (!hasSub)
            {
                // Скрываем часть данных
                book.FinalPrice = null;
                book.Price = 0;
                book.EndDate = "Только для подписчиков";
                book.ImageArchiveUrl = null;
                book.IsImagesCompressed = false;
            }

            return Ok(book);
        }

        // ==============================================
        // Методы для изображений
        // ==============================================

        /// <summary>
        /// Возвращает список имён файлов (images, thumbnails).
        /// Если нет подписки — пустой список.
        /// </summary>
        [HttpGet("{id}/images")]
        public async Task<ActionResult> GetBookImages(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return NotFound();

            // Если у пользователя нет подписки — вернуть пустые списки
            if (!hasSubscription)
            {
                return Ok(new { images = new List<string>(), thumbnails = new List<string>() });
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal)
                                 && useLocal;

            var (images, thumbnails) = await _bookImagesService.GetBookImagesAsync(book, hasSubscription, useLocalFiles);
            return Ok(new { images, thumbnails });
        }

        /// <summary>
        /// Возвращает полноразмерное изображение (требуется подписка).
        /// Без подписки возвращаем NotFound (чтобы "скрыть" наличие файла).
        /// </summary>
        [HttpGet("{id}/images/{imageName}")]
        public async Task<ActionResult> GetImage(int id, string imageName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return NotFound();
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal)
                                 && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return NotFound();

            var result = await _bookImagesService.GetImageAsync(book, imageName, hasSubscription, useLocalFiles);
            if (result == null)
                return NotFound();

            return result;
        }

        /// <summary>
        /// Возвращает миниатюру (требуется подписка).
        /// Без подписки — NotFound().
        /// </summary>
        [HttpGet("{id}/thumbnails/{thumbnailName}")]
        public async Task<ActionResult> GetThumbnail(int id, string thumbnailName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return NotFound();
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal)
                                 && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return NotFound();

            var result = await _bookImagesService.GetThumbnailAsync(book, thumbnailName, hasSubscription, useLocalFiles);
            if (result == null)
                return NotFound();

            return result;
        }

        /// <summary>
        /// Возвращает статистику цен по книгам, опционально фильтруя по категории
        /// </summary>
        [HttpGet("price-statistics")]
        public async Task<ActionResult<PriceStatisticsDto>> GetPriceStatistics([FromQuery] int? categoryId = null)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            // Проверка подписки
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return Unauthorized(new { message = "Требуется активная подписка для доступа к статистике цен" });
            }

            var statistics = new PriceStatisticsDto();
            
            // Получаем книги с учетом фильтра по категории
            var query = _booksRepository.GetQueryable();
            if (categoryId.HasValue)
            {
                query = query.Where(b => b.CategoryId == categoryId.Value);
            }

            // Только книги с указанной финальной ценой
            query = query.Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value > 0);
            
            var books = await query.ToListAsync();
            
            if (books.Any())
            {
                // Рассчитываем базовую статистику
                var prices = books.Select(b => b.FinalPrice.Value).ToList();
                statistics.AveragePrice = prices.Average();
                statistics.MedianPrice = CalculateMedian(prices);
                statistics.MaxPrice = prices.Max();
                statistics.MinPrice = prices.Min();
                statistics.TotalBooks = books.Count;
                statistics.TotalSales = books.Count(b => b.FinalPrice.HasValue && b.Status == 2); // Предполагаем, что Status 2 означает "продано"
                
                // Расчет диапазонов цен
                statistics.PriceRanges = CalculatePriceRanges(prices);
                
                // Расчет средних цен по категориям
                if (!categoryId.HasValue)
                {
                    statistics.CategoryAveragePrices = await CalculateCategoryAveragePrices();
                }
            }
            
            return Ok(statistics);
        }
        
        /// <summary>
        /// Вспомогательный метод для вычисления медианы
        /// </summary>
        private double CalculateMedian(List<double> values)
        {
            var sortedValues = values.OrderBy(v => v).ToList();
            int count = sortedValues.Count;
            
            if (count == 0)
                return 0;
                
            if (count % 2 == 0)
            {
                // Четное количество - берем среднее двух средних значений
                return (sortedValues[count / 2 - 1] + sortedValues[count / 2]) / 2;
            }
            else
            {
                // Нечетное количество - берем среднее значение
                return sortedValues[count / 2];
            }
        }
        
        /// <summary>
        /// Рассчитывает распределение книг по ценовым диапазонам
        /// </summary>
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
        
        /// <summary>
        /// Рассчитывает средние цены по категориям
        /// </summary>
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

        /// <summary>
        /// Возвращает список недавних продаж книг с ценой больше 5000
        /// </summary>
        [HttpGet("recent-sales")]
        public async Task<ActionResult<List<RecentSaleDto>>> GetRecentSales([FromQuery] int limit = 5)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();
                
            // Проверка подписки
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return Unauthorized(new { message = "Требуется активная подписка для доступа к данным о продажах" });
            }
            
            // Ограничиваем запрашиваемое количество
            if (limit > 20) limit = 20;
            
            // Вычисляем дату три месяца назад (вместо одного)
            var threeMonthsAgo = DateTime.UtcNow.AddMonths(-3);
            
            try 
            {
                // Получаем проданные книги за последние три месяца с ценой больше 5000
                var recentSales = await _booksRepository.GetQueryable()
                    .Where(b => b.SoldQuantity > 0) // Статус "продано"
                    .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value >= 5000) // Цена больше или равна 5000
                    .Where(b => b.EndDate >= threeMonthsAgo) // Только продажи за последние три месяца
                    .OrderByDescending(b => b.EndDate) // Сначала самые свежие
                    .Take(limit)
                    .Select(b => new RecentSaleDto
                    {
                        BookId = b.Id,
                        Title = b.Title,
                        FinalPrice = b.FinalPrice.Value,
                        ThumbnailUrl = b.ThumbnailUrls.FirstOrDefault() ?? "",
                        ImageUrl = b.ImageUrls.FirstOrDefault() ?? "", // Добавляем первое полноформатное изображение
                        SaleDate = b.EndDate,
                        SellerName = b.SellerName,
                        Category = b.Category.Name
                    })
                    .ToListAsync();
                
                if (!recentSales.Any())
                {
                    // Если не нашли продажи по заданным критериям, попробуем найти без ограничения по дате
                    recentSales = await _booksRepository.GetQueryable()
                        .Where(b => b.Status == 2) // Статус "продано"
                        .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value >= 5000) // Цена больше или равна 5000
                        .OrderByDescending(b => b.EndDate) // Сначала самые свежие
                        .Take(limit)
                        .Select(b => new RecentSaleDto
                        {
                            BookId = b.Id,
                            Title = b.Title,
                            FinalPrice = b.FinalPrice.Value,
                            ThumbnailUrl = b.ThumbnailUrls.FirstOrDefault() ?? "",
                            ImageUrl = b.ImageUrls.FirstOrDefault() ?? "",
                            SaleDate = b.EndDate,
                            SellerName = b.SellerName,
                            Category = b.Category.Name
                        })
                        .ToListAsync();

                    _logger.LogWarning($"Найдено {recentSales.Count} продаж после снятия ограничения по дате");
                }
                else
                {
                    _logger.LogInformation($"Найдено {recentSales.Count} продаж за последние три месяца с ценой >= 5000");
                }
                
                return Ok(recentSales);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении недавних продаж");
                return StatusCode(500, new { message = "Внутренняя ошибка сервера при получении данных о продажах" });
            }
        }

        /// <summary>
        /// Возвращает историю цен для указанной книги
        /// </summary>
        [HttpGet("{id}/price-history")]
        public async Task<ActionResult<PriceHistoryDto>> GetPriceHistory(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();
                
            // Проверка подписки
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return Unauthorized(new { message = "Требуется активная подписка для доступа к истории цен" });
            }
            
            // Получаем книгу
            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return NotFound();
            
            _logger.LogInformation($"Получение истории цен для книги {id} - {book.Title}");
            
            // Извлекаем ключевые слова из заголовка (слова длиннее 3 символов)
            var titleWords = book.Title
                .Split(new[] { ' ', ',', '.', ':', ';', '-', '!', '?', '(', ')', '[', ']', '{', '}' }, StringSplitOptions.RemoveEmptyEntries)
                .Where(word => word.Length > 3)
                .Select(word => word.ToLowerInvariant())
                .ToList();
                
            _logger.LogInformation($"Извлечены ключевые слова из заголовка: {string.Join(", ", titleWords)}");
            
            // Находим книги с совпадающими ключевыми словами в заголовке
            var similarBooks = new List<RegularBaseBook>();
            
            if (titleWords.Any())
            {
                var query = _booksRepository.GetQueryable()
                    .Where(b => b.Id != id && b.FinalPrice.HasValue && b.FinalPrice.Value > 0);
                
                // Добавляем условие для каждого ключевого слова (должно совпадать хотя бы одно)
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
                    
                _logger.LogInformation($"Найдено {similarBooks.Count} книг с совпадающими ключевыми словами в заголовке");
            }
            
            // Создаем историю с данными текущей книги и похожих
            var history = new PriceHistoryDto
            {
                BookId = book.Id,
                Title = book.Title,
                PricePoints = new List<PricePoint>(),
                AveragePrice = 0,
                PriceChange = 0,
                PriceChangePercentage = 0,
                KeywordsUsed = titleWords // Добавляем использованные ключевые слова
            };
            
            // Добавляем текущую цену
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
                
                _logger.LogInformation($"Добавлена текущая цена: {book.FinalPrice.Value} на дату {book.EndDate}");
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
                
                _logger.LogInformation($"Добавлена начальная цена: {book.Price} на дату {book.BeginDate}");
            }
            
            // Добавляем цены книг с совпадающими ключевыми словами
            foreach (var similar in similarBooks)
            {
                if(similar.FinalPrice.HasValue && similar.FinalPrice.Value > 0)
                {
                    // Находим совпадающие ключевые слова
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
                    
                    _logger.LogInformation($"Добавлена книга с совпадающими ключевыми словами: {similar.Title}, {similar.FinalPrice.Value}, {similar.EndDate}");
                }
            }
            
            // Если история пуста, добавляем хотя бы одну точку с текущей книгой
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
                
                _logger.LogInformation($"История была пуста, добавлена точка по умолчанию");
            }
            
            // Сортируем по дате
            history.PricePoints = history.PricePoints.OrderBy(p => DateTime.Parse(p.Date)).ToList();
            
            // Рассчитываем статистику
            if (history.PricePoints.Any())
            {
                var prices = history.PricePoints.Select(p => p.Price).ToList();
                history.AveragePrice = prices.Average();
                
                // Рассчитываем изменение цены (между первой и последней точкой)
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
            
            _logger.LogInformation($"Возвращается история цен с {history.PricePoints.Count} точками");
            
            return Ok(history);
        }

        /// <summary>
        /// Оценивает стоимость книги на основе переданных параметров
        /// </summary>
        [HttpPost("estimate-value")]
        public async Task<ActionResult<BookValueEstimateDto>> EstimateBookValue([FromBody] BookValueEstimateRequest request)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();
                
            // Проверка подписки
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return Unauthorized(new { message = "Требуется активная подписка для оценки стоимости книг" });
            }
            
            if (request == null || string.IsNullOrWhiteSpace(request.Title))
            {
                return BadRequest(new { message = "Не указано название книги" });
            }
            
            // Оценка стоимости книги на основе переданных параметров
            var estimate = new BookValueEstimateDto();
            var factors = new List<string>();
            var factorWeights = new Dictionary<string, double>();
            
            // Базовое значение
            double baseValue = 1000;
            estimate.Confidence = 0.5; // Начальная уверенность
            
            // Находим похожие книги по названию и категории
            var query = _booksRepository.GetQueryable()
                .Where(b => b.FinalPrice.HasValue && b.FinalPrice.Value > 0);
                
            // Применяем фильтры
            if (!string.IsNullOrWhiteSpace(request.Title))
            {
                // Нормализуем запрос аналогично хранимым данным
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
                // Ищем книги примерно того же года издания (+/- 5 лет)
                int year = request.YearPublished.Value;
                query = query.Where(b => b.YearPublished.HasValue && 
                                        Math.Abs(b.YearPublished.Value - year) <= 5);
                                        
                factors.Add($"Год издания: {year}");
                factorWeights["Год издания"] = 0.15;
                estimate.Confidence += 0.1;
                
                // Возраст книги влияет на стоимость
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
            
            // Учитываем особые характеристики
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
                
                // Учитываем состояние книги
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
            
            // Получаем похожие книги для анализа
            var similarBooks = await query.Take(10).ToListAsync();
            
            // Если нашли похожие книги - используем их для уточнения оценки
            if (similarBooks.Any())
            {
                var prices = similarBooks.Select(b => b.FinalPrice.Value).ToList();
                double similarBooksAvg = prices.Average();
                
                // Корректируем базовое значение на основе похожих книг
                // Если мало данных, смешиваем с базовой оценкой
                // Если много данных, больше полагаемся на них
                double weight = Math.Min(0.7, similarBooks.Count * 0.1);
                baseValue = baseValue * (1 - weight) + similarBooksAvg * weight;
                
                factors.Add($"Учтено {similarBooks.Count} аналогичных книг");
                factorWeights["Аналогичные книги"] = weight;
                estimate.Confidence += Math.Min(0.3, similarBooks.Count * 0.03);
                
                // Добавляем ссылки на похожие книги
                estimate.SimilarBooks = similarBooks.Take(5).Select(b => new SimilarBookReference
                {
                    BookId = b.Id,
                    Title = b.Title,
                    SalePrice = b.FinalPrice.Value,
                    Similarity = CalculateSimilarity(request, b)
                }).ToList();
            }
            else
            {
                // Если нет похожих книг, снижаем уверенность
                estimate.Confidence -= 0.2;
                if (estimate.Confidence < 0.2) estimate.Confidence = 0.2;
            }
            
            // Ограничиваем уверенность диапазоном от 0 до 1
            if (estimate.Confidence > 0.95) estimate.Confidence = 0.95;
            if (estimate.Confidence < 0.1) estimate.Confidence = 0.1;
            
            // Устанавливаем итоговые значения
            estimate.EstimatedValue = Math.Round(baseValue, 2);
            estimate.MinimumValue = Math.Round(baseValue * 0.7, 2);
            estimate.MaximumValue = Math.Round(baseValue * 1.3, 2);
            estimate.Factors = factors;
            estimate.FactorWeights = factorWeights;
            
            return Ok(estimate);
        }
        
        /// <summary>
        /// Рассчитывает степень сходства между запросом и книгой
        /// </summary>
        private double CalculateSimilarity(BookValueEstimateRequest request, RegularBaseBook book)
        {
            double similarity = 0.5; // Базовая схожесть
            
            // Сравниваем название
            if (!string.IsNullOrWhiteSpace(request.Title) && 
                book.Title.Contains(request.Title, StringComparison.OrdinalIgnoreCase))
            {
                similarity += 0.3;
            }
            
            // Сравниваем год
            if (request.YearPublished.HasValue && book.YearPublished.HasValue &&
                Math.Abs(request.YearPublished.Value - book.YearPublished.Value) <= 3)
            {
                similarity += 0.2;
            }
            
            // Сравниваем категорию
            if (request.CategoryId.HasValue && book.CategoryId == request.CategoryId.Value)
            {
                similarity += 0.2;
            }
            
            // Ограничиваем значение от 0 до 1
            return Math.Min(similarity, 0.99);
        }
    }
}
