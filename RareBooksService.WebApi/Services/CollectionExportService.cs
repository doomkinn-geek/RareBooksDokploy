using iText.IO.Font;
using iText.IO.Image;
using iText.Kernel.Font;
using iText.Kernel.Pdf;
using iText.Layout;
using iText.Layout.Element;
using iText.Layout.Properties;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data;
using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public interface ICollectionExportService
    {
        Task<byte[]> ExportToPdfAsync(string userId);
        Task<byte[]> ExportToJsonAsync(string userId);
        Task<ImportCollectionResponse> ImportFromJsonAsync(ImportCollectionRequest request, string userId);
    }

    public class CollectionExportService : ICollectionExportService
    {
        private readonly UsersDbContext _usersContext;
        private readonly BooksDbContext _booksContext;
        private readonly ICollectionImageService _imageService;
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<CollectionExportService> _logger;

        public CollectionExportService(
            UsersDbContext usersContext,
            BooksDbContext booksContext,
            ICollectionImageService imageService,
            IWebHostEnvironment environment,
            ILogger<CollectionExportService> logger)
        {
            _usersContext = usersContext;
            _booksContext = booksContext;
            _imageService = imageService;
            _environment = environment;
            _logger = logger;
        }

        public async Task<byte[]> ExportToPdfAsync(string userId)
        {
            try
            {
                _logger.LogInformation("Начало экспорта коллекции в PDF для пользователя {UserId}", userId);

                var books = await _usersContext.UserCollectionBooks
                    .Include(b => b.Images)
                    .Where(b => b.UserId == userId)
                    .OrderBy(b => b.Title)
                    .ToListAsync();

                if (!books.Any())
                {
                    throw new InvalidOperationException("Коллекция пуста");
                }

                // Получаем референсные книги
                var referenceBookIds = books
                    .Where(b => b.ReferenceBookId.HasValue)
                    .Select(b => b.ReferenceBookId.Value)
                    .ToList();

                var referenceBooks = await _booksContext.BooksInfo
                    .Where(b => referenceBookIds.Contains(b.Id))
                    .ToDictionaryAsync(b => b.Id);

                using (var stream = new MemoryStream())
                {
                    var writer = new PdfWriter(stream);
                    var pdf = new PdfDocument(writer);
                    var document = new Document(pdf);

                    // Загружаем шрифт для поддержки кириллицы
                    var fontPath = Path.Combine(_environment.ContentRootPath, "ARIALBD.TTF");
                    PdfFont font = null;
                    
                    if (File.Exists(fontPath))
                    {
                        font = PdfFontFactory.CreateFont(fontPath, PdfEncodings.IDENTITY_H);
                        document.SetFont(font);
                    }

                    // Титульная страница
                    var title = new Paragraph("Моя коллекция редких книг")
                        .SetFontSize(24)
                        .SetBold()
                        .SetTextAlignment(TextAlignment.CENTER);
                    document.Add(title);

                    var exportDate = new Paragraph($"Дата экспорта: {DateTime.Now:dd.MM.yyyy}")
                        .SetFontSize(12)
                        .SetTextAlignment(TextAlignment.CENTER);
                    document.Add(exportDate);

                    document.Add(new Paragraph("\n"));

                    // Статистика
                    var totalEstimatedValue = books.Where(b => b.EstimatedPrice.HasValue)
                                         .Sum(b => b.EstimatedPrice.Value);
                    var totalPurchaseValue = books.Where(b => b.PurchasePrice.HasValue)
                                         .Sum(b => b.PurchasePrice.Value);
                    var valueDifference = totalEstimatedValue - totalPurchaseValue;
                    var percentageChange = totalPurchaseValue > 0 
                        ? (valueDifference / totalPurchaseValue) * 100 
                        : 0;
                    
                    var statsTable = new Table(2).UseAllAvailableWidth();
                    statsTable.AddCell(new Cell().Add(new Paragraph("Всего книг:").SetBold()));
                    statsTable.AddCell(new Cell().Add(new Paragraph(books.Count.ToString())));
                    statsTable.AddCell(new Cell().Add(new Paragraph("Книг с оценкой:").SetBold()));
                    statsTable.AddCell(new Cell().Add(new Paragraph(books.Count(b => b.EstimatedPrice.HasValue).ToString())));
                    statsTable.AddCell(new Cell().Add(new Paragraph("Книг с данными о покупке:").SetBold()));
                    statsTable.AddCell(new Cell().Add(new Paragraph(books.Count(b => b.PurchasePrice.HasValue).ToString())));
                    statsTable.AddCell(new Cell().Add(new Paragraph("Общая оценочная стоимость:").SetBold()));
                    statsTable.AddCell(new Cell().Add(new Paragraph($"{totalEstimatedValue:N0} руб.")));
                    statsTable.AddCell(new Cell().Add(new Paragraph("Общая стоимость покупки:").SetBold()));
                    statsTable.AddCell(new Cell().Add(new Paragraph($"{totalPurchaseValue:N0} руб.")));
                    statsTable.AddCell(new Cell().Add(new Paragraph("Изменение стоимости:").SetBold()));
                    statsTable.AddCell(new Cell().Add(new Paragraph($"{valueDifference:N0} руб. ({percentageChange:F2}%)")));

                    document.Add(statsTable);
                    document.Add(new Paragraph("\n\n"));

                    // Список книг
                    foreach (var book in books)
                    {
                        var bookTable = new Table(2).UseAllAvailableWidth();
                        bookTable.SetMarginBottom(20);

                        // Левая колонка - изображение
                        var mainImage = book.Images.FirstOrDefault(i => i.IsMainImage) ?? book.Images.FirstOrDefault();
                        if (mainImage != null)
                        {
                            try
                            {
                                var imagePath = await _imageService.GetImagePathAsync(userId, book.Id, mainImage.FileName);
                                if (File.Exists(imagePath))
                                {
                                    var thumbnailPath = Path.Combine(Path.GetDirectoryName(imagePath), $"thumb_{mainImage.FileName}");
                                    var imgPath = File.Exists(thumbnailPath) ? thumbnailPath : imagePath;
                                    
                                    var imageData = ImageDataFactory.Create(imgPath);
                                    // Используем только ширину, чтобы сохранить пропорции изображения
                                    // Высота будет вычислена автоматически на основе исходных пропорций
                                    var img = new Image(imageData).SetWidth(150);
                                    bookTable.AddCell(new Cell().Add(img).SetVerticalAlignment(VerticalAlignment.TOP));
                                }
                                else
                                {
                                    bookTable.AddCell(new Cell().Add(new Paragraph("Нет изображения")));
                                }
                            }
                            catch (Exception ex)
                            {
                                _logger.LogWarning(ex, "Не удалось добавить изображение для книги {BookId}", book.Id);
                                bookTable.AddCell(new Cell().Add(new Paragraph("Ошибка загрузки изображения")));
                            }
                        }
                        else
                        {
                            bookTable.AddCell(new Cell().Add(new Paragraph("Нет изображения")));
                        }

                        // Правая колонка - информация
                        var infoCell = new Cell();
                        infoCell.Add(new Paragraph(book.Title).SetBold().SetFontSize(14));
                        
                        if (!string.IsNullOrWhiteSpace(book.Author))
                        {
                            infoCell.Add(new Paragraph($"Автор: {book.Author}"));
                        }
                        
                        if (book.YearPublished.HasValue)
                        {
                            infoCell.Add(new Paragraph($"Год издания: {book.YearPublished.Value}"));
                        }
                        
                        if (!string.IsNullOrWhiteSpace(book.Description))
                        {
                            infoCell.Add(new Paragraph($"Описание: {book.Description}").SetFontSize(10));
                        }
                        
                        if (book.EstimatedPrice.HasValue)
                        {
                            var priceText = book.IsManuallyPriced 
                                ? $"Оценка (ручная): {book.EstimatedPrice.Value:N0} руб."
                                : $"Оценка (автоматическая): {book.EstimatedPrice.Value:N0} руб.";
                            infoCell.Add(new Paragraph(priceText).SetBold());
                        }
                        
                        if (book.PurchasePrice.HasValue)
                        {
                            infoCell.Add(new Paragraph($"Цена покупки: {book.PurchasePrice.Value:N0} руб."));
                            
                            if (book.PurchaseDate.HasValue)
                            {
                                infoCell.Add(new Paragraph($"Дата покупки: {book.PurchaseDate.Value:dd.MM.yyyy}"));
                            }
                            
                            if (book.EstimatedPrice.HasValue)
                            {
                                var gain = book.EstimatedPrice.Value - book.PurchasePrice.Value;
                                var gainPercent = (gain / book.PurchasePrice.Value) * 100;
                                var gainText = gain >= 0 
                                    ? $"Прирост: +{gain:N0} руб. (+{gainPercent:F2}%)"
                                    : $"Убыток: {gain:N0} руб. ({gainPercent:F2}%)";
                                infoCell.Add(new Paragraph(gainText).SetFontSize(10).SetItalic());
                            }
                        }
                        
                        if (book.ReferenceBookId.HasValue && referenceBooks.ContainsKey(book.ReferenceBookId.Value))
                        {
                            var refBook = referenceBooks[book.ReferenceBookId.Value];
                            infoCell.Add(new Paragraph($"Референс: {refBook.Title}")
                                .SetFontSize(9)
                                .SetItalic());
                            infoCell.Add(new Paragraph($"ID лота: {refBook.Id}")
                                .SetFontSize(9)
                                .SetItalic());
                        }

                        bookTable.AddCell(infoCell);
                        document.Add(bookTable);
                    }

                    document.Close();

                    _logger.LogInformation("Экспорт в PDF завершен для пользователя {UserId}", userId);
                    return stream.ToArray();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при экспорте коллекции в PDF для пользователя {UserId}", userId);
                throw;
            }
        }

        public async Task<byte[]> ExportToJsonAsync(string userId)
        {
            try
            {
                _logger.LogInformation("Начало экспорта коллекции в JSON+ZIP для пользователя {UserId}", userId);

                var books = await _usersContext.UserCollectionBooks
                    .Include(b => b.Images)
                    .Where(b => b.UserId == userId)
                    .OrderBy(b => b.Title)
                    .ToListAsync();

                if (!books.Any())
                {
                    throw new InvalidOperationException("Коллекция пуста");
                }

                // Получаем референсные книги
                var referenceBookIds = books
                    .Where(b => b.ReferenceBookId.HasValue)
                    .Select(b => b.ReferenceBookId.Value)
                    .ToList();

                var referenceBooks = await _booksContext.BooksInfo
                    .Where(b => referenceBookIds.Contains(b.Id))
                    .ToDictionaryAsync(b => b.Id);

                // Создаем структуру данных для JSON
                var totalEstimatedValue = books.Where(b => b.EstimatedPrice.HasValue)
                                             .Sum(b => b.EstimatedPrice.Value);
                var totalPurchaseValue = books.Where(b => b.PurchasePrice.HasValue)
                                             .Sum(b => b.PurchasePrice.Value);
                var valueDifference = totalEstimatedValue - totalPurchaseValue;
                var percentageChange = totalPurchaseValue > 0 
                    ? (valueDifference / totalPurchaseValue) * 100 
                    : 0;
                    
                var exportData = new
                {
                    exportDate = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                    totalBooks = books.Count,
                    totalEstimatedValue = totalEstimatedValue,
                    totalPurchaseValue = totalPurchaseValue,
                    valueDifference = valueDifference,
                    percentageChange = percentageChange,
                    books = books.Select(book => new
                    {
                        id = book.Id,
                        title = book.Title,
                        author = book.Author,
                        yearPublished = book.YearPublished,
                        description = book.Description,
                        notes = book.Notes,
                        estimatedPrice = book.EstimatedPrice,
                        purchasePrice = book.PurchasePrice,
                        purchaseDate = book.PurchaseDate?.ToString("yyyy-MM-dd"),
                        isManuallyPriced = book.IsManuallyPriced,
                        addedDate = book.AddedDate,
                        updatedDate = book.UpdatedDate,
                        images = book.Images.Select(img => new
                        {
                            fileName = img.FileName,
                            isMainImage = img.IsMainImage,
                            uploadedDate = img.UploadedDate
                        }).ToList(),
                        referenceBook = book.ReferenceBookId.HasValue && referenceBooks.ContainsKey(book.ReferenceBookId.Value)
                            ? new
                            {
                                id = book.ReferenceBookId.Value,
                                title = referenceBooks[book.ReferenceBookId.Value].Title,
                                price = referenceBooks[book.ReferenceBookId.Value].FinalPrice,
                                url = $"https://yoursite.com/books/{book.ReferenceBookId.Value}" // TODO: заменить на реальный URL
                            }
                            : null
                    }).ToList()
                };

                // Создаем ZIP архив
                using (var zipStream = new MemoryStream())
                {
                    using (var archive = new ZipArchive(zipStream, ZipArchiveMode.Create, true))
                    {
                        // Добавляем JSON файл
                        var jsonEntry = archive.CreateEntry("collection_data.json");
                        using (var entryStream = jsonEntry.Open())
                        {
                            var options = new JsonSerializerOptions 
                            { 
                                WriteIndented = true,
                                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
                            };
                            await JsonSerializer.SerializeAsync(entryStream, exportData, options);
                        }

                        // Добавляем изображения
                        foreach (var book in books)
                        {
                            foreach (var image in book.Images)
                            {
                                try
                                {
                                    var imagePath = await _imageService.GetImagePathAsync(userId, book.Id, image.FileName);
                                    if (File.Exists(imagePath))
                                    {
                                        var imageEntry = archive.CreateEntry($"images/{book.Id}_{image.FileName}");
                                        using (var entryStream = imageEntry.Open())
                                        using (var fileStream = File.OpenRead(imagePath))
                                        {
                                            await fileStream.CopyToAsync(entryStream);
                                        }
                                    }
                                }
                                catch (Exception ex)
                                {
                                    _logger.LogWarning(ex, "Не удалось добавить изображение {FileName} для книги {BookId}", 
                                        image.FileName, book.Id);
                                }
                            }
                        }
                    }

                    _logger.LogInformation("Экспорт в JSON+ZIP завершен для пользователя {UserId}", userId);
                    return zipStream.ToArray();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при экспорте коллекции в JSON для пользователя {UserId}", userId);
                throw;
            }
        }

        public async Task<ImportCollectionResponse> ImportFromJsonAsync(ImportCollectionRequest request, string userId)
        {
            var response = new ImportCollectionResponse
            {
                Success = true,
                ImportedBooks = 0,
                SkippedBooks = 0,
                Errors = new List<string>()
            };

            try
            {
                _logger.LogInformation("Начало импорта коллекции для пользователя {UserId}. Книг в файле: {Count}", 
                    userId, request.Books?.Count ?? 0);

                if (request.Books == null || request.Books.Count == 0)
                {
                    response.Success = false;
                    response.Message = "Файл не содержит книг для импорта";
                    return response;
                }

                foreach (var bookData in request.Books)
                {
                    try
                    {
                        // Валидация обязательных полей
                        if (string.IsNullOrWhiteSpace(bookData.Title))
                        {
                            response.Errors.Add($"Пропущена книга без названия");
                            response.SkippedBooks++;
                            continue;
                        }

                        // Определяем финальное название (без автора)
                        string finalTitle = bookData.Title;
                        if (!string.IsNullOrEmpty(bookData.Author) && bookData.Title.StartsWith(bookData.Author))
                        {
                            finalTitle = bookData.Title.Substring(bookData.Author.Length).TrimStart('.', ' ');
                        }

                        // Создаем книгу
                        var book = new UserCollectionBook
                        {
                            UserId = userId,
                            Title = finalTitle,
                            Author = bookData.Author,
                            YearPublished = bookData.YearPublished,
                            Description = null, // Пока не используется
                            Notes = bookData.Notes,
                            PurchasePrice = bookData.TotalPurchasePrice ?? bookData.PurchasePrice,
                            PurchaseDate = bookData.PurchaseDate.HasValue 
                                ? DateTime.SpecifyKind(bookData.PurchaseDate.Value, DateTimeKind.Utc) 
                                : null,
                            IsSold = bookData.IsSold,
                            SoldPrice = bookData.SoldPrice,
                            SoldDate = bookData.SoldDate.HasValue 
                                ? DateTime.SpecifyKind(bookData.SoldDate.Value, DateTimeKind.Utc) 
                                : null,
                            AddedDate = DateTime.UtcNow,
                            UpdatedDate = DateTime.UtcNow,
                            IsManuallyPriced = false,
                            EstimatedPrice = null
                        };

                        _usersContext.UserCollectionBooks.Add(book);
                        await _usersContext.SaveChangesAsync();

                        response.ImportedBooks++;
                        _logger.LogDebug("Импортирована книга: {Title}", finalTitle);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Ошибка при импорте книги: {Title}", bookData.Title);
                        response.Errors.Add($"Ошибка при импорте '{bookData.Title}': {ex.Message}");
                        response.SkippedBooks++;
                    }
                }

                response.Message = $"Импортировано книг: {response.ImportedBooks}. Пропущено: {response.SkippedBooks}";
                _logger.LogInformation("Импорт завершен. Импортировано: {Imported}, Пропущено: {Skipped}", 
                    response.ImportedBooks, response.SkippedBooks);

                return response;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Критическая ошибка при импорте коллекции для пользователя {UserId}", userId);
                response.Success = false;
                response.Message = $"Критическая ошибка импорта: {ex.Message}";
                return response;
            }
        }
    }
}

