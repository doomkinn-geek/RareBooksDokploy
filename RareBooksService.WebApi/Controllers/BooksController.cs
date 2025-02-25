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
    }
}
