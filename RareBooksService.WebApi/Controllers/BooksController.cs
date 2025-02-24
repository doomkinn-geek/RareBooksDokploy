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

        // Чтобы мы могли читать/записывать UserSearchStates
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
        /// Проверяет подписку, смотрит в UserSearchStates,
        /// если текущий запрос не совпадает с последним — прибавляет 1 к счётчику.
        /// Возвращает (hasSubscription, remainRequests).
        /// Если лимит исчерпан — вернётся (true, 0) => нужно вызвать Forbid().
        /// Если нет подписки — (false, 0).
        /// </summary>
        private async Task<(bool hasSubscription, int? remainingRequests)>
            CheckIfNewSearchAndConsumeLimit(ApplicationUser user, string searchType, string queryText)
        {
            // 1) Смотрим, есть ли активная подписка
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (subDto == null || !subDto.IsActive)
            {
                // нет подписки
                return (false, 0);
            }

            var plan = subDto.SubscriptionPlan;
            if (plan == null)
            {
                // данные подписки битые
                return (false, 0);
            }

            // безлимит
            if (plan.MonthlyRequestLimit <= 0)
            {
                return (true, null);
            }

            // если уже исчерпано
            if (subDto.UsedRequestsThisPeriod >= plan.MonthlyRequestLimit)
            {
                return (true, 0);
            }

            // 2) ищем в UserSearchStates
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
                    // другой запрос => новый
                    isNewSearch = true;
                    state.LastQuery = queryText;
                    state.UpdatedAt = DateTime.UtcNow;
                    _usersDbContext.UserSearchStates.Update(state);
                }
            }

            if (isNewSearch)
            {
                // прибавляем 1 к счётчику
                subDto.UsedRequestsThisPeriod++;
                // обновляем в БД
                await _subscriptionService.UpdateSubscriptionAsync(subDto);
            }

            // Сохраняем изменения в UserSearchStates
            await _usersDbContext.SaveChangesAsync();

            // Считаем остаток
            var used = subDto.UsedRequestsThisPeriod;
            var limit = plan.MonthlyRequestLimit;

            var remain = limit - used;
            if (remain < 0) remain = 0;

            return (true, remain);
        }

        /// <summary>
        /// Скрывает цены/даты, если нет подписки (логика без изменений).
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
        // Примеры методов поиска
        // =======================

        [HttpGet("searchByTitle")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchByTitle(
                string title, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Поиск по названию: {Title}, page={Page}", title, page);

            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            // Проверяем подписку + лимит
            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Title", title);            

            var books = await _booksRepository.GetBooksByTitleAsync(title, page, pageSize, exactPhrase);

            // Если нет подписки (но у нас hasSub == true — теоретически невозможно),
            // но оставим проверку на всякий случай:
            // Если нет подписки или лимит запросов исчерпан — скрываем цену/дату/превью-картинку
            if (!hasSub || remain == 0)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            // Лог поиска
            await _searchHistoryService.SaveSearchHistory(user.Id, title, "Title");

            return Ok(new
            {
                Items = books.Items,
                TotalPages = books.TotalPages,
                RemainingRequests = remain // null => безлимит 
            });
        }

        [HttpGet("searchByDescription")]
        public async Task<ActionResult> SearchByDescription(
            string description, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Description", description);
            if (!hasSub)
                return Forbid("Нет активной подписки.");
            if (remain == 0)
                return Forbid("Лимит запросов исчерпан.");

            var books = await _booksRepository.GetBooksByDescriptionAsync(description, page, pageSize, exactPhrase);

            // ...
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
            if (user == null) return Unauthorized();

            // Найдём имя категории
            var category = await _booksRepository.GetCategoryByIdAsync(categoryId);
            var queryText = category != null ? category.Name : categoryId.ToString();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Category", queryText);
            if (!hasSub) return Forbid("Нет подписки");
            if (remain == 0) return Forbid("Лимит исчерпан.");

            var books = await _booksRepository.GetBooksByCategoryAsync(categoryId, page, pageSize);

            // ...
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
            if (user == null) return Unauthorized();

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "Seller", sellerName);
            if (!hasSub) return Forbid("Нет подписки");
            if (remain == 0) return Forbid("Лимит исчерпан.");

            var books = await _booksRepository.GetBooksBySellerAsync(sellerName, page, pageSize);
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
            if (user == null) return Unauthorized();

            var queryText = $"range:{minPrice}-{maxPrice}";

            var (hasSub, remain) = await CheckIfNewSearchAndConsumeLimit(user, "PriceRange", queryText);
            if (!hasSub) return Forbid("Нет подписки");
            if (remain == 0) return Forbid("Лимит исчерпан.");

            var books = await _booksRepository.GetBooksByPriceRangeAsync(minPrice, maxPrice, page, pageSize);

            await _searchHistoryService.SaveSearchHistory(user.Id, queryText, "PriceRange");

            return Ok(new
            {
                Items = books.Items,
                books.TotalPages,
                RemainingRequests = remain
            });
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<BookDetailDto>> GetBookById(int id)
        {
            // просматривать книгу можно и без подписки?
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var hasSub = false;
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            if (subDto != null && subDto.IsActive)
                hasSub = true;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
                return NotFound();

            if (!hasSub)
            {
                // скрываем часть данных (как у вас и было)
                book.FinalPrice = null;
                book.Price = 0;
                book.EndDate = "Только для подписчиков";
                book.ImageArchiveUrl = null;
                book.IsImagesCompressed = false;
            }

            return Ok(book);
        }

        // ==============================================
        //  Методы для получения изображений и списков
        // ==============================================

        /// <summary>
        /// Возвращает список имён файлов (images, thumbnails).
        /// Если нет подписки — возвращаем пустой список.
        /// Если книга малоценная — берём списки из внешних URL (если есть).
        /// Если книга обычная и подписка есть — разбираем ZIP или Legacy.
        /// </summary>
        [HttpGet("{id}/images")]
        public async Task<ActionResult> GetBookImages(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            // Проверяем подписку
            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            // Если у пользователя нет подписки — пустой список
            if (!hasSubscription)
            {
                return Ok(new { images = new List<string>(), thumbnails = new List<string>() });
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            // Получаем списки файлов
            var (images, thumbnails) = await _bookImagesService.GetBookImagesAsync(book, hasSubscription, useLocalFiles);
            return Ok(new { images, thumbnails });
        }

        /// <summary>
        /// Возвращает конкретный полноразмерный файл (blob).
        /// Для любых изображений теперь требуется подписка (включая малоценные).
        /// </summary>
        [HttpGet("{id}/images/{imageName}")]
        public async Task<ActionResult> GetImage(int id, string imageName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                // Можно возвращать 404, чтобы "спрятать" факт существования изображения
                // или 200 c пустым телом. На ваше усмотрение.
                return NotFound();
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            // Поручаем сервису достать файл
            var result = await _bookImagesService.GetImageAsync(book, imageName, hasSubscription, useLocalFiles);
            if (result == null) return NotFound();

            return result;
        }

        /// <summary>
        /// Возвращает конкретную миниатюру (blob).
        /// Аналогично полноразмерным — требуется подписка.
        /// </summary>
        [HttpGet("{id}/thumbnails/{thumbnailName}")]
        public async Task<ActionResult> GetThumbnail(int id, string thumbnailName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) return Unauthorized();

            var subDto = await _subscriptionService.GetActiveSubscriptionForUser(user.Id);
            bool hasSubscription = (subDto != null && subDto.IsActive);
            if (!hasSubscription)
            {
                return NotFound(); // или другой способ скрыть изображение
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            var result = await _bookImagesService.GetThumbnailAsync(book, thumbnailName, hasSubscription, useLocalFiles);
            if (result == null) return NotFound();

            return result;
        }
    }
}
