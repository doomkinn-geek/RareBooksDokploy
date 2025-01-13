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
        private readonly IWebHostEnvironment _environment;
        private readonly IConfiguration _configuration;
        private readonly ISearchHistoryService _searchHistoryService;
        private readonly IYandexStorageService _yandexStorageService;
        private readonly ILogger<BooksController> _logger;

        public BooksController(
            IRegularBaseBooksRepository booksRepository,
            IWebHostEnvironment environment,
            IConfiguration configuration,
            UserManager<ApplicationUser> userManager,
            ISearchHistoryService searchHistoryService,
            IYandexStorageService yandexStorageService,
            ILogger<BooksController> logger) : base(userManager)
        {
            _booksRepository = booksRepository;
            _environment = environment;
            _configuration = configuration;
            _searchHistoryService = searchHistoryService;
            _yandexStorageService = yandexStorageService;
            _logger = logger;
        }

        private async Task<bool> UserHasSubscriptionAsync()
        {
            var user = await GetCurrentUserAsync();
            bool hasSubscription = user != null && user.HasSubscription;
            _logger.LogInformation("Проверка подписки для пользователя {UserId}: {HasSubscription}", user?.Id, hasSubscription);
            return hasSubscription;
        }
        private void ApplyNoSubscriptionRulesToSearchResults(List<BookSearchResultDto> books)
        {
            // Если нет подписки, скрываем цены, заменяем дату и т.п.
            foreach (var b in books)
            {
                b.Price = 0;
                // Вместо реальной даты отображаем сообщение
                b.Date = "Только для подписчиков";
                b.FirstThumbnailName = "";
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
            _logger.LogInformation("Запрос получения книги по ID: {BookId}", id);

            var hasSubscription = await UserHasSubscriptionAsync();
            var book = await _booksRepository.GetBookByIdAsync(id);

            if (book == null)
            {
                _logger.LogWarning("Книга с ID {BookId} не найдена.", id);
                return NotFound();
            }

            if (!hasSubscription)
            {
                // Очищаем данные, которые нельзя показывать без подписки:
                book.FinalPrice = null; 
                book.Price = 0;
                book.EndDate = "Только для подписчиков";
                book.ImageArchiveUrl = null;
                book.IsImagesCompressed = false;                                                
            }

            _logger.LogInformation("Возвращение деталей книги с ID {BookId}", id);
            return Ok(book);
        }


        [HttpGet("{id}/images")]
        public async Task<ActionResult> GetBookImages(int id)
        {
            _logger.LogInformation("Запрос получения изображений для книги с ID {BookId}", id);

            var hasSubscription = await UserHasSubscriptionAsync();
            var book = await _booksRepository.GetBookByIdAsync(id);

            if (book == null)
            {
                _logger.LogWarning("Книга с ID {BookId} не найдена.", id);
                return NotFound();
            }

            if (!hasSubscription)
            {
                // Без подписки не возвращаем изображения вообще
                return Ok(new { images = new List<string>(), thumbnails = new List<string>() });
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;
            string localPathOfImages = _configuration["TypeOfAccessImages:LocalPathOfImages"];

            List<string> images = new List<string>();
            List<string> thumbnails = new List<string>();

            if (book.IsImagesCompressed)
            {
                _logger.LogInformation("Изображения для книги с ID {BookId} хранятся в сжатом виде.", id);

                if (useLocalFiles)
                {
                    _logger.LogInformation("Используются локальные файлы для изображений.");

                    string archivePath = book.ImageArchiveUrl;

                    if (!System.IO.File.Exists(archivePath))
                    {
                        _logger.LogWarning("Архив изображений для книги с ID {BookId} не найден по пути {ArchivePath}.", id, archivePath);
                        return NotFound();
                    }

                    // Получаем список файлов внутри архива
                    using (var archive = ZipFile.OpenRead(archivePath))
                    {
                        foreach (var entry in archive.Entries)
                        {
                            if (!string.IsNullOrEmpty(entry.Name))
                            {
                                if (entry.FullName.StartsWith("thumbnails/"))
                                {
                                    thumbnails.Add(entry.Name);
                                }
                                else if (entry.FullName.StartsWith("images/"))
                                {
                                    images.Add(entry.Name);
                                }
                            }
                        }
                    }
                }
                else
                {
                    _logger.LogInformation("Используется облачное хранилище для изображений.");

                    // Получаем архив из Yandex Object Storage
                    var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);

                    if (archiveStream == null)
                    {
                        _logger.LogWarning("Архив изображений для книги с ID {BookId} не найден в облачном хранилище.", id);
                        return NotFound();
                    }

                    using (var archive = new ZipArchive(archiveStream, ZipArchiveMode.Read))
                    {
                        foreach (var entry in archive.Entries)
                        {
                            if (!string.IsNullOrEmpty(entry.Name))
                            {
                                if (entry.FullName.StartsWith("thumbnails/"))
                                {
                                    thumbnails.Add(entry.Name);
                                }
                                else if (entry.FullName.StartsWith("images/"))
                                {
                                    images.Add(entry.Name);
                                }
                            }
                        }
                    }
                }
            }
            else
            {
                if (useLocalFiles)
                {
                    _logger.LogInformation("Используются локальные файлы для изображений.");

                    string basePath = Path.Combine(AppContext.BaseDirectory, "books_photos", id.ToString());
                    if (!string.IsNullOrWhiteSpace(localPathOfImages))
                        basePath = Path.Combine(localPathOfImages, id.ToString());

                    var imagesPath = Path.Combine(basePath, "images");
                    var thumbnailsPath = Path.Combine(basePath, "thumbnails");

                    if (!Directory.Exists(imagesPath) && !Directory.Exists(thumbnailsPath))
                    {
                        _logger.LogWarning("Изображения и миниатюры для книги с ID {BookId} не найдены.", id);
                        return NotFound();
                    }

                    images = Directory.Exists(imagesPath)
                        ? Directory.GetFiles(imagesPath).Select(Path.GetFileName).ToList()
                        : new List<string>();

                    thumbnails = Directory.Exists(thumbnailsPath)
                        ? Directory.GetFiles(thumbnailsPath).Select(Path.GetFileName).ToList()
                        : new List<string>();
                }
                else
                {
                    _logger.LogInformation("Используется облачное хранилище для изображений.");

                    images = await _yandexStorageService.GetImageKeysAsync(id);
                    thumbnails = await _yandexStorageService.GetThumbnailKeysAsync(id);
                }
            }            

            if (!hasSubscription)
            {
                _logger.LogInformation("У пользователя нет подписки. Ограничение доступа к изображениям.");
                images = new List<string>();
                thumbnails = thumbnails.Take(1).ToList();
            }

            _logger.LogInformation("Возвращение списка изображений и миниатюр для книги с ID {BookId}", id);
            return Ok(new { images, thumbnails });
        }

        [HttpGet("{id}/images/{imageName}")]
        public async Task<ActionResult> GetImage(int id, string imageName)
        {
            _logger.LogInformation("Запрос получения изображения '{ImageName}' для книги с ID {BookId}", imageName, id);

            var hasSubscription = await UserHasSubscriptionAsync();
            if (!hasSubscription)
            {
                _logger.LogWarning("Доступ запрещен: требуется подписка для просмотра полных изображений.");
                return Forbid("Требуется подписка для просмотра полных изображений.");
            }

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
            {
                _logger.LogWarning("Книга с ID {BookId} не найдена.", id);
                return NotFound();
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            if (book.IsImagesCompressed)
            {
                _logger.LogInformation("Изображения для книги с ID {BookId} хранятся в сжатом виде.", id);

                if (useLocalFiles)
                {
                    _logger.LogInformation("Используются локальные файлы для изображений.");

                    string archivePath = book.ImageArchiveUrl;

                    if (!System.IO.File.Exists(archivePath))
                    {
                        _logger.LogWarning("Архив изображений для книги с ID {BookId} не найден по пути {ArchivePath}.", id, archivePath);
                        return NotFound();
                    }

                    using (var archive = ZipFile.OpenRead(archivePath))
                    {
                        var entry = archive.GetEntry($"images/{imageName}");
                        if (entry == null)
                        {
                            _logger.LogWarning("Изображение '{ImageName}' не найдено в архиве для книги с ID {BookId}.", imageName, id);
                            return NotFound();
                        }

                        using (var entryStream = entry.Open())
                        {
                            var memoryStream = new MemoryStream();
                            await entryStream.CopyToAsync(memoryStream);
                            memoryStream.Position = 0;
                            _logger.LogInformation("Возвращение изображения '{ImageName}' для книги с ID {BookId}", imageName, id);
                            return File(memoryStream, "image/jpeg");
                        }
                    }
                }
                else
                {
                    _logger.LogInformation("Используется облачное хранилище для изображений.");

                    var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);

                    if (archiveStream == null)
                    {
                        _logger.LogWarning("Архив изображений для книги с ID {BookId} не найден в облачном хранилище.", id);
                        return NotFound();
                    }

                    using (var archive = new ZipArchive(archiveStream, ZipArchiveMode.Read))
                    {
                        var entry = archive.GetEntry($"images/{imageName}");
                        if (entry == null)
                        {
                            _logger.LogWarning("Изображение '{ImageName}' не найдено в архиве для книги с ID {BookId}.", imageName, id);
                            return NotFound();
                        }

                        using (var entryStream = entry.Open())
                        {
                            var memoryStream = new MemoryStream();
                            await entryStream.CopyToAsync(memoryStream);
                            memoryStream.Position = 0;
                            _logger.LogInformation("Возвращение изображения '{ImageName}' для книги с ID {BookId}", imageName, id);
                            return File(memoryStream, "image/jpeg");
                        }
                    }
                }
            }
            else
            {
                if (useLocalFiles)
                {
                    string localPathOfImages = _configuration["TypeOfAccessImages:LocalPathOfImages"];
                    _logger.LogInformation("Используются локальные файлы для изображений.");

                    string basePath = Path.Combine(AppContext.BaseDirectory, "books_photos", id.ToString());
                    if (!string.IsNullOrWhiteSpace(localPathOfImages))
                        basePath = Path.Combine(localPathOfImages, id.ToString());

                    var imagePath = Path.Combine(basePath, "images", imageName);

                    if (!System.IO.File.Exists(imagePath))
                    {
                        _logger.LogWarning("Изображение '{ImageName}' для книги с ID {BookId} не найдено.", imageName, id);
                        return NotFound();
                    }

                    var image = System.IO.File.OpenRead(imagePath);
                    _logger.LogInformation("Возвращение изображения '{ImageName}' для книги с ID {BookId}", imageName, id);
                    return File(image, "image/jpeg");
                }
                else
                {
                    _logger.LogInformation("Используется облачное хранилище для изображений.");

                    var key = $"{id}/images/{imageName}";
                    var imageStream = await _yandexStorageService.GetImageStreamAsync(key);
                    if (imageStream == null)
                    {
                        _logger.LogWarning("Изображение '{ImageName}' для книги с ID {BookId} не найдено в облаке.", imageName, id);
                        return NotFound();
                    }

                    _logger.LogInformation("Возвращение изображения '{ImageName}' для книги с ID {BookId}", imageName, id);
                    return File(imageStream, "image/jpeg");
                }
            }            
        }

        [HttpGet("{id}/thumbnails/{thumbnailName}")]
        public async Task<ActionResult> GetThumbnail(int id, string thumbnailName)
        {
            _logger.LogInformation("Запрос получения миниатюры '{ThumbnailName}' для книги с ID {BookId}", thumbnailName, id);

            var book = await _booksRepository.GetBookByIdAsync(id);
            if (book == null)
            {
                _logger.LogWarning("Книга с ID {BookId} не найдена.", id);
                return NotFound();
            }

            bool useLocalFiles = bool.TryParse(_configuration["TypeOfAccessImages:UseLocalFiles"], out var useLocal) && useLocal;

            if (book.IsImagesCompressed)
            {
                _logger.LogInformation("Изображения для книги с ID {BookId} хранятся в сжатом виде.", id);

                if (useLocalFiles)
                {
                    _logger.LogInformation("Используются локальные файлы для миниатюр.");

                    string archivePath = book.ImageArchiveUrl;

                    if (!System.IO.File.Exists(archivePath))
                    {
                        _logger.LogWarning("Архив изображений для книги с ID {BookId} не найден по пути {ArchivePath}.", id, archivePath);
                        return NotFound();
                    }

                    using (var archive = ZipFile.OpenRead(archivePath))
                    {
                        var entry = archive.GetEntry($"thumbnails/{thumbnailName}");
                        if (entry == null)
                        {
                            _logger.LogWarning("Миниатюра '{ThumbnailName}' не найдена в архиве для книги с ID {BookId}.", thumbnailName, id);
                            return NotFound();
                        }

                        using (var entryStream = entry.Open())
                        {
                            var memoryStream = new MemoryStream();
                            await entryStream.CopyToAsync(memoryStream);
                            memoryStream.Position = 0;
                            _logger.LogInformation("Возвращение миниатюры '{ThumbnailName}' для книги с ID {BookId}", thumbnailName, id);
                            return File(memoryStream, "image/jpeg");
                        }
                    }
                }
                else
                {
                    _logger.LogInformation("Используется облачное хранилище для миниатюр.");

                    var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);

                    if (archiveStream == null)
                    {
                        _logger.LogWarning("Архив изображений для книги с ID {BookId} не найден в облачном хранилище.", id);
                        return NotFound();
                    }

                    using (var archive = new ZipArchive(archiveStream, ZipArchiveMode.Read))
                    {
                        var entry = archive.GetEntry($"thumbnails/{thumbnailName}");
                        if (entry == null)
                        {
                            _logger.LogWarning("Миниатюра '{ThumbnailName}' не найдена в архиве для книги с ID {BookId}.", thumbnailName, id);
                            return NotFound();
                        }

                        using (var entryStream = entry.Open())
                        {
                            var memoryStream = new MemoryStream();
                            await entryStream.CopyToAsync(memoryStream);
                            memoryStream.Position = 0;
                            _logger.LogInformation("Возвращение миниатюры '{ThumbnailName}' для книги с ID {BookId}", thumbnailName, id);
                            return File(memoryStream, "image/jpeg");
                        }
                    }
                }
            }
            else
            {
                if (useLocalFiles)
                {
                    string localPathOfImages = _configuration["TypeOfAccessImages:LocalPathOfImages"];
                    _logger.LogInformation("Используются локальные файлы для миниатюр.");

                    var basePath = Path.Combine(AppContext.BaseDirectory, "books_photos", id.ToString());
                    if (!string.IsNullOrWhiteSpace(localPathOfImages))
                        basePath = Path.Combine(localPathOfImages, id.ToString());

                    var thumbnailPath = Path.Combine(basePath, "thumbnails", thumbnailName);

                    if (!System.IO.File.Exists(thumbnailPath))
                    {
                        _logger.LogWarning("Миниатюра '{ThumbnailName}' для книги с ID {BookId} не найдена.", thumbnailName, id);
                        return NotFound();
                    }

                    var thumbnail = System.IO.File.OpenRead(thumbnailPath);
                    _logger.LogInformation("Возвращение миниатюры '{ThumbnailName}' для книги с ID {BookId}", thumbnailName, id);
                    return File(thumbnail, "image/jpeg");
                }
                else
                {
                    _logger.LogInformation("Используется облачное хранилище для миниатюр.");

                    var key = $"{id}/thumbnails/{thumbnailName}";
                    var thumbnailStream = await _yandexStorageService.GetThumbnailStreamAsync(key);
                    if (thumbnailStream == null)
                    {
                        _logger.LogWarning("Миниатюра '{ThumbnailName}' для книги с ID {BookId} не найдена в облаке.", thumbnailName, id);
                        return NotFound();
                    }

                    _logger.LogInformation("Возвращение миниатюры '{ThumbnailName}' для книги с ID {BookId}", thumbnailName, id);
                    return File(thumbnailStream, "image/jpeg");
                }
            }            
        }
    }
}
