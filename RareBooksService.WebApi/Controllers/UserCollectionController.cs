using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using RareBooksService.WebApi.Helpers;
using RareBooksService.WebApi.Services;
using System.Security.Claims;

namespace RareBooksService.WebApi.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    [RequiresCollectionAccess]
    public class UserCollectionController : ControllerBase
    {
        private readonly IUserCollectionService _collectionService;
        private readonly ICollectionMatchingService _matchingService;
        private readonly ICollectionImageService _imageService;
        private readonly ICollectionExportService _exportService;
        private readonly UsersDbContext _usersContext;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ILogger<UserCollectionController> _logger;

        public UserCollectionController(
            IUserCollectionService collectionService,
            ICollectionMatchingService matchingService,
            ICollectionImageService imageService,
            ICollectionExportService exportService,
            UsersDbContext usersContext,
            UserManager<ApplicationUser> userManager,
            ILogger<UserCollectionController> logger)
        {
            _collectionService = collectionService;
            _matchingService = matchingService;
            _imageService = imageService;
            _exportService = exportService;
            _usersContext = usersContext;
            _userManager = userManager;
            _logger = logger;
        }

        private string GetUserId()
        {
            return User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? throw new UnauthorizedAccessException("Пользователь не авторизован");
        }

        private async Task<ApplicationUser> GetCurrentUserAsync()
        {
            var userId = GetUserId();
            return await _userManager.FindByIdAsync(userId);
        }

        /// <summary>
        /// Получить список всех книг в коллекции
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<List<UserCollectionBookDto>>> GetCollection()
        {
            try
            {
                var userId = GetUserId();
                var books = await _collectionService.GetUserCollectionAsync(userId);
                return Ok(books);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении коллекции");
                return StatusCode(500, new { error = "Ошибка при получении коллекции" });
            }
        }

        /// <summary>
        /// Получить статистику коллекции
        /// </summary>
        [HttpGet("statistics")]
        public async Task<ActionResult<CollectionStatisticsDto>> GetStatistics()
        {
            try
            {
                var userId = GetUserId();
                var stats = await _collectionService.GetStatisticsAsync(userId);
                return Ok(stats);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении статистики");
                return StatusCode(500, new { error = "Ошибка при получении статистики" });
            }
        }

        /// <summary>
        /// Получить детальную информацию о книге
        /// </summary>
        [HttpGet("{id}")]
        public async Task<ActionResult<UserCollectionBookDetailsDto>> GetBookDetails(int id)
        {
            try
            {
                var userId = GetUserId();
                var book = await _collectionService.GetBookDetailsAsync(id, userId);
                return Ok(book);
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении деталей книги {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при получении деталей книги" });
            }
        }

        /// <summary>
        /// Добавить книгу в коллекцию
        /// </summary>
        [HttpPost]
        public async Task<ActionResult<UserCollectionBookDto>> AddBook([FromBody] AddCollectionBookRequest request)
        {
            try
            {
                var userId = GetUserId();
                var book = await _collectionService.AddBookToCollectionAsync(request, userId);
                return CreatedAtAction(nameof(GetBookDetails), new { id = book.Id }, book);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при добавлении книги в коллекцию");
                return StatusCode(500, new { error = "Ошибка при добавлении книги" });
            }
        }

        /// <summary>
        /// Обновить информацию о книге
        /// </summary>
        [HttpPut("{id}")]
        public async Task<ActionResult<UserCollectionBookDto>> UpdateBook(int id, [FromBody] UpdateCollectionBookRequest request)
        {
            try
            {
                var userId = GetUserId();
                var book = await _collectionService.UpdateBookAsync(id, request, userId);
                return Ok(book);
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обновлении книги {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при обновлении книги" });
            }
        }

        /// <summary>
        /// Удалить книгу из коллекции
        /// </summary>
        [HttpDelete("{id}")]
        public async Task<ActionResult> DeleteBook(int id)
        {
            try
            {
                var userId = GetUserId();
                await _collectionService.DeleteBookAsync(id, userId);
                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении книги {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при удалении книги" });
            }
        }

        /// <summary>
        /// Загрузить изображение для книги
        /// </summary>
        [HttpPost("{id}/images")]
        [RequestSizeLimit(50_000_000)] // 50 MB
        [RequestFormLimits(MultipartBodyLengthLimit = 50_000_000)]
        public async Task<ActionResult<UserCollectionBookImageDto>> UploadImage(int id, IFormFile file)
        {
            try
            {
                if (file == null || file.Length == 0)
                {
                    return BadRequest(new { error = "Файл не предоставлен" });
                }

                var userId = GetUserId();
                var image = await _collectionService.UploadBookImageAsync(id, file, userId);
                return Ok(image);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при загрузке изображения для книги {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при загрузке изображения" });
            }
        }

        /// <summary>
        /// Удалить изображение
        /// </summary>
        [HttpDelete("{id}/images/{imageId}")]
        public async Task<ActionResult> DeleteImage(int id, int imageId)
        {
            try
            {
                var userId = GetUserId();
                await _collectionService.DeleteBookImageAsync(id, imageId, userId);
                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении изображения {ImageId}", imageId);
                return StatusCode(500, new { error = "Ошибка при удалении изображения" });
            }
        }

        /// <summary>
        /// Установить главное изображение
        /// </summary>
        [HttpPut("{id}/images/{imageId}/setmain")]
        public async Task<ActionResult> SetMainImage(int id, int imageId)
        {
            try
            {
                var userId = GetUserId();
                await _collectionService.SetMainImageAsync(id, imageId, userId);
                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при установке главного изображения {ImageId}", imageId);
                return StatusCode(500, new { error = "Ошибка при установке главного изображения" });
            }
        }

        /// <summary>
        /// Получить изображение
        /// </summary>
        [HttpGet("{bookId}/images/{fileName}")]
        public async Task<ActionResult> GetImage(int bookId, string fileName)
        {
            _logger.LogInformation("Запрос изображения: bookId={BookId}, fileName={FileName}", bookId, fileName);
            try
            {
                var userId = GetUserId();
                _logger.LogInformation("UserId для изображения: {UserId}", userId);
                var imagePath = await _imageService.GetImagePathAsync(userId, bookId, fileName);
                
                var contentType = "image/jpeg";
                var extension = Path.GetExtension(fileName).ToLowerInvariant();
                if (extension == ".png") contentType = "image/png";
                else if (extension == ".webp") contentType = "image/webp";

                return PhysicalFile(imagePath, contentType);
            }
            catch (FileNotFoundException)
            {
                return NotFound();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении изображения {FileName}", fileName);
                return StatusCode(500, new { error = "Ошибка при получении изображения" });
            }
        }

        /// <summary>
        /// Найти аналоги для книги
        /// </summary>
        [HttpGet("{id}/matches")]
        public async Task<ActionResult<List<BookMatchDto>>> FindMatches(int id)
        {
            try
            {
                var userId = GetUserId();
                var user = await GetCurrentUserAsync();
                if (user == null)
                {
                    return Unauthorized("Пользователь не авторизован");
                }

                var book = await _collectionService.GetBookDetailsAsync(id, userId);
                
                // Преобразуем DTO обратно в модель для поиска
                var bookModel = new Common.Models.UserCollectionBook
                {
                    Id = book.Id,
                    Title = book.Title,
                    Author = book.Author,
                    YearPublished = book.YearPublished,
                    Description = book.Description
                };

                var matches = await _matchingService.FindMatchesAsync(bookModel, user);
                return Ok(matches);
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при поиске аналогов для книги {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при поиске аналогов" });
            }
        }

        /// <summary>
        /// Найти аналоги для книги с пользовательским запросом
        /// </summary>
        [HttpGet("{id}/matches/search")]
        public async Task<ActionResult<List<BookMatchDto>>> FindMatchesWithCustomQuery(int id, [FromQuery] string query)
        {
            try
            {
                var userId = GetUserId();
                var user = await GetCurrentUserAsync();
                if (user == null)
                {
                    return Unauthorized("Пользователь не авторизован");
                }

                if (string.IsNullOrWhiteSpace(query))
                {
                    return BadRequest(new { error = "Запрос не может быть пустым" });
                }

                var book = await _collectionService.GetBookDetailsAsync(id, userId);
                
                // Создаем временную модель с пользовательским запросом
                var bookModel = new Common.Models.UserCollectionBook
                {
                    Id = book.Id,
                    Title = query, // Используем пользовательский запрос
                    Author = book.Author,
                    YearPublished = book.YearPublished,
                    Description = book.Description
                };

                _logger.LogInformation("Поиск аналогов с пользовательским запросом '{Query}' для книги {BookId}", query, id);
                
                var matches = await _matchingService.FindMatchesAsync(bookModel, user);
                return Ok(matches);
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при поиске аналогов с пользовательским запросом для книги {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при поиске аналогов" });
            }
        }

        /// <summary>
        /// Выбрать референсную книгу
        /// </summary>
        [HttpPost("{id}/reference")]
        public async Task<ActionResult> SelectReferenceBook(int id, [FromBody] SelectReferenceRequest request)
        {
            try
            {
                var userId = GetUserId();
                await _matchingService.SelectReferenceBookAsync(id, request.ReferenceBookId, userId);
                return NoContent();
            }
            catch (InvalidOperationException ex)
            {
                return NotFound(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при выборе референсной книги для {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при выборе референсной книги" });
            }
        }

        /// <summary>
        /// Удалить референсную книгу
        /// </summary>
        [HttpDelete("{id}/reference")]
        public async Task<ActionResult> RemoveReferenceBook(int id)
        {
            try
            {
                var userId = GetUserId();
                
                // Получаем книгу
                var book = await _usersContext.UserCollectionBooks
                    .FirstOrDefaultAsync(b => b.Id == id && b.UserId == userId);
                
                if (book == null)
                {
                    return NotFound(new { error = "Книга не найдена" });
                }

                // Удаляем референс
                book.ReferenceBookId = null;
                book.UpdatedDate = DateTime.UtcNow;
                await _usersContext.SaveChangesAsync();

                // Пересчитываем оценку на основе других аналогов
                await _matchingService.UpdateEstimatedPriceAsync(id, userId);

                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении референсной книги для {BookId}", id);
                return StatusCode(500, new { error = "Ошибка при удалении референсной книги" });
            }
        }

        /// <summary>
        /// Экспортировать коллекцию в PDF
        /// </summary>
        [HttpGet("export/pdf")]
        public async Task<ActionResult> ExportToPdf()
        {
            try
            {
                var userId = GetUserId();
                var pdfBytes = await _exportService.ExportToPdfAsync(userId);
                
                var fileName = $"collection_{DateTime.Now:yyyyMMdd}.pdf";
                return File(pdfBytes, "application/pdf", fileName);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при экспорте в PDF");
                return StatusCode(500, new { error = "Ошибка при экспорте коллекции" });
            }
        }

        /// <summary>
        /// Экспортировать коллекцию в JSON+ZIP
        /// </summary>
        [HttpGet("export/json")]
        public async Task<ActionResult> ExportToJson()
        {
            try
            {
                var userId = GetUserId();
                var zipBytes = await _exportService.ExportToJsonAsync(userId);
                
                var fileName = $"collection_{DateTime.Now:yyyyMMdd}.zip";
                return File(zipBytes, "application/zip", fileName);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { error = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при экспорте в JSON");
                return StatusCode(500, new { error = "Ошибка при экспорте коллекции" });
            }
        }
    }

    /// <summary>
    /// Запрос на выбор референсной книги
    /// </summary>
    public class SelectReferenceRequest
    {
        public int ReferenceBookId { get; set; }
    }
}

