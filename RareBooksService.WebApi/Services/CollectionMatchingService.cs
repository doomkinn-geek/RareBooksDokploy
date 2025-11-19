using Iveonik.Stemmers;
using LanguageDetection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Linq.Expressions;

namespace RareBooksService.WebApi.Services
{
    public interface ICollectionMatchingService
    {
        Task<List<BookMatchDto>> FindMatchesAsync(UserCollectionBook book, ApplicationUser user, int maxResults = 50);
        Task<UserCollectionBook> SelectReferenceBookAsync(int bookId, int referenceBookId, string userId);
        Task<UserCollectionBook> UpdateEstimatedPriceAsync(int bookId, string userId);
    }

    public class CollectionMatchingService : ICollectionMatchingService
    {
        private readonly BooksDbContext _booksContext;
        private readonly UsersDbContext _usersContext;
        private readonly ILogger<CollectionMatchingService> _logger;
        private readonly Dictionary<string, IStemmer> _stemmers;
        private readonly IBooksService _booksService;
        private static readonly LanguageDetector _languageDetector;

        static CollectionMatchingService()
        {
            _languageDetector = new LanguageDetector();
            _languageDetector.AddAllLanguages();
        }

        public CollectionMatchingService(
            BooksDbContext booksContext,
            UsersDbContext usersContext,
            ILogger<CollectionMatchingService> logger,
            IBooksService booksService)
        {
            _booksContext = booksContext;
            _usersContext = usersContext;
            _logger = logger;
            _booksService = booksService;

            _stemmers = new Dictionary<string, IStemmer>
            {
                { "rus", new RussianStemmer() },
                { "eng", new EnglishStemmer() },
                { "fra", new FrenchStemmer() },
                { "deu", new GermanStemmer() },
                { "ita", new ItalianStemmer() },
                { "fin", new FinnishStemmer() }
            };
        }

        public async Task<List<BookMatchDto>> FindMatchesAsync(UserCollectionBook book, ApplicationUser user, int maxResults = 50)
        {
            try
            {
                _logger.LogInformation("Поиск аналогов для книги '{Title}' (ID: {BookId}) через BooksService", book.Title, book.Id);

                // Используем готовый сервис поиска по заголовку - он уже отлично работает!
                var searchResult = await _booksService.SearchByTitleAsync(
                    user, 
                    book.Title, 
                    exactPhrase: false, 
                    page: 1, 
                    pageSize: maxResults);

                _logger.LogInformation("BooksService нашел {Count} аналогов для книги '{Title}'", 
                    searchResult.Items?.Count ?? 0, book.Title);

                if (searchResult.Items == null || searchResult.Items.Count == 0)
                {
                    _logger.LogWarning("Аналогов не найдено через BooksService");
                    return new List<BookMatchDto>();
                }

                // Используем результаты поиска напрямую, без дополнительной фильтрации
                // Score вычисляется на основе позиции в результатах (чем выше, тем лучше)
                var result = searchResult.Items
                    .Select((item, index) => new BookMatchDto
                    {
                        MatchedBookId = item.Id,
                        // Score уменьшается от 1.0 до 0.5 в зависимости от позиции в результатах
                        MatchScore = 1.0 - (index * 0.5 / Math.Max(searchResult.Items.Count, 1)),
                        FoundDate = DateTime.UtcNow,
                        IsSelected = false,
                        MatchedBook = item
                    })
                    .ToList();

                _logger.LogInformation("Возвращаем {Count} аналогов (от score {MaxScore:F2} до {MinScore:F2})", 
                    result.Count,
                    result.FirstOrDefault()?.MatchScore ?? 0,
                    result.LastOrDefault()?.MatchScore ?? 0);

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при поиске аналогов для книги {BookId}", book.Id);
                throw;
            }
        }

        public async Task<UserCollectionBook> SelectReferenceBookAsync(int bookId, int referenceBookId, string userId)
        {
            try
            {
                var book = await _usersContext.UserCollectionBooks
                    .Include(b => b.SuggestedMatches)
                    .FirstOrDefaultAsync(b => b.Id == bookId && b.UserId == userId);

                if (book == null)
                {
                    throw new InvalidOperationException($"Книга {bookId} не найдена");
                }

                // Проверяем, что referenceBook существует
                var referenceBook = await _booksContext.BooksInfo
                    .FirstOrDefaultAsync(b => b.Id == referenceBookId);

                if (referenceBook == null)
                {
                    throw new InvalidOperationException($"Референсная книга {referenceBookId} не найдена");
                }

                // Сбрасываем предыдущий выбор
                foreach (var match in book.SuggestedMatches)
                {
                    match.IsSelected = false;
                }

                // Устанавливаем новый референс
                book.ReferenceBookId = referenceBookId;
                book.UpdatedDate = DateTime.UtcNow;

                // Помечаем соответствующий match как выбранный, если он существует в базе
                var selectedMatch = book.SuggestedMatches.FirstOrDefault(m => m.MatchedBookId == referenceBookId);
                if (selectedMatch != null)
                {
                    selectedMatch.IsSelected = true;
                }
                else
                {
                    // Если match не существует (например, при ручном поиске), создаем его
                    _logger.LogInformation("Создаем новый match для референса {ReferenceBookId}", referenceBookId);
                    var newMatch = new UserCollectionBookMatch
                    {
                        UserCollectionBookId = bookId,
                        MatchedBookId = referenceBookId,
                        MatchScore = 1.0, // Пользователь выбрал вручную
                        FoundDate = DateTime.UtcNow,
                        IsSelected = true
                    };
                    _usersContext.UserCollectionBookMatches.Add(newMatch);
                }

                await _usersContext.SaveChangesAsync();

                // Автоматически обновляем оценку на основе выбранного референса
                await UpdateEstimatedPriceAsync(bookId, userId);

                _logger.LogInformation("Установлен референс {ReferenceBookId} для книги {BookId}", 
                    referenceBookId, bookId);

                return book;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при выборе референсной книги {ReferenceBookId} для книги {BookId}", 
                    referenceBookId, bookId);
                throw;
            }
        }

        public async Task<UserCollectionBook> UpdateEstimatedPriceAsync(int bookId, string userId)
        {
            try
            {
                var book = await _usersContext.UserCollectionBooks
                    .FirstOrDefaultAsync(b => b.Id == bookId && b.UserId == userId);

                if (book == null)
                {
                    throw new InvalidOperationException($"Книга {bookId} не найдена");
                }

                if (!book.ReferenceBookId.HasValue)
                {
                    _logger.LogWarning("Нельзя обновить оценку для книги {BookId}: референс не выбран", bookId);
                    return book;
                }

                // Получаем самый свежий лот референсной книги
                var referenceBook = await _booksContext.BooksInfo
                    .Where(b => b.Id == book.ReferenceBookId.Value)
                    .OrderByDescending(b => b.EndDate)
                    .FirstOrDefaultAsync();

                if (referenceBook != null && referenceBook.FinalPrice.HasValue)
                {
                    book.EstimatedPrice = (decimal)referenceBook.FinalPrice.Value;
                    book.IsManuallyPriced = false;
                    book.UpdatedDate = DateTime.UtcNow;

                    await _usersContext.SaveChangesAsync();

                    _logger.LogInformation("Обновлена оценка для книги {BookId}: {Price} руб. на основе референса {ReferenceBookId}", 
                        bookId, book.EstimatedPrice, book.ReferenceBookId);
                }

                return book;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обновлении оценки для книги {BookId}", bookId);
                throw;
            }
        }

        private double CalculateMatchScore(UserCollectionBook userBook, RegularBaseBook dbBook, string[] searchWords)
        {
            double score = 0.0;

            // 1. Совпадение по названию (вес 60%)
            var titleMatchCount = searchWords.Count(word => 
                dbBook.NormalizedTitle?.Contains(word) == true);
            var titleScore = searchWords.Length > 0 
                ? (double)titleMatchCount / searchWords.Length 
                : 0;
            score += titleScore * 0.6;

            // 2. Совпадение по автору (вес 20%)
            if (!string.IsNullOrWhiteSpace(userBook.Author))
            {
                var processedAuthor = PreprocessText(userBook.Author, out _);
                var authorWords = processedAuthor.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                var authorMatchCount = authorWords.Count(word =>
                    dbBook.NormalizedTitle?.Contains(word) == true ||
                    dbBook.NormalizedDescription?.Contains(word) == true);
                var authorScore = authorWords.Length > 0
                    ? (double)authorMatchCount / authorWords.Length
                    : 0;
                score += authorScore * 0.2;
            }
            else
            {
                score += 0.1; // Бонус если автор не указан
            }

            // 3. Совпадение по году (вес 20%)
            if (userBook.YearPublished.HasValue && dbBook.YearPublished.HasValue)
            {
                var yearDiff = Math.Abs(userBook.YearPublished.Value - dbBook.YearPublished.Value);
                var yearScore = yearDiff <= 2 ? 1.0 : (yearDiff <= 5 ? 0.5 : 0.0);
                score += yearScore * 0.2;
            }
            else
            {
                score += 0.1; // Бонус если год не указан
            }

            return Math.Min(score, 1.0);
        }

        private string PreprocessText(string text, out string detectedLanguage)
        {
            detectedLanguage = DetectLanguage(text);
            if (detectedLanguage == "bul" || detectedLanguage == "ukr" || detectedLanguage == "mkd")
                detectedLanguage = "rus";

            if (!_stemmers.ContainsKey(detectedLanguage))
            {
                detectedLanguage = "rus"; // Fallback на русский
            }

            var stemmer = _stemmers[detectedLanguage];
            var normalizedText = Regex.Replace(text.ToLowerInvariant(), @"\p{P}", " ");
            var words = normalizedText.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                                      .Select(word => stemmer.Stem(word));
            return string.Join(" ", words);
        }

        private string DetectLanguage(string text)
        {
            try
            {
                return _languageDetector.Detect(text);
            }
            catch
            {
                return "rus"; // Fallback на русский при ошибке
            }
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
    }
}

