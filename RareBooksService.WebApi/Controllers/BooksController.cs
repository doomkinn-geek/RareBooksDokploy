using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;
using RareBooksService.Parser.Services;
using RareBooksService.WebApi.Services;
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
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

        public BooksController(
            IRegularBaseBooksRepository booksRepository,
            ISearchHistoryService searchHistoryService,
            IBookImagesService bookImagesService,
            UserManager<ApplicationUser> userManager,
            ILogger<BooksController> logger,
            IConfiguration configuration,
            IWebHostEnvironment env
        ) : base(userManager)
        {
            _booksRepository = booksRepository;
            _searchHistoryService = searchHistoryService;
            _bookImagesService = bookImagesService;
            _logger = logger;
            _configuration = configuration;
            _env = env;
        }

        private async Task<bool> UserHasSubscriptionAsync()
        {
            var user = await GetCurrentUserAsync();
            return (user != null && user.HasSubscription);
        }

        private void ApplyNoSubscriptionRulesToSearchResults(List<BookSearchResultDto> books)
        {
            // Если нет подписки, скрываем цены, заменяем дату и т.п.
            foreach (var b in books)
            {
                b.Price = 0;
                // Вместо реальной даты отображаем сообщение
                b.Date = "Только для подписчиков";
                b.FirstImageName = "";
            }
        }

        [HttpGet("searchByTitle")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchByTitle(string title, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Запрос поиска по названию: '{Title}', точная фраза: {ExactPhrase}, страница: {Page}, размер страницы: {PageSize}", title, exactPhrase, page, pageSize);

            var books = await _booksRepository.GetBooksByTitleAsync(title, page, pageSize, exactPhrase);
            var hasSubscription = await UserHasSubscriptionAsync();           


            if (!hasSubscription)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            if (page == 1)
            {
                var user = await GetCurrentUserAsync();
                if (user != null)
                {
                    await _searchHistoryService.SaveSearchHistory(user.Id, title, "Title");
                    _logger.LogInformation("Сохранение истории поиска для пользователя {UserId}: '{SearchQuery}'", user.Id, title);
                }
            }

            return Ok(books);
        }

        [HttpGet("searchByDescription")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchByDescription(string description, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Запрос поиска по описанию: '{Description}', точная фраза: {ExactPhrase}, страница: {Page}, размер страницы: {PageSize}", description, exactPhrase, page, pageSize);

            if (page == 1)
            {
                var user = await GetCurrentUserAsync();
                if (user != null)
                {
                    await _searchHistoryService.SaveSearchHistory(user.Id, description, "Description");
                    _logger.LogInformation("Сохранение истории поиска для пользователя {UserId}: '{SearchQuery}'", user.Id, description);
                }
            }

            var books = await _booksRepository.GetBooksByDescriptionAsync(description, page, pageSize, exactPhrase);
            var hasSubscription = await UserHasSubscriptionAsync();

            if (!hasSubscription)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            return Ok(books);
        }

        [HttpGet("searchByCategory")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchByCategory(int categoryId, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Запрос поиска по категории: {CategoryId}, страница: {Page}, размер страницы: {PageSize}", categoryId, page, pageSize);

            var books = await _booksRepository.GetBooksByCategoryAsync(categoryId, page, pageSize);
            var hasSubscription = await UserHasSubscriptionAsync();

            if (!hasSubscription)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            if (page == 1)
            {
                var user = await GetCurrentUserAsync();
                var category = await _booksRepository.GetCategoryByIdAsync(categoryId);
                if (user != null && category != null)
                {
                    await _searchHistoryService.SaveSearchHistory(user.Id, category.Name, "Category");
                    _logger.LogInformation("Сохранение истории поиска для пользователя {UserId}: категория '{CategoryName}'", user.Id, category.Name);
                }
            }

            return Ok(books);
        }

        [HttpGet("searchByPriceRange")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchByPriceRange(double minPrice, double maxPrice, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Запрос поиска по диапазону цен: от {MinPrice} до {MaxPrice}, страница: {Page}, размер страницы: {PageSize}", minPrice, maxPrice, page, pageSize);

            if (page == 1)
            {
                var user = await GetCurrentUserAsync();
                if (user != null)
                {
                    await _searchHistoryService.SaveSearchHistory(user.Id, $"от {minPrice} до {maxPrice} рублей", "PriceRange");
                    _logger.LogInformation("Сохранение истории поиска для пользователя {UserId}: диапазон цен от {MinPrice} до {MaxPrice}", user.Id, minPrice, maxPrice);
                }
            }

            var hasSubscription = await UserHasSubscriptionAsync();

            if (!hasSubscription)
            {
                _logger.LogWarning("Доступ запрещен: требуется подписка для поиска по диапазону цен.");
                return Forbid("Требуется подписка для поиска по диапазону цен.");
            }

            var books = await _booksRepository.GetBooksByPriceRangeAsync(minPrice, maxPrice, page, pageSize);
            return Ok(books);
        }

        [HttpGet("searchBySeller")]
        public async Task<ActionResult<PagedResultDto<BookSearchResultDto>>> SearchBySeller(string sellerName, int page = 1, int pageSize = 10)
        {
            _logger.LogInformation("Запрос поиска по продавцу: '{SellerName}', страница: {Page}, размер страницы: {PageSize}", sellerName, page, pageSize);

            if (page == 1)
            {
                var user = await GetCurrentUserAsync();
                if (user != null)
                {
                    await _searchHistoryService.SaveSearchHistory(user.Id, sellerName, "Seller");
                    _logger.LogInformation("Сохранение истории поиска для пользователя {UserId}: продавец '{SellerName}'", user.Id, sellerName);
                }
            }

            var books = await _booksRepository.GetBooksBySellerAsync(sellerName, page, pageSize);
            var hasSubscription = await UserHasSubscriptionAsync();

            if (!hasSubscription)
            {
                ApplyNoSubscriptionRulesToSearchResults(books.Items);
            }

            return Ok(books);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<BookDetailDto>> GetBookById(int id)
        {
            var hasSubscription = await UserHasSubscriptionAsync();
            var book = await _booksRepository.GetBookByIdAsync(id);

            if (book == null)
                return NotFound();

            if (!hasSubscription)
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
            _logger.LogInformation("Получение списка изображений книги {Id}", id);
            var hasSubscription = await UserHasSubscriptionAsync();

            // Определяем, используется ли локальное хранение
            //bool useLocalFiles = _configuration.GetValue<bool>("TypeOfAccessImages:UseLocalFiles");
            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            var (images, thumbnails) = await _bookImagesService.GetBookImagesAsync(book, hasSubscription, useLocalFiles);
            return Ok(new { images, thumbnails });
        }

        [HttpGet("{id}/images/{imageName}")]
        public async Task<ActionResult> GetImage(int id, string imageName)
        {
            _logger.LogInformation("Запрос полноразмерного изображения '{imageName}' книги ID={Id}", imageName, id);

            bool hasSubscription = await UserHasSubscriptionAsync();

            //bool useLocalFiles = _configuration.GetValue<bool>("TypeOfAccessImages:UseLocalFiles");
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
            _logger.LogInformation("Запрос миниатюры '{thumbnailName}' книги ID={Id}", thumbnailName, id);

            bool hasSubscription = await UserHasSubscriptionAsync();

            //bool useLocalFiles = _configuration.GetValue<bool>("TypeOfAccessImages:UseLocalFiles");
            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null) return NotFound();

            var result = await _bookImagesService.GetThumbnailAsync(book, thumbnailName, hasSubscription, useLocalFiles);
            if (result == null) return NotFound();
            return result;
        }
    }
}
