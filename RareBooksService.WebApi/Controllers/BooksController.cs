using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.WebApi.Services;
using System.Threading.Tasks;

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
        public async Task<ActionResult> SearchByTitle(string title, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null)
                return Unauthorized();

            var result = await _booksService.SearchByTitleAsync(user, title, exactPhrase, page, pageSize);
            // если надо, можно проверить result == null и вернуть NotFound()

            return Ok(new
            {
                Items = result.Items,
                result.TotalPages,
                RemainingRequests = result.RemainingRequests 
            });
        }

        [HttpGet("searchByDescription")]
        public async Task<ActionResult> SearchByDescription(string description, bool exactPhrase = false, int page = 1, int pageSize = 10)
        {
            var user = await GetCurrentUserAsync();
            if (user == null) 
                return Unauthorized();

            var result = await _booksService.SearchByDescriptionAsync(user, description, exactPhrase, page, pageSize);
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
