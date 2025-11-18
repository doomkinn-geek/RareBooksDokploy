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

namespace RareBooksService.WebApi.Services
{
    public interface ICollectionMatchingService
    {
        Task<List<BookMatchDto>> FindMatchesAsync(UserCollectionBook book, int maxResults = 10);
        Task<UserCollectionBook> SelectReferenceBookAsync(int bookId, int referenceBookId, string userId);
        Task<UserCollectionBook> UpdateEstimatedPriceAsync(int bookId, string userId);
    }

    public class CollectionMatchingService : ICollectionMatchingService
    {
        private readonly BooksDbContext _booksContext;
        private readonly UsersDbContext _usersContext;
        private readonly ILogger<CollectionMatchingService> _logger;
        private readonly Dictionary<string, IStemmer> _stemmers;
        private static readonly LanguageDetector _languageDetector;

        static CollectionMatchingService()
        {
            _languageDetector = new LanguageDetector();
            _languageDetector.AddAllLanguages();
        }

        public CollectionMatchingService(
            BooksDbContext booksContext,
            UsersDbContext usersContext,
            ILogger<CollectionMatchingService> logger)
        {
            _booksContext = booksContext;
            _usersContext = usersContext;
            _logger = logger;

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

        public async Task<List<BookMatchDto>> FindMatchesAsync(UserCollectionBook book, int maxResults = 10)
        {
            try
            {
                _logger.LogInformation("Поиск аналогов для книги '{Title}' (ID: {BookId})", book.Title, book.Id);

                // Нормализуем название книги
                var processedTitle = PreprocessText(book.Title, out var detectedLanguage);
                var searchWords = processedTitle.Split(' ', StringSplitOptions.RemoveEmptyEntries);

                // Базовый запрос для поиска книг
                IQueryable<RegularBaseBook> query = _booksContext.BooksInfo.AsQueryable();

                // Ищем по всем словам из названия
                foreach (var word in searchWords)
                {
                    query = query.Where(b => b.NormalizedTitle.Contains(word));
                }

                // Дополнительная фильтрация по автору, если указан
                if (!string.IsNullOrWhiteSpace(book.Author))
                {
                    var processedAuthor = PreprocessText(book.Author, out _);
                    var authorWords = processedAuthor.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                    
                    foreach (var word in authorWords)
                    {
                        query = query.Where(b => b.NormalizedTitle.Contains(word) || 
                                               b.NormalizedDescription.Contains(word));
                    }
                }

                // Фильтрация по году, если указан (±5 лет)
                if (book.YearPublished.HasValue)
                {
                    var yearMin = book.YearPublished.Value - 5;
                    var yearMax = book.YearPublished.Value + 5;
                    query = query.Where(b => b.YearPublished >= yearMin && b.YearPublished <= yearMax);
                }

                // Получаем топ результатов, отсортированных по дате (самые свежие первыми)
                var matches = await query
                    .OrderByDescending(b => b.EndDate)
                    .Take(maxResults * 2) // Берем больше для расчета score
                    .ToListAsync();

                _logger.LogInformation("Найдено {Count} потенциальных аналогов для книги '{Title}'", 
                    matches.Count, book.Title);

                // Вычисляем score для каждого результата
                var scoredMatches = matches
                    .Select(m => new
                    {
                        Book = m,
                        Score = CalculateMatchScore(book, m, searchWords)
                    })
                    .Where(m => m.Score > 0.3) // Порог минимального совпадения
                    .OrderByDescending(m => m.Score)
                    .Take(maxResults)
                    .ToList();

                // Преобразуем в DTO
                var result = scoredMatches.Select(m => new BookMatchDto
                {
                    MatchedBookId = m.Book.Id,
                    MatchScore = m.Score,
                    FoundDate = DateTime.UtcNow,
                    IsSelected = false,
                    MatchedBook = MapToSearchResultDto(m.Book)
                }).ToList();

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

                // Помечаем соответствующий match как выбранный
                var selectedMatch = book.SuggestedMatches.FirstOrDefault(m => m.MatchedBookId == referenceBookId);
                if (selectedMatch != null)
                {
                    selectedMatch.IsSelected = true;
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

