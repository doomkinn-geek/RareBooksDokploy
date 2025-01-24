using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Parser.Services;
using System.IO.Compression;

namespace RareBooksService.WebApi.Services
{
    public interface IBookImagesService
    {
        Task<(List<string> images, List<string> thumbnails)> GetBookImagesAsync(
            BookDetailDto book,
            bool hasSubscription,
            bool useLocalFiles);

        Task<ActionResult?> GetImageAsync(
            BookDetailDto book,
            string imageName,
            bool hasSubscription,
            bool useLocalFiles);

        Task<ActionResult?> GetThumbnailAsync(
            BookDetailDto book,
            string thumbName,
            bool hasSubscription,
            bool useLocalFiles);
    }

    public class BookImagesService : IBookImagesService
    {
        private readonly ILogger<BookImagesService> _logger;
        private readonly IYandexStorageService _yandexStorageService;

        private static readonly HttpClient _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(10)
        };

        public BookImagesService(ILogger<BookImagesService> logger,
                                 IYandexStorageService yandexStorageService)
        {
            _logger = logger;
            _yandexStorageService = yandexStorageService;
        }

        // =======================
        // 1) Получение списков изображений
        // =======================
        public async Task<(List<string> images, List<string> thumbnails)> GetBookImagesAsync(
            BookDetailDto book,
            bool hasSubscription,
            bool useLocalFiles)
        {
            if (!hasSubscription)
            {
                // Нет подписки => пустой список
                return (new List<string>(), new List<string>());
            }

            // Если лот малоценный => всегда прямые ссылки
            if (book.IsLessValuable)
            {
                return DirectLinksApproach(book);
            }

            // Иначе (IsLessValuable = false) => проверяем первую ссылку
            if (book.ImageUrls != null && book.ImageUrls.Count > 0)
            {
                // Проверяем доступность первой ссылки
                var firstLink = book.ImageUrls[0];
                bool firstLinkOk = await CheckUrlAccessibleAsync(firstLink);
                if (firstLinkOk)
                {
                    // если первая ссылка доступна -> используем DirectLinksApproach, 
                    // игнорируя IsImagesCompressed
                    return DirectLinksApproach(book);
                }
            }

            // Если дошли сюда, значит 
            //   - первая ссылка отсутствует/недоступна 
            //     (или book.ImageUrls == null/empty),
            // => тогда переходим к архиву/legacy
            if (book.IsImagesCompressed)
            {
                return await GetImagesFromArchive(book, useLocalFiles);
            }
            else
            {
                return await GetLegacyImagesAsync(book.Id, useLocalFiles);
            }
        }

        // =======================
        // 2) Получение *одного* полноразмерного изображения
        // =======================
        public async Task<ActionResult?> GetImageAsync(
        BookDetailDto book,
        string imageName,
        bool hasSubscription,
        bool useLocalFiles)
        {
            // 2.1) Сначала проверяем подписку
            if (!hasSubscription)
            {
                return new ForbidResult("Требуется подписка для полноразмерных изображений.");
            }

            // 2.2) Если `imageName` – это полная ссылка (http/https),
            //      сразу «проксируем» без поиска в book.ImageUrls
            if (IsAbsoluteUrl(imageName))
            {
                _logger.LogInformation("GetImageAsync: Параметр imageName = абсолютная ссылка {Url}, проксируем напрямую", imageName);
                return await ProxyImageAsync(imageName);
            }

            // 2.3) Иначе работаем по «старым» правилам
            if (book.IsLessValuable)
            {
                // ищем fileName в book.ImageUrls
                var matchingUrl = FindByFileName(book.ImageUrls, imageName);
                if (matchingUrl == null)
                {
                    _logger.LogWarning("Не найдена ссылка на изображение '{imageName}' (малоценный) у лота {bookId}", imageName, book.Id);
                    return new NotFoundResult();
                }
                return await ProxyImageAsync(matchingUrl);
            }
            else
            {
                // обычный лот
                if (book.IsImagesCompressed)
                {
                    // архив
                    return await GetFileFromArchive(book.ImageArchiveUrl, $"images/{imageName}", useLocalFiles);
                }
                else
                {
                    // legacy
                    return await GetLegacyImageAsync(book.Id, imageName, isThumbnail: false, useLocalFiles);
                }
            }
        }

        // ---------------------------
        // 3) Получение одной миниатюры
        // ---------------------------
        public async Task<ActionResult?> GetThumbnailAsync(
            BookDetailDto book,
            string thumbName,
            bool hasSubscription,
            bool useLocalFiles)
        {
            // 3.1) Если thumbName – полная ссылка → проксируем
            if (IsAbsoluteUrl(thumbName))
            {
                _logger.LogInformation("GetThumbnailAsync: Параметр thumbName = абсолютная ссылка {Url}, проксируем", thumbName);
                return await ProxyImageAsync(thumbName);
            }

            // 3.2) Если лот малоценный → ищем, проксируем
            if (book.IsLessValuable)
            {
                var matchingUrl = FindByFileName(book.ThumbnailUrls, thumbName);
                if (matchingUrl == null)
                {
                    _logger.LogWarning("Не найдена ссылка на миниатюру '{thumbName}' (малоценный) у лота {bookId}", thumbName, book.Id);
                    return new NotFoundResult();
                }
                return await ProxyImageAsync(matchingUrl);
            }

            // 3.3) Иначе проверяем подписку
            if (!hasSubscription)
            {
                return new ForbidResult("Требуется подписка для миниатюр (кроме малоценных).");
            }

            // 3.4) Иначе обычный лот
            if (book.IsImagesCompressed)
            {
                return await GetFileFromArchive(book.ImageArchiveUrl, $"thumbnails/{thumbName}", useLocalFiles);
            }
            else
            {
                return await GetLegacyImageAsync(book.Id, thumbName, isThumbnail: true, useLocalFiles);
            }
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~
        //  ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
        // ~~~~~~~~~~~~~~~~~~~~~~~~~

        private bool IsAbsoluteUrl(string val)
        {
            // Либо простая проверка, либо более точная Uri.TryCreate(...)
            return val.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
                || val.StartsWith("https://", StringComparison.OrdinalIgnoreCase);
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        //  HELPER: "Direct Links" — как для малоценных
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        private (List<string> images, List<string> thumbnails) DirectLinksApproach(BookDetailDto book)
        {
            // Просто возвращаем те же ссылки, без проверки CheckUrlAccessibleAsync
            // (иначе мы бы снова делали много лишних запросов)
            // Но, если хотите, можно проверить каждую, 
            // тогда (List<string> bigImages, List<string> thumbs) = ...
            var bigImages = new List<string>(book.ImageUrls);
            var thumbs = new List<string>(book.ThumbnailUrls);
            return (bigImages, thumbs);
        }

        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        //  HELPER: Ищем URL, чей "файл" совпадает с imageName
        // ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        private string? FindByFileName(List<string> urls, string targetFileName)
        {
            if (urls == null) return null;
            foreach (var url in urls)
            {
                var fileName = Path.GetFileName(url);
                if (fileName.Equals(targetFileName, StringComparison.OrdinalIgnoreCase))
                    return url;
            }
            return null;
        }

        // =======================
        // 4) Чтение архива
        // =======================
        private async Task<(List<string> images, List<string> thumbnails)> GetImagesFromArchive(
            BookDetailDto book, bool useLocalFiles)
        {
            var images = new List<string>();
            var thumbs = new List<string>();

            if (useLocalFiles)
            {
                if (!File.Exists(book.ImageArchiveUrl))
                {
                    _logger.LogWarning("Archive not found: {ArchivePath}", book.ImageArchiveUrl);
                    return (images, thumbs);
                }
                using var archive = ZipFile.OpenRead(book.ImageArchiveUrl);
                foreach (var entry in archive.Entries)
                {
                    if (string.IsNullOrEmpty(entry.Name)) continue;
                    if (entry.FullName.StartsWith("thumbnails/"))
                        thumbs.Add(entry.Name);
                    else if (entry.FullName.StartsWith("images/"))
                        images.Add(entry.Name);
                }
            }
            else
            {
                var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);
                if (archiveStream == null)
                {
                    _logger.LogWarning("Archive not found in object storage: {ArchiveUrl}", book.ImageArchiveUrl);
                    return (images, thumbs);
                }
                using var archive = new ZipArchive(archiveStream, ZipArchiveMode.Read);
                foreach (var entry in archive.Entries)
                {
                    if (string.IsNullOrEmpty(entry.Name)) continue;
                    if (entry.FullName.StartsWith("thumbnails/"))
                        thumbs.Add(entry.Name);
                    else if (entry.FullName.StartsWith("images/"))
                        images.Add(entry.Name);
                }
            }

            return (images, thumbs);
        }

        // =======================
        // 5) "Legacy" (без архива)
        // =======================
        private async Task<(List<string>, List<string>)> GetLegacyImagesAsync(int bookId, bool useLocalFiles)
        {
            var images = new List<string>();
            var thumbs = new List<string>();

            if (useLocalFiles)
            {
                // Локальные папки
                string basePath = Path.Combine(AppContext.BaseDirectory, "books_photos", bookId.ToString());
                var imagesPath = Path.Combine(basePath, "images");
                var thumbsPath = Path.Combine(basePath, "thumbnails");

                if (Directory.Exists(imagesPath))
                    images.AddRange(Directory.GetFiles(imagesPath).Select(Path.GetFileName));
                if (Directory.Exists(thumbsPath))
                    thumbs.AddRange(Directory.GetFiles(thumbsPath).Select(Path.GetFileName));
            }
            else
            {
                // S3
                var keysImg = await _yandexStorageService.GetImageKeysAsync(bookId);
                var keysThumb = await _yandexStorageService.GetThumbnailKeysAsync(bookId);
                images.AddRange(keysImg);
                thumbs.AddRange(keysThumb);
            }

            return (images, thumbs);
        }

        // =======================
        // 6) Читаем файл из архива
        // =======================
        private async Task<ActionResult?> GetFileFromArchive(
            string archiveUrl, string entryPath, bool useLocalFiles)
        {
            if (useLocalFiles)
            {
                if (!File.Exists(archiveUrl))
                {
                    return new NotFoundResult();
                }
                using var zip = ZipFile.OpenRead(archiveUrl);
                var entry = zip.GetEntry(entryPath);
                if (entry == null) return new NotFoundResult();

                using var entryStream = entry.Open();
                var ms = new MemoryStream();
                await entryStream.CopyToAsync(ms);
                ms.Position = 0;
                return new FileStreamResult(ms, "image/jpeg");
            }
            else
            {
                var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(archiveUrl);
                if (archiveStream == null) return new NotFoundResult();

                using var zip = new ZipArchive(archiveStream, ZipArchiveMode.Read);
                var entry = zip.GetEntry(entryPath);
                if (entry == null) return new NotFoundResult();

                using var es = entry.Open();
                var ms = new MemoryStream();
                await es.CopyToAsync(ms);
                ms.Position = 0;
                return new FileStreamResult(ms, "image/jpeg");
            }
        }

        // =======================
        // 7) "Legacy" выдача одного файла
        // =======================
        private async Task<ActionResult?> GetLegacyImageAsync(
            int bookId, string fileName, bool isThumbnail, bool useLocalFiles)
        {
            if (useLocalFiles)
            {
                string basePath = Path.Combine(AppContext.BaseDirectory, "books_photos", bookId.ToString());
                var folder = isThumbnail ? "thumbnails" : "images";
                var path = Path.Combine(basePath, folder, fileName);
                if (!File.Exists(path)) return new NotFoundResult();

                var stream = File.OpenRead(path);
                return new FileStreamResult(stream, "image/jpeg");
            }
            else
            {
                // S3
                var prefix = isThumbnail ? "thumbnails" : "images";
                var key = $"{bookId}/{prefix}/{fileName}";
                Stream imageStream = null;
                if (isThumbnail)
                    imageStream = await _yandexStorageService.GetThumbnailStreamAsync(key);
                else
                    imageStream = await _yandexStorageService.GetImageStreamAsync(key);

                if (imageStream == null) return new NotFoundResult();
                return new FileStreamResult(imageStream, "image/jpeg");
            }
        }

        // =======================
        // 8) "Прокси": скачать по внешней ссылке
        // =======================
        private async Task<ActionResult?> ProxyImageAsync(string url)
        {
            try
            {
                using var resp = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                if (!resp.IsSuccessStatusCode)
                    return null; // вернуть 404? => можно return new NotFoundResult()

                var contentType = resp.Content.Headers.ContentType?.ToString() ?? "image/jpeg";
                var stream = await resp.Content.ReadAsStreamAsync();
                return new FileStreamResult(stream, contentType);
            }
            catch
            {
                return null;
            }
        }

        // =======================
        // 9) Проверяем доступность URL
        // =======================
        private async Task<bool> CheckUrlAccessibleAsync(string url)
        {
            try
            {
                using var resp = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                return resp.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }
    }
}
