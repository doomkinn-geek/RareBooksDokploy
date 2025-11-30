using System;
using System.IO;
using System.Linq;
using System.Globalization;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;
using OfficeOpenXml;
using ClosedXML.Excel;

namespace RareBooksImporter
{
    class Program
    {
        static void Main(string[] args)
        {
            // EPPlus требует установки LicenseContext
            //ExcelPackage.LicenseContext = LicenseContext.NonCommercial;

            Console.WriteLine("=== Конвертер коллекции книг XLSX → JSON ===");
            Console.WriteLine();

            if (args.Length == 0)
            {
                Console.WriteLine("Использование: RareBooksImporter <путь-к-xlsx-файлу> [путь-к-json-выходу]");
                Console.WriteLine("Пример: RareBooksImporter books.xlsx collection.json");
                Console.WriteLine();
                Console.WriteLine("Если не указан выходной файл, будет создан [имя-входного].json");
                return;
            }

            string inputPath = args[0];
            string outputPath = args.Length > 1 
                ? args[1] 
                : Path.ChangeExtension(inputPath, ".json");

            if (!File.Exists(inputPath))
            {
                Console.WriteLine($"ОШИБКА: Файл не найден: {inputPath}");
                return;
            }

            Console.WriteLine($"Входной файл:  {inputPath}");
            Console.WriteLine($"Выходной файл: {outputPath}");
            Console.WriteLine();

            try
            {
                var books = ProcessExcelFile(inputPath);
                SaveToJson(books, outputPath);
                
                Console.WriteLine();
                Console.WriteLine("✅ Конвертация успешно завершена!");
                Console.WriteLine($"📄 Создан файл: {outputPath}");
                Console.WriteLine($"📚 Книг в коллекции: {books.Count}");
            }
            catch (Exception ex)
            {
                Console.WriteLine();
                Console.WriteLine($"❌ ОШИБКА: {ex.Message}");
                Console.WriteLine(ex.StackTrace);
            }
        }

        static List<BookData> ProcessExcelFile(string filePath)
        {
            using var workbook = new XLWorkbook(filePath);
            var ws = workbook.Worksheet(1);

            var books = new List<BookData>();
            int rowCount = ws.LastRowUsed().RowNumber();

            for (int row = 3; row <= rowCount; row++)
            {
                string title = ws.Cell(row, 2).GetString();

                if (string.IsNullOrWhiteSpace(title))
                    continue;

                var book = new BookData
                {
                    Title = title,
                    Author = ExtractAuthor(title),
                    PurchaseDate = ParseDate(ws.Cell(row, 1).GetString()),
                    YearPublished = ParseYear(ws.Cell(row, 3).GetString()),
                    PurchasePrice = ParsePrice(ws.Cell(row, 4).GetString()),
                    DeliveryCost = ParsePrice(ws.Cell(row, 5).GetString()),
                    SoldPrice = ParsePrice(ws.Cell(row, 6).GetString()),
                    SoldDate = ParseDate(ws.Cell(row, 9).GetString()),
                    SaleNotes = ws.Cell(row, 10).GetString(),
                    Comments = ws.Cell(row, 11).GetString()
                };

                // Цена общая
                if (book.PurchasePrice.HasValue && book.DeliveryCost.HasValue)
                    book.TotalPurchasePrice = book.PurchasePrice.Value + book.DeliveryCost.Value;
                else
                    book.TotalPurchasePrice = book.PurchasePrice;

                // Комментарии
                book.FullNotes = BuildFullNotes(book.SaleNotes, book.Comments);

                book.IsSold = book.SoldPrice.HasValue || book.SoldDate.HasValue;

                books.Add(book);
            }

            return books;
        }

        static void SaveToJson(List<BookData> books, string outputPath)
        {
            var exportData = new CollectionExportData
            {
                ExportDate = DateTime.UtcNow,
                TotalBooks = books.Count,
                Books = books
            };

            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
                Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping
            };

            string json = JsonSerializer.Serialize(exportData, options);
            File.WriteAllText(outputPath, json, System.Text.Encoding.UTF8);
        }

        static BookData ParseRow(ExcelWorksheet ws, int row)
        {
            // Колонки по схеме:
            // A: Дата покупки
            // B: Название, Автор
            // C: Год издания
            // D: Стоимость покупки
            // E: Стоимость доставки
            // F: Стоимость продажи (если продана)
            // G: Стоимость доставки при продаже (игнорируем)
            // H: Профит (игнорируем, рассчитаем сами)
            // I: Дата продажи
            // J: О продаже
            // K: Комментарий

            string title = GetCellValue(ws, row, 2); // B - Название
            if (string.IsNullOrWhiteSpace(title))
                return null;

            var book = new BookData
            {
                Title = title,
                Author = ExtractAuthor(title),
                PurchaseDate = ParseDate(GetCellValue(ws, row, 1)), // A
                YearPublished = ParseYear(GetCellValue(ws, row, 3)), // C
                PurchasePrice = ParsePrice(GetCellValue(ws, row, 4)), // D
                DeliveryCost = ParsePrice(GetCellValue(ws, row, 5)), // E
                SoldPrice = ParsePrice(GetCellValue(ws, row, 6)), // F
                SoldDate = ParseDate(GetCellValue(ws, row, 9)), // I
                SaleNotes = GetCellValue(ws, row, 10), // J - О продаже
                Comments = GetCellValue(ws, row, 11) // K - Комментарий
            };

            // Объединяем стоимость покупки + доставка
            if (book.PurchasePrice.HasValue && book.DeliveryCost.HasValue)
            {
                book.TotalPurchasePrice = book.PurchasePrice.Value + book.DeliveryCost.Value;
            }
            else if (book.PurchasePrice.HasValue)
            {
                book.TotalPurchasePrice = book.PurchasePrice.Value;
            }

            // Формируем полный комментарий
            book.FullNotes = BuildFullNotes(book.SaleNotes, book.Comments);

            // Определяем, продана ли книга
            book.IsSold = book.SoldPrice.HasValue || book.SoldDate.HasValue;

            return book;
        }

        static string GetCellValue(ExcelWorksheet ws, int row, int col)
        {
            var cell = ws.Cells[row, col];
            return cell.Value?.ToString()?.Trim() ?? string.Empty;
        }

        static string ExtractAuthor(string titleAndAuthor)
        {
            // Пытаемся извлечь автора из строки вида "Захарьин (Якунин). Тени прошлого"
            // или "История современной Европы. 2тт."
            
            if (titleAndAuthor.Contains("."))
            {
                var parts = titleAndAuthor.Split('.');
                if (parts.Length > 1)
                {
                    string firstPart = parts[0].Trim();
                    // Проверяем, есть ли в первой части имя/фамилия
                    if (firstPart.Length > 3 && firstPart.Length < 100 && 
                        !firstPart.Contains("кн.") && !firstPart.Contains("т."))
                    {
                        return firstPart;
                    }
                }
            }

            return null;
        }

        static DateTime? ParseDate(string dateStr)
        {
            if (string.IsNullOrWhiteSpace(dateStr))
                return null;

            // Форматы: "7-1-2016", "7-26-2016", "12-2-2016"
            string[] formats = { "M-d-yyyy", "M-dd-yyyy", "MM-d-yyyy", "MM-dd-yyyy", 
                                 "d-M-yyyy", "dd-M-yyyy", "d-MM-yyyy", "dd-MM-yyyy" };

            foreach (var format in formats)
            {
                if (DateTime.TryParseExact(dateStr, format, CultureInfo.InvariantCulture, 
                    DateTimeStyles.None, out DateTime result))
                {
                    return DateTime.SpecifyKind(result, DateTimeKind.Utc);
                }
            }

            // Пробуем общий парсинг
            if (DateTime.TryParse(dateStr, out DateTime generalResult))
            {
                return DateTime.SpecifyKind(generalResult, DateTimeKind.Utc);
            }

            return null;
        }

        static int? ParseYear(string yearStr)
        {
            if (string.IsNullOrWhiteSpace(yearStr))
                return null;

            // Может быть "1885", "I - 1907; II - 1903", "1887"
            // Берем первое 4-значное число
            var match = System.Text.RegularExpressions.Regex.Match(yearStr, @"\b(1[7-9]\d{2}|20\d{2})\b");
            if (match.Success)
            {
                return int.Parse(match.Value);
            }

            return null;
        }

        static decimal? ParsePrice(string priceStr)
        {
            if (string.IsNullOrWhiteSpace(priceStr))
                return null;

            // Убираем пробелы, "р.", "руб."
            priceStr = priceStr.Replace(" ", "")
                               .Replace("р.", "")
                               .Replace("руб.", "")
                               .Replace("р", "")
                               .Trim();

            if (decimal.TryParse(priceStr, NumberStyles.Any, CultureInfo.InvariantCulture, out decimal result))
            {
                return result;
            }

            return null;
        }

        static string BuildFullNotes(string saleNotes, string comments)
        {
            var parts = new System.Collections.Generic.List<string>();

            if (!string.IsNullOrWhiteSpace(saleNotes))
            {
                parts.Add($"О продаже: {saleNotes}");
            }

            if (!string.IsNullOrWhiteSpace(comments))
            {
                parts.Add(comments);
            }

            return parts.Count > 0 ? string.Join("\n\n", parts) : null;
        }
    }

    // Класс для экспорта коллекции
    class CollectionExportData
    {
        [JsonPropertyName("exportDate")]
        public DateTime ExportDate { get; set; }

        [JsonPropertyName("totalBooks")]
        public int TotalBooks { get; set; }

        [JsonPropertyName("books")]
        public List<BookData> Books { get; set; }
    }

    class BookData
    {
        [JsonPropertyName("title")]
        public string Title { get; set; }
        
        [JsonPropertyName("author")]
        public string Author { get; set; }
        
        [JsonPropertyName("yearPublished")]
        public int? YearPublished { get; set; }
        
        [JsonPropertyName("purchaseDate")]
        public DateTime? PurchaseDate { get; set; }
        
        [JsonPropertyName("purchasePrice")]
        public decimal? PurchasePrice { get; set; }
        
        [JsonPropertyName("deliveryCost")]
        public decimal? DeliveryCost { get; set; }
        
        [JsonPropertyName("totalPurchasePrice")]
        public decimal? TotalPurchasePrice { get; set; }
        
        [JsonPropertyName("soldPrice")]
        public decimal? SoldPrice { get; set; }
        
        [JsonPropertyName("soldDate")]
        public DateTime? SoldDate { get; set; }
        
        [JsonPropertyName("saleNotes")]
        public string SaleNotes { get; set; }
        
        [JsonPropertyName("comments")]
        public string Comments { get; set; }
        
        [JsonPropertyName("notes")]
        public string FullNotes { get; set; }
        
        [JsonPropertyName("isSold")]
        public bool IsSold { get; set; }

        /*[JsonIgnore]
        public string CleanTitle
        {
            get
            {
                // Убираем автора из названия, если он там есть
                if (!string.IsNullOrEmpty(Author) && Title != null && Title.StartsWith(Author))
                {
                    return Title.Substring(Author.Length).TrimStart('.', ' ');
                }
                return Title;
            }
        }*/
    }
}
