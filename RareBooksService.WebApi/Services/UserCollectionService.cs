using Grpc.Core;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public interface IUserCollectionService
    {
        Task<List<UserCollectionBookDto>> GetUserCollectionAsync(string userId);
        Task<UserCollectionBookDetailsDto> GetBookDetailsAsync(int bookId, string userId);
        Task<UserCollectionBookDto> AddBookToCollectionAsync(AddCollectionBookRequest request, string userId);
        Task<UserCollectionBookDto> UpdateBookAsync(int bookId, UpdateCollectionBookRequest request, string userId);
        Task DeleteBookAsync(int bookId, string userId);
        Task<UserCollectionBookImageDto> UploadBookImageAsync(int bookId, IFormFile file, string userId);
        Task DeleteBookImageAsync(int bookId, int imageId, string userId);
        Task SetMainImageAsync(int bookId, int imageId, string userId);
        Task<CollectionStatisticsDto> GetStatisticsAsync(string userId);
    }

    public class UserCollectionService : IUserCollectionService
    {
        private readonly UsersDbContext _usersContext;
        private readonly BooksDbContext _booksContext;
        private readonly ICollectionImageService _imageService;
        private readonly ICollectionMatchingService _matchingService;
        private readonly ILogger<UserCollectionService> _logger;
        private readonly UserManager<ApplicationUser> _userManager;

        public UserCollectionService(
            UsersDbContext usersContext,
            BooksDbContext booksContext,
            ICollectionImageService imageService,
            ICollectionMatchingService matchingService,
            ILogger<UserCollectionService> logger,
            UserManager<ApplicationUser> userManager)
        {
            _usersContext = usersContext;
            _booksContext = booksContext;
            _imageService = imageService;
            _matchingService = matchingService;
            _logger = logger;
            _userManager = userManager;
        }

        public async Task<List<UserCollectionBookDto>> GetUserCollectionAsync(string userId)
        {
            try
            {
                var books = await _usersContext.UserCollectionBooks
                    .Include(b => b.Images)
                    .Where(b => b.UserId == userId)
                    .OrderByDescending(b => b.AddedDate)
                    .ToListAsync();

                return books.Select(MapToDto).ToList();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении коллекции пользователя {UserId}", userId);
                throw;
            }
        }

        public async Task<UserCollectionBookDetailsDto> GetBookDetailsAsync(int bookId, string userId)
        {
            try
            {
                var book = await _usersContext.UserCollectionBooks
                    .Include(b => b.Images)
                    .Include(b => b.SuggestedMatches)
                    .FirstOrDefaultAsync(b => b.Id == bookId && b.UserId == userId);

                if (book == null)
                {
                    throw new InvalidOperationException($"Книга {bookId} не найдена");
                }

                var detailsDto = new UserCollectionBookDetailsDto
                {
                    Id = book.Id,
                    Title = book.Title,
                    Author = book.Author,
                    YearPublished = book.YearPublished,
                    Description = book.Description,
                    Notes = book.Notes,
                    EstimatedPrice = book.EstimatedPrice,
                    PurchasePrice = book.PurchasePrice,
                    PurchaseDate = book.PurchaseDate,
                    IsSold = book.IsSold,
                    SoldPrice = book.SoldPrice,
                    SoldDate = book.SoldDate,
                    IsManuallyPriced = book.IsManuallyPriced,
                    ReferenceBookId = book.ReferenceBookId,
                    AddedDate = book.AddedDate,
                    UpdatedDate = book.UpdatedDate,
                    Images = book.Images.Select(img => new UserCollectionBookImageDto
                    {
                        Id = img.Id,
                        UserCollectionBookId = img.UserCollectionBookId,
                        FileName = img.FileName,
                        ImageUrl = _imageService.GetImageUrl(userId, bookId, img.FileName),
                        UploadedDate = img.UploadedDate,
                        IsMainImage = img.IsMainImage
                    }).ToList(),
                    SuggestedMatches = new List<BookMatchDto>()
                };

                // Загружаем детали найденных аналогов
                if (book.SuggestedMatches.Any())
                {
                    var matchedBookIds = book.SuggestedMatches.Select(m => m.MatchedBookId).ToList();
                    var matchedBooks = await _booksContext.BooksInfo
                        .Include(b => b.Category)
                        .Where(b => matchedBookIds.Contains(b.Id))
                        .ToDictionaryAsync(b => b.Id);

                    detailsDto.SuggestedMatches = book.SuggestedMatches
                        .Where(m => matchedBooks.ContainsKey(m.MatchedBookId))
                        .Select(m => new BookMatchDto
                        {
                            Id = m.Id,
                            MatchedBookId = m.MatchedBookId,
                            MatchScore = m.MatchScore,
                            FoundDate = m.FoundDate,
                            IsSelected = m.IsSelected,
                            MatchedBook = MapToSearchResultDto(matchedBooks[m.MatchedBookId])
                        })
                        .OrderByDescending(m => m.MatchScore)
                        .ToList();
                }

                // Загружаем детали референсной книги, если есть
                if (book.ReferenceBookId.HasValue)
                {
                    var refBook = await _booksContext.BooksInfo
                        .Include(b => b.Category)
                        .FirstOrDefaultAsync(b => b.Id == book.ReferenceBookId.Value);

                    if (refBook != null)
                    {
                        detailsDto.ReferenceBook = MapToDetailDto(refBook);
                    }
                }

                return detailsDto;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении деталей книги {BookId}", bookId);
                throw;
            }
        }

        public async Task<UserCollectionBookDto> AddBookToCollectionAsync(AddCollectionBookRequest request, string userId)
        {
            try
            {
                var book = new UserCollectionBook
                {
                    UserId = userId,
                    Title = request.Title,
                    Author = request.Author,
                    YearPublished = request.YearPublished,
                    Description = request.Description,
                    Notes = request.Notes,
                    PurchasePrice = request.PurchasePrice,
                    PurchaseDate = request.PurchaseDate,
                    AddedDate = DateTime.UtcNow,
                    UpdatedDate = DateTime.UtcNow
                };

                _usersContext.UserCollectionBooks.Add(book);
                await _usersContext.SaveChangesAsync();

                _logger.LogInformation("Добавлена книга '{Title}' в коллекцию пользователя {UserId}", 
                    request.Title, userId);

                // Автоматически ищем аналоги
                try
                {
                    var user = await _userManager.FindByIdAsync(userId);
                    if (user != null)
                    {
                        var matches = await _matchingService.FindMatchesAsync(book, user);
                    
                    foreach (var match in matches)
                    {
                        var bookMatch = new UserCollectionBookMatch
                        {
                            UserCollectionBookId = book.Id,
                            MatchedBookId = match.MatchedBookId,
                            MatchScore = match.MatchScore,
                            FoundDate = DateTime.UtcNow,
                            IsSelected = false
                        };
                        _usersContext.UserCollectionBookMatches.Add(bookMatch);
                    }

                        await _usersContext.SaveChangesAsync();
                        
                        _logger.LogInformation("Найдено {Count} аналогов для книги {BookId}", matches.Count, book.Id);
                    }
                    else
                    {
                        _logger.LogWarning("Пользователь {UserId} не найден при поиске аналогов", userId);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Не удалось найти аналоги для книги {BookId}", book.Id);
                    // Не прерываем выполнение, если поиск аналогов не удался
                }

                return MapToDto(book);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при добавлении книги в коллекцию пользователя {UserId}", userId);
                throw;
            }
        }

        public async Task<UserCollectionBookDto> UpdateBookAsync(int bookId, UpdateCollectionBookRequest request, string userId)
        {
            try
            {
                var book = await _usersContext.UserCollectionBooks
                    .Include(b => b.Images)
                    .FirstOrDefaultAsync(b => b.Id == bookId && b.UserId == userId);

                if (book == null)
                {
                    throw new InvalidOperationException($"Книга {bookId} не найдена");
                }

                book.Title = request.Title;
                book.Author = request.Author;
                book.YearPublished = request.YearPublished;
                book.Description = request.Description;
                book.Notes = request.Notes;
                book.PurchasePrice = request.PurchasePrice;
                book.PurchaseDate = request.PurchaseDate;
                book.IsSold = request.IsSold;
                book.SoldPrice = request.SoldPrice;
                book.SoldDate = request.SoldDate;
                book.UpdatedDate = DateTime.UtcNow;

                // Обновляем цену, если она установлена вручную
                if (request.IsManuallyPriced)
                {
                    book.EstimatedPrice = request.EstimatedPrice;
                    book.IsManuallyPriced = true;
                }

                await _usersContext.SaveChangesAsync();

                _logger.LogInformation("Обновлена книга {BookId} в коллекции пользователя {UserId}", bookId, userId);

                return MapToDto(book);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обновлении книги {BookId}", bookId);                
                throw;
            }
        }

        public async Task DeleteBookAsync(int bookId, string userId)
        {
            try
            {
                var book = await _usersContext.UserCollectionBooks
                    .FirstOrDefaultAsync(b => b.Id == bookId && b.UserId == userId);

                if (book == null)
                {
                    throw new InvalidOperationException($"Книга {bookId} не найдена");
                }

                // Удаляем все изображения
                await _imageService.DeleteAllBookImagesAsync(userId, bookId);

                // Удаляем книгу (каскадно удалятся связанные записи)
                _usersContext.UserCollectionBooks.Remove(book);
                await _usersContext.SaveChangesAsync();

                _logger.LogInformation("Удалена книга {BookId} из коллекции пользователя {UserId}", bookId, userId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении книги {BookId}", bookId);
                throw;
            }
        }

        public async Task<UserCollectionBookImageDto> UploadBookImageAsync(int bookId, IFormFile file, string userId)
        {
            try
            {
                var book = await _usersContext.UserCollectionBooks
                    .Include(b => b.Images)
                    .FirstOrDefaultAsync(b => b.Id == bookId && b.UserId == userId);

                if (book == null)
                {
                    throw new InvalidOperationException($"Книга {bookId} не найдена");
                }

                // Сохраняем файл
                var imageDto = await _imageService.SaveImageAsync(userId, bookId, file);

                // Создаем запись в БД
                var image = new UserCollectionBookImage
                {
                    UserCollectionBookId = bookId,
                    FileName = imageDto.FileName,
                    FilePath = await _imageService.GetImagePathAsync(userId, bookId, imageDto.FileName),
                    UploadedDate = imageDto.UploadedDate,
                    IsMainImage = !book.Images.Any() // Первое изображение делаем главным
                };

                _usersContext.UserCollectionBookImages.Add(image);
                book.UpdatedDate = DateTime.UtcNow;
                await _usersContext.SaveChangesAsync();

                imageDto.Id = image.Id;
                imageDto.IsMainImage = image.IsMainImage;

                _logger.LogInformation("Загружено изображение {FileName} для книги {BookId}", 
                    imageDto.FileName, bookId);

                return imageDto;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при загрузке изображения для книги {BookId}", bookId);
                throw;
            }
        }

        public async Task DeleteBookImageAsync(int bookId, int imageId, string userId)
        {
            try
            {
                var image = await _usersContext.UserCollectionBookImages
                    .Include(i => i.UserCollectionBook)
                    .FirstOrDefaultAsync(i => i.Id == imageId && 
                                            i.UserCollectionBookId == bookId &&
                                            i.UserCollectionBook.UserId == userId);

                if (image == null)
                {
                    throw new InvalidOperationException($"Изображение {imageId} не найдено");
                }

                var wasMainImage = image.IsMainImage;

                // Удаляем файл
                await _imageService.DeleteImageAsync(userId, bookId, image.FileName);

                // Удаляем запись из БД
                _usersContext.UserCollectionBookImages.Remove(image);

                // Если это было главное изображение, назначаем другое
                if (wasMainImage)
                {
                    var nextImage = await _usersContext.UserCollectionBookImages
                        .Where(i => i.UserCollectionBookId == bookId && i.Id != imageId)
                        .FirstOrDefaultAsync();

                    if (nextImage != null)
                    {
                        nextImage.IsMainImage = true;
                    }
                }

                image.UserCollectionBook.UpdatedDate = DateTime.UtcNow;
                await _usersContext.SaveChangesAsync();

                _logger.LogInformation("Удалено изображение {ImageId} для книги {BookId}", imageId, bookId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении изображения {ImageId}", imageId);
                throw;
            }
        }

        public async Task SetMainImageAsync(int bookId, int imageId, string userId)
        {
            try
            {
                var images = await _usersContext.UserCollectionBookImages
                    .Include(i => i.UserCollectionBook)
                    .Where(i => i.UserCollectionBookId == bookId && 
                              i.UserCollectionBook.UserId == userId)
                    .ToListAsync();

                var targetImage = images.FirstOrDefault(i => i.Id == imageId);
                if (targetImage == null)
                {
                    throw new InvalidOperationException($"Изображение {imageId} не найдено");
                }

                // Сбрасываем флаг у всех изображений
                foreach (var img in images)
                {
                    img.IsMainImage = false;
                }

                // Устанавливаем новое главное
                targetImage.IsMainImage = true;
                targetImage.UserCollectionBook.UpdatedDate = DateTime.UtcNow;

                await _usersContext.SaveChangesAsync();

                _logger.LogInformation("Установлено главное изображение {ImageId} для книги {BookId}", 
                    imageId, bookId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при установке главного изображения {ImageId}", imageId);
                throw;
            }
        }

        public async Task<CollectionStatisticsDto> GetStatisticsAsync(string userId)
        {
            try
            {
                var books = await _usersContext.UserCollectionBooks
                    .Include(b => b.Images)
                    .Where(b => b.UserId == userId)
                    .ToListAsync();

                var booksNotSold = books.Where(b => !b.IsSold).ToList();
                var booksSold = books.Where(b => b.IsSold).ToList();

                var totalEstimatedValue = booksNotSold.Where(b => b.EstimatedPrice.HasValue)
                                            .Sum(b => b.EstimatedPrice.Value);
                var totalPurchaseValue = books.Where(b => b.PurchasePrice.HasValue)
                                          .Sum(b => b.PurchasePrice.Value);
                var totalSoldValue = booksSold.Where(b => b.SoldPrice.HasValue)
                                          .Sum(b => b.SoldPrice.Value);
                var purchaseOfSoldBooks = booksSold.Where(b => b.PurchasePrice.HasValue)
                                                    .Sum(b => b.PurchasePrice.Value);
                var totalProfit = totalSoldValue - purchaseOfSoldBooks;
                var valueDifference = totalEstimatedValue - totalPurchaseValue;
                var percentageChange = totalPurchaseValue > 0 
                    ? (valueDifference / totalPurchaseValue) * 100 
                    : 0;

                var stats = new CollectionStatisticsDto
                {
                    TotalBooks = books.Count,
                    BooksSold = booksSold.Count,
                    BooksInCollection = booksNotSold.Count,
                    TotalEstimatedValue = totalEstimatedValue,
                    TotalPurchaseValue = totalPurchaseValue,
                    TotalSoldValue = totalSoldValue,
                    TotalProfit = totalProfit,
                    ValueDifference = valueDifference,
                    PercentageChange = percentageChange,
                    BooksWithEstimate = booksNotSold.Count(b => b.EstimatedPrice.HasValue),
                    BooksWithoutEstimate = booksNotSold.Count(b => !b.EstimatedPrice.HasValue),
                    BooksWithPurchaseInfo = books.Count(b => b.PurchasePrice.HasValue),
                    BooksWithReferenceBook = books.Count(b => b.ReferenceBookId.HasValue),
                    TotalImages = books.Sum(b => b.Images.Count)
                };

                return stats;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении статистики для пользователя {UserId}", userId);
                throw;
            }
        }

        private UserCollectionBookDto MapToDto(UserCollectionBook book)
        {
            var mainImage = book.Images.FirstOrDefault(i => i.IsMainImage);
            
            return new UserCollectionBookDto
            {
                Id = book.Id,
                Title = book.Title,
                Author = book.Author,
                YearPublished = book.YearPublished,
                EstimatedPrice = book.EstimatedPrice,
                PurchasePrice = book.PurchasePrice,
                PurchaseDate = book.PurchaseDate,
                IsSold = book.IsSold,
                SoldPrice = book.SoldPrice,
                SoldDate = book.SoldDate,
                IsManuallyPriced = book.IsManuallyPriced,
                AddedDate = book.AddedDate,
                UpdatedDate = book.UpdatedDate,
                MainImageUrl = mainImage != null 
                    ? _imageService.GetImageUrl(book.UserId, book.Id, mainImage.FileName)
                    : null,
                ImagesCount = book.Images.Count,
                HasReferenceBook = book.ReferenceBookId.HasValue
            };
        }

        private BookSearchResultDto MapToSearchResultDto(RegularBaseBook book)
        {
            return new BookSearchResultDto
            {
                Id = book.Id,
                Title = book.Title,
                Description = book.Description,
                Date = book.EndDate.ToString("yyyy-MM-dd"),
                Price = book.Price,
                Category = book.Category?.Name,
                Type = book.Type,
                SellerName = book.SellerName,
                FirstImageName = book.ThumbnailUrls?.FirstOrDefault()
            };
        }

        private BookDetailDto MapToDetailDto(RegularBaseBook book)
        {
            return new BookDetailDto
            {
                Id = book.Id,
                Title = book.Title,
                Description = book.Description,
                EndDate = book.EndDate.ToString("yyyy-MM-dd"),
                Price = book.Price,
                FinalPrice = book.FinalPrice,
                City = book.City,
                YearPublished = book.YearPublished,
                CategoryName = book.Category?.Name,
                ImageUrls = book.ImageUrls,
                ThumbnailUrls = book.ThumbnailUrls,
                Status = book.Status,
                Type = book.Type,
                SellerName = book.SellerName,
                IsImagesCompressed = book.IsImagesCompressed,
                ImageArchiveUrl = book.ImageArchiveUrl,
                NormalizedTitle = book.NormalizedTitle
            };
        }
    }
}

