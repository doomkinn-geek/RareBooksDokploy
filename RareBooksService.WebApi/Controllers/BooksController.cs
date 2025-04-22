using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.WebApi.Services;
using System.Threading.Tasks;
using System.Linq;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] 
    public class BooksController : BaseController
    {
        private readonly IBooksService _booksService;
        
        public BooksController(
            IBooksService booksService,
            UserManager<ApplicationUser> userManager
        ) : base(userManager)
        {
            _booksService = booksService;
        }

        [HttpGet("searchByTitle")]
        public async Task<ActionResult> SearchByTitle(string title, bool exactPhrase = false, string categoryIds = null, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            // Преобразуем строку с разделителями в список целых чисел
            List<int> categoryIdsList = null;
            if (!string.IsNullOrEmpty(categoryIds))
            {
                categoryIdsList = categoryIds.Split(',')
                    .Where(id => !string.IsNullOrEmpty(id))
                    .Select(id => int.TryParse(id, out int parsedId) ? parsedId : -1)
                    .Where(id => id != -1)
                    .ToList();
            }

            var result = categoryIdsList != null && categoryIdsList.Any() 
                ? await _booksService.SearchByTitleAsync(user, title, exactPhrase, categoryIdsList, page, pageSize)
                : await _booksService.SearchByTitleAsync(user, title, exactPhrase, page, pageSize);

            return Ok(new
            {
                Items = result.Items,
                result.TotalPages,
                RemainingRequests = result.RemainingRequests 
            });
        }

        [HttpGet("searchByDescription")]
        public async Task<ActionResult> SearchByDescription(string description, bool exactPhrase = false, string categoryIds = null, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) 
                return Unauthorized();

            // Преобразуем строку с разделителями в список целых чисел
            List<int> categoryIdsList = null;
            if (!string.IsNullOrEmpty(categoryIds))
            {
                categoryIdsList = categoryIds.Split(',')
                    .Where(id => !string.IsNullOrEmpty(id))
                    .Select(id => int.TryParse(id, out int parsedId) ? parsedId : -1)
                    .Where(id => id != -1)
                    .ToList();
            }

            var result = categoryIdsList != null && categoryIdsList.Any() 
                ? await _booksService.SearchByDescriptionAsync(user, description, exactPhrase, categoryIdsList, page, pageSize)
                : await _booksService.SearchByDescriptionAsync(user, description, exactPhrase, page, pageSize);

            return Ok(new
            {
                Items = result.Items,
                result.TotalPages,
                RemainingRequests = result.RemainingRequests
            });
        }

        [HttpGet("searchByCategory")]
        public async Task<ActionResult> SearchByCategory(int categoryId, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var result = await _booksService.SearchByCategoryAsync(user, categoryId, page, pageSize);
            return Ok(new
            {
                Items = result.Items,
                result.TotalPages,
                RemainingRequests = result.RemainingRequests
            });
        }

        [HttpGet("searchBySeller")]
        public async Task<ActionResult> SearchBySeller(string sellerName, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) 
                return Unauthorized();

            var result = await _booksService.SearchBySellerAsync(user, sellerName, page, pageSize);
            return Ok(new
            {
                Items = result.Items,
                result.TotalPages,
                RemainingRequests = result.RemainingRequests
            });
        }

        [HttpGet("searchByPriceRange")]
        public async Task<ActionResult> SearchByPriceRange(double minPrice, double maxPrice, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) 
                return Unauthorized();

            var result = await _booksService.SearchByPriceRangeAsync(user, minPrice, maxPrice, page, pageSize);
            return Ok(result);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<BookDetailDto>> GetBookById(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var book = await _booksService.GetBookByIdAsync(user, id);
            if (book == null)
                return NotFound(); 

            return Ok(book);
        }

        [HttpGet("{id}/images")]
        public async Task<ActionResult> GetBookImages(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var (images, thumbnails) = await _booksService.GetBookImagesAsync(user, id);
            return Ok(new { images, thumbnails });
        }

        [HttpGet("{id}/images/{imageName}")]
        public async Task<ActionResult> GetImage(int id, string imageName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var fileResult = await _booksService.GetImageAsync(user, id, imageName);
            if (fileResult == null)
                return NotFound();

            return fileResult;
        }

        [HttpGet("{id}/thumbnails/{thumbnailName}")]
        public async Task<ActionResult> GetThumbnail(int id, string thumbnailName)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var fileResult = await _booksService.GetThumbnailAsync(user, id, thumbnailName);
            if (fileResult == null)
                return NotFound();

            return fileResult;
        }

        [HttpGet("price-statistics")]
        public async Task<ActionResult<PriceStatisticsDto>> GetPriceStatistics([FromQuery] int? categoryId = null)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var stats = await _booksService.GetPriceStatisticsAsync(user, categoryId);
            if (stats == null)
                return Unauthorized(new { message = "Требуется подписка" });

            return Ok(stats);
        }

        [HttpGet("recent-sales")]
        public async Task<ActionResult<List<RecentSaleDto>>> GetRecentSales([FromQuery] int limit = 5)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var sales = await _booksService.GetRecentSalesAsync(user, limit);
            if (sales == null)
                return NotFound(new { message = "Данные не найдены" });

            return Ok(sales);
        }

        /// <summary>
        /// Добавляет книгу в избранное текущего пользователя
        /// </summary>
        [HttpPost("{id}/favorite")]
        public async Task<ActionResult> AddToFavorites(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            // Проверяем, существует ли книга
            var book = await _booksService.GetBookByIdAsync(id);
            if (book == null)
                return NotFound(new { message = "Книга не найдена" });

            var result = await _booksService.AddBookToFavoritesAsync(user.Id, id);
            
            if (!result)
                return BadRequest(new { message = "Книга уже в избранном или произошла ошибка" });

            return Ok(new { message = "Книга добавлена в избранное" });
        }

        /// <summary>
        /// Проверяет, находится ли книга в избранном у текущего пользователя
        /// </summary>
        [HttpGet("{id}/is-favorite")]
        public async Task<ActionResult<bool>> CheckIfFavorite(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var isFavorite = await _booksService.IsBookInFavoritesAsync(user.Id, id);
            
            return Ok(isFavorite);
        }

        /// <summary>
        /// Удаляет книгу из избранного текущего пользователя
        /// </summary>
        [HttpDelete("{id}/favorite")]
        public async Task<ActionResult> RemoveFromFavorites(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var result = await _booksService.RemoveBookFromFavoritesAsync(user.Id, id);
            
            if (!result)
                return NotFound(new { message = "Книга не найдена в избранном" });

            return NoContent();
        }

        /// <summary>
        /// Получает список всех избранных книг текущего пользователя
        /// </summary>
        [HttpGet("favorites")]
        public async Task<ActionResult<List<BookDetailDto>>> GetFavoriteBooks(int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var favorites = await _booksService.GetFavoriteBooksAsync(user.Id, page, pageSize);
            
            if (favorites == null || !favorites.Items.Any())
                return Ok(new { items = new List<BookDetailDto>(), totalCount = 0 });

            return Ok(favorites);
        }

        [HttpGet("{id}/price-history")]
        public async Task<ActionResult<PriceHistoryDto>> GetPriceHistory(int id)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var history = await _booksService.GetPriceHistoryAsync(user, id);
            if (history == null)
                return Unauthorized(new { message = "Требуется подписка или книга не найдена" });

            return Ok(history);
        }

        [HttpPost("estimate-value")]
        public async Task<ActionResult<BookValueEstimateDto>> EstimateBookValue([FromBody] BookValueEstimateRequest request)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var estimate = await _booksService.EstimateBookValueAsync(user, request);
            if (estimate == null)
                return Unauthorized(new { message = "Требуется подписка или отсутствуют данные для оценки" });

            return Ok(estimate);
        }
    }
}
