using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;
using RareBooksService.Parser.Services;
using RareBooksService.WebApi.Services;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // Требуется авторизация для всех действий
    public class BooksController : BaseController
    {
        private readonly IRegularBaseBooksRepository _booksRepository;
        private readonly ISearchHistoryService _searchHistoryService;
        private readonly IBookImagesService _bookImagesService;
        private readonly ILogger<BooksController> _logger;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _env;
        private readonly ISubscriptionService _subscriptionService;

        public BooksController(
            IRegularBaseBooksRepository booksRepository,
            ISearchHistoryService searchHistoryService,
            IBookImagesService bookImagesService,
            UserManager<ApplicationUser> userManager,
            ILogger<BooksController> logger,
            IConfiguration configuration,
            IWebHostEnvironment env,
            ISubscriptionService subscriptionService
        ) : base(userManager)
        {
            _booksRepository = booksRepository;
            _searchHistoryService = searchHistoryService;
            _bookImagesService = bookImagesService;
            _logger = logger;
            _configuration = configuration;
            _env = env;
            _subscriptionService = subscriptionService;
        }

        /// <summary>
        /// Универсальный метод, который проверяет подписку и при необходимости «тратит» 1 запрос из лимита,
        /// возвращает (hasSubscription, remainRequests) — сколько запросов осталось у пользователя, если > 0.
        /// Если лимит исчерпан — вернётся (false, 0) и вы сможете вызвать return Forbid(...).
        /// Если подписки нет — тоже (false, 0).
        /// </summary>
        private async Task<(bool hasSubscription, int? remainRequests)>
            CheckSubscriptionAndConsumeLimit(ApplicationUser user, bool consume = true)
        {
            var sub = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (sub == null || !sub.IsActive)
            {
                // Нет активной подписки
                return (false, 0);
            }

            var plan = sub.SubscriptionPlan;
            if (plan == null)
            {
                // Ситуация, когда plan не подгрузился 
                // (или subscription data corrupt)
                return (false, 0);
            }

            if (plan.MonthlyRequestLimit <= 0)
            {
                // Безлимит
                return (true, null);
            }

            // Есть лимит
            var used = sub.UsedRequestsThisPeriod;
            if (used >= plan.MonthlyRequestLimit)
            {
                // Лимит исчерпан
                return (true, 0);
            }

            // Иначе — если нужно «потратить» 1 запрос
            if (consume)
            {
                sub.UsedRequestsThisPeriod += 1;
                await _subscriptionService.UpdateSubscriptionAsync(sub);
            }

            var remain = plan.MonthlyRequestLimit - sub.UsedRequestsThisPeriod;
            return (true, remain); // осталось <remain> запросов
        }

        /// <summary>
        /// Скрывает цены/даты, если нет подписки.
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

        // Пример: улучшенная версия searchByTitle
        [HttpGet("searchByTitle")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchByTitle(
                string title, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Поиск по названию: {Title}, page={Page}", title, page);

            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            // Если это первая страница, проверяем лимит
            (bool hasSub, int? remain) = (true, null);

            if (page == 1)
            {
                (hasSub, remain) = await CheckSubscriptionAndConsumeLimit(user, consume: true);
                // Если lim=0 => Forbid
                if (hasSub && remain == 0)
                {
                    return Forbid("Вы исчерпали лимит запросов в этом месяце.");
                }
            }

            var books = await _booksRepository.GetBooksByTitleAsync(title, page, pageSize, exactPhrase);

            // Если нет подписки — скрываем цены и т.п.
            if (!hasSub)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            // Лог поиска только на первой странице
            if (page == 1)
            {
                await _searchHistoryService.SaveSearchHistory(user.Id, title, "Title");
            }

            // Возвращаем поле, которое указывает пользователю, сколько осталось запросов
            // (например, remain == null => безлимит)
            return Ok(new
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain // null => безлимит, число => остаток, 0 => исчерпан
            });
        }

        [HttpGet("searchByDescription")]
        public async Task<ActionResult> SearchByDescription(
            string description, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            (bool hasSub, int? remain) = (true, null);

            if (page == 1)
            {
                (hasSub, remain) = await CheckSubscriptionAndConsumeLimit(user, consume: true);
                if (hasSub && remain == 0)
                {
                    return Forbid("Вы исчерпали лимит запросов в этом месяце.");
                }

                // Лог
                await _searchHistoryService.SaveSearchHistory(user.Id, description, "Description");
            }

            var books = await _booksRepository.GetBooksByDescriptionAsync(description, page, pageSize, exactPhrase);

            if (!hasSub)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            return Ok(new
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain
            });
        }

        [HttpGet("searchByCategory")]
        public async Task<ActionResult> SearchByCategory(
            int categoryId, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            (bool hasSub, int? remain) = (true, null);

            if (page == 1)
            {
                (hasSub, remain) = await CheckSubscriptionAndConsumeLimit(user, consume: true);
                if (hasSub && remain == 0)
                {
                    return Forbid("Вы исчерпали лимит запросов в этом месяце.");
                }

                // Лог
                var category = await _booksRepository.GetCategoryByIdAsync(categoryId);
                if (category != null)
                {
                    await _searchHistoryService.SaveSearchHistory(user.Id, category.Name, "Category");
                }
            }

            var books = await _booksRepository.GetBooksByCategoryAsync(categoryId, page, pageSize);

            if (!hasSub)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            return Ok(new
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain
            });
        }

        [HttpGet("searchByPriceRange")]
        public async Task<ActionResult> SearchByPriceRange(
            double minPrice, double maxPrice, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            // В вашем коде: требуется подписка
            // Но всё равно проверим лимиты
            var subscription = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (subscription == null || !subscription.IsActive)
            {
                return Forbid("Требуется активная подписка для поиска по диапазону цен.");
            }

            if (page == 1)
            {
                var limit = subscription.SubscriptionPlan.MonthlyRequestLimit;
                if (limit > 0)
                {
                    if (subscription.UsedRequestsThisPeriod >= limit)
                    {
                        return Forbid("Вы исчерпали лимит запросов в этом месяце.");
                    }
                    subscription.UsedRequestsThisPeriod++;
                    await _subscriptionService.UpdateSubscriptionAsync(subscription);
                }

                await _searchHistoryService.SaveSearchHistory(
                    user.Id, $"от {minPrice} до {maxPrice} рублей", "PriceRange");
            }

            var books = await _booksRepository.GetBooksByPriceRangeAsync(
                minPrice, maxPrice, page, pageSize);

            return Ok(new
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = (subscription.SubscriptionPlan.MonthlyRequestLimit > 0)
                    ? (subscription.SubscriptionPlan.MonthlyRequestLimit - subscription.UsedRequestsThisPeriod)
                    : (int?)null
            });
        }

        [HttpGet("searchBySeller")]
        public async Task<ActionResult> SearchBySeller(
            string sellerName, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            (bool hasSub, int? remain) = (true, null);

            if (page == 1)
            {
                (hasSub, remain) = await CheckSubscriptionAndConsumeLimit(user, consume: true);
                if (hasSub && remain == 0)
                {
                    return Forbid("Вы исчерпали лимит запросов в этом месяце.");
                }

                await _searchHistoryService.SaveSearchHistory(user.Id, sellerName, "Seller");
            }

            var books = await _booksRepository.GetBooksBySellerAsync(sellerName, page, pageSize);

            if (!hasSub)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            return Ok(new
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain
            });
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<BookDetailDto>> GetBookById(int id)
        {
            // По вашему описанию, просмотр книги требует авторизации, 
            // но не обязательно подписки (или сами решите).
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var hasSub = false;
            var sub = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (sub != null && sub.IsActive) hasSub = true;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return NotFound();

            if (!hasSub)
            {
                // скрываем часть данных
                book.FinalPrice = null;
                book.Price = 0;
                book.EndDate = "Только для подписчиков";
                book.ImageArchiveUrl = null;
                book.IsImagesCompressed = false;
            }

            return Ok(book);
        }

        [HttpGet("{id}/images")]
        public async Task<ActionResult> GetBookImages(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var hasSubscription = false;
            var sub = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (sub != null && sub.IsActive) hasSubscription = true;

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            var (images, thumbnails) = await _bookImagesService.GetBookImagesAsync(book, hasSubscription, useLocalFiles);
            return Ok(new { images, thumbnails });
        }

        [HttpGet("{id}/images/{imageName}")]
        public async Task<ActionResult> GetImage(int id, string imageName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var hasSubscription = false;
            var sub = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (sub != null && sub.IsActive) hasSubscription = true;

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            var result = await _bookImagesService.GetImageAsync(book, imageName, hasSubscription, useLocalFiles);
            if (result == null) return NotFound();
            return result;
        }

        [HttpGet("{id}/thumbnails/{thumbnailName}")]
        public async Task<ActionResult> GetThumbnail(int id, string thumbnailName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var hasSubscription = false;
            var sub = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (sub != null && sub.IsActive) hasSubscription = true;

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            var result = await _bookImagesService.GetThumbnailAsync(book, thumbnailName, hasSubscription, useLocalFiles);
            if (result == null) return NotFound();
            return result;
        }
    }
}
