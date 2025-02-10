using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Common.Models.Settings;
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

        // Общий HttpClient (для загрузки из URL)
        private static readonly HttpClient _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(10)
        };

        // ------------ НАСТРОЙКИ КЭША ------------
        private readonly string _cacheRootPath;
        private readonly TimeSpan _cacheLifetime = TimeSpan.FromDays(30);
        private static readonly object _cacheLock = new object();

        public BookImagesService(ILogger<BookImagesService> logger,
                                 IYandexStorageService yandexStorageService,
                                IOptions<CacheSettings> cacheOptions)
        {
            _logger = logger;
            _yandexStorageService = yandexStorageService;

            var c = cacheOptions.Value;
            _cacheRootPath = Path.Combine(AppContext.BaseDirectory, c.LocalCachePath);
            _cacheLifetime = TimeSpan.FromDays(c.DaysToKeep);

            Directory.CreateDirectory(_cacheRootPath);
        }

        // ==================================================================================
        //  (1) ПОЛУЧЕНИЕ СПИСКА ИЗОБРАЖЕНИЙ (+ работа с кэшем)
        // ==================================================================================
        public async Task<(List<string> images, List<string> thumbnails)> GetBookImagesAsync(
            BookDetailDto book,
            bool hasSubscription,
            bool useLocalFiles)
        {
            // 1. Если нет подписки -> пусто
            if (!hasSubscription)
                return (new List<string>(), new List<string>());

            // 2. Если IsLessValuable -> только URL, без fallback
            if (book.IsLessValuable)
            {
                // если вообще нет ссылок -> пусто
                if (book.ImageUrls == null || book.ImageUrls.Count == 0)
                    return (new List<string>(), new List<string>());

                // Проверяем доступность или наличие в кэше первой ссылки:
                var firstUrl = book.ImageUrls[0];
                bool firstOk = await CheckImageOrCacheAsync(book.Id, firstUrl, isThumbnail: false, fallbackForbidden: true);
                if (!firstOk)
                {
                    // если первая недоступна -> пусто
                    return (new List<string>(), new List<string>());
                }

                // если первая доступна -> обрабатываем все images
                var imagesOk = new List<string>();
                foreach (var url in book.ImageUrls)
                {
                    bool ok = await CheckImageOrCacheAsync(book.Id, url, false, fallbackForbidden: true);
                    if (ok) imagesOk.Add(url);
                }
                // Аналогично для миниатюр
                var thumbsOk = new List<string>();
                if (book.ThumbnailUrls != null)
                {
                    foreach (var turl in book.ThumbnailUrls)
                    {
                        bool ok = await CheckImageOrCacheAsync(book.Id, turl, true, fallbackForbidden: true);
                        if (ok) thumbsOk.Add(turl);
                    }
                }

                return (imagesOk, thumbsOk);
            }

            // 3. Если IsImagesCompressed -> читаем из архива (локально или S3),
            //    складываем все файлы в кэш, возвращаем списки.
            if (book.IsImagesCompressed)
            {
                return await FetchArchiveImagesAndCache(book, useLocalFiles);
            }

            // 4. Иначе (обычный лот) -> проверяем первую ссылку (кэш / URL)
            //    если доступна -> «прямые ссылки»
            //    если нет -> «legacy» (локальные файлы или S3)
            if (book.ImageUrls != null && book.ImageUrls.Count > 0)
            {
                var firstUrl = book.ImageUrls[0];
                bool firstOk = await CheckImageOrCacheAsync(book.Id, firstUrl, false, fallbackForbidden: false);
                if (firstOk)
                {
                    // Значит URL доступны
                    var imagesOk = new List<string>();
                    foreach (var url in book.ImageUrls)
                    {
                        bool ok = await CheckImageOrCacheAsync(book.Id, url, false, fallbackForbidden: false);
                        if (ok) imagesOk.Add(url);
                    }
                    var thumbsOk = new List<string>();
                    if (book.ThumbnailUrls != null)
                    {
                        foreach (var turl in book.ThumbnailUrls)
                        {
                            bool ok = await CheckImageOrCacheAsync(book.Id, turl, true, fallbackForbidden: false);
                            if (ok) thumbsOk.Add(turl);
                        }
                    }
                    return (imagesOk, thumbsOk);
                }
            }

            // Если дошли сюда -> ссылка либо отсутствует, либо недоступна
            // -> Legacy (S3 или локальные)
            return await FetchLegacyImagesAndCache(book.Id, useLocalFiles);
        }

        // ==================================================================================
        //  (2) ПОЛУЧЕНИЕ ПОЛНОРАЗМЕРНОГО ИЗОБРАЖЕНИЯ
        // ==================================================================================
        public async Task<ActionResult?> GetImageAsync(
            BookDetailDto book,
            string imageName,
            bool hasSubscription,
            bool useLocalFiles)
        {
            // Проверка подписки
            if (!hasSubscription)
            {
                return new ForbidResult("Требуется подписка для полноразмерных изображений.");
            }

            // Смотрим кэш
            var cached = TryGetFromCache(book.Id, imageName, isThumbnail: false);
            if (cached != null)
            {
                _logger.LogDebug("GetImageAsync: {0}/{1} найдено в кэше", book.Id, imageName);
                return new FileStreamResult(cached, "image/jpeg");
            }

            if (book.IsLessValuable)
            {
                // Только URL без fallback
                var url = FindByFileName(book.ImageUrls, imageName);
                if (url == null)
                {
                    _logger.LogWarning("Не найдена ссылка на изображение '{0}' (малоценный) у лота {1}", imageName, book.Id);
                    return new NotFoundResult();
                }

                var stream = await DownloadImageFromUrlAsync(url, TimeSpan.FromSeconds(1));
                if (stream == null)
                    return new NotFoundResult();

                SaveFileToCache(book.Id, imageName, false, stream);
                stream.Position = 0;
                return new FileStreamResult(stream, "image/jpeg");
            }
            else
            {
                // Обычный лот
                if (book.IsImagesCompressed)
                {
                    // Чтение из архива
                    return await GetFileFromArchive(book, $"images/{imageName}", useLocalFiles);
                }
                else
                {
                    // Legacy или URL
                    // Сначала URL (1 сек)
                    if (book.ImageUrls != null && book.ImageUrls.Count > 0)
                    {
                        var matchingUrl = FindByFileName(book.ImageUrls, imageName);
                        if (matchingUrl != null)
                        {
                            var stream = await DownloadImageFromUrlAsync(matchingUrl, TimeSpan.FromSeconds(1));
                            if (stream != null)
                            {
                                SaveFileToCache(book.Id, imageName, false, stream);
                                stream.Position = 0;
                                return new FileStreamResult(stream, "image/jpeg");
                            }
                        }
                    }

                    // Fallback -> legacy (S3 или локал)
                    return await GetLegacyImageAsync(book.Id, imageName, false, useLocalFiles);
                }
            }
        }

        // ==================================================================================
        //  (3) ПОЛУЧЕНИЕ МИНИАТЮРЫ
        // ==================================================================================
        public async Task<ActionResult?> GetThumbnailAsync(
            BookDetailDto book,
            string thumbName,
            bool hasSubscription,
            bool useLocalFiles)
        {
            if (!book.IsLessValuable && !hasSubscription)
            {
                return new ForbidResult("Требуется подписка для миниатюр (кроме малоценных).");
            }

            var cached = TryGetFromCache(book.Id, thumbName, true);
            if (cached != null)
            {
                _logger.LogDebug("GetThumbnailAsync: {0}/{1} взято из кэша", book.Id, thumbName);
                return new FileStreamResult(cached, "image/jpeg");
            }

            if (book.IsLessValuable)
            {
                var url = FindByFileName(book.ThumbnailUrls, thumbName);
                if (url == null)
                {
                    _logger.LogWarning("Не найдена ссылка на миниатюру '{0}' (малоценный) у лота {1}", thumbName, book.Id);
                    return new NotFoundResult();
                }

                var stream = await DownloadImageFromUrlAsync(url, TimeSpan.FromSeconds(1));
                if (stream == null)
                    return new NotFoundResult();

                SaveFileToCache(book.Id, thumbName, true, stream);
                stream.Position = 0;
                return new FileStreamResult(stream, "image/jpeg");
            }
            else
            {
                // Обычный
                if (book.IsImagesCompressed)
                {
                    return await GetFileFromArchive(book, $"thumbnails/{thumbName}", useLocalFiles);
                }
                else
                {
                    // Legacy или URL
                    if (book.ThumbnailUrls != null && book.ThumbnailUrls.Count > 0)
                    {
                        var matchingUrl = FindByFileName(book.ThumbnailUrls, thumbName);
                        if (matchingUrl != null)
                        {
                            var stream = await DownloadImageFromUrlAsync(matchingUrl, TimeSpan.FromSeconds(1));
                            if (stream != null)
                            {
                                SaveFileToCache(book.Id, thumbName, true, stream);
                                stream.Position = 0;
                                return new FileStreamResult(stream, "image/jpeg");
                            }
                        }
                    }

                    return await GetLegacyImageAsync(book.Id, thumbName, true, useLocalFiles);
                }
            }
        }

        // ==================================================================================
        //   ВСПОМОГАТЕЛЬНАЯ ЛОГИКА ДЛЯ GetBookImagesAsync
        // ==================================================================================

        /// <summary>
        /// Проверяет, есть ли файл в кэше (по URL -> имя файла).
        /// Если нет — скачивает (1 сек) и складывает в кэш.
        /// Если `fallbackForbidden = true`, то при неудаче вернётся false (без попытки взять из ObjectStorage).
        /// Возвращает true, если файл либо взят из кэша, либо успешно скачан.
        /// </summary>
        private async Task<bool> CheckImageOrCacheAsync(int bookId, string url, bool isThumbnail, bool fallbackForbidden)
        {
            var fileName = Path.GetFileName(url);

            // 1) Проверка кэша
            using var cached = TryGetFromCache(bookId, fileName, isThumbnail);
            if (cached != null)
            {
                return true;
            }

            // 2) Скачиваем
            var stream = await DownloadImageFromUrlAsync(url, TimeSpan.FromSeconds(1));
            if (stream != null)
            {
                SaveFileToCache(bookId, fileName, isThumbnail, stream);
                return true;
            }

            // 3) Не скачалось
            if (fallbackForbidden)
            {
                // Нет fallback
                return false;
            }

            // Иначе вернём false → вызывающий код решит пойти ли в Legacy / ObjectStorage
            return false;
        }

        /// <summary>
        /// Извлекает список изображений из архива (локально или S3),
        /// выкладывает их в кэш и возвращает (images, thumbnails).
        /// </summary>
        private async Task<(List<string> images, List<string> thumbnails)> FetchArchiveImagesAndCache(
            BookDetailDto book, bool useLocalFiles)
        {
            var images = new List<string>();
            var thumbnails = new List<string>();

            if (useLocalFiles)
            {
                if (!File.Exists(book.ImageArchiveUrl))
                {
                    _logger.LogWarning("Archive not found: {0}", book.ImageArchiveUrl);
                    return (images, thumbnails);
                }

                using var zip = ZipFile.OpenRead(book.ImageArchiveUrl);
                foreach (var entry in zip.Entries)
                {
                    if (string.IsNullOrEmpty(entry.Name)) continue;
                    bool isThumb = entry.FullName.StartsWith("thumbnails/", StringComparison.OrdinalIgnoreCase);
                    var fileName = entry.Name;

                    // Проверяем кэш
                    using var existing = TryGetFromCache(book.Id, fileName, isThumb);
                    if (existing == null)
                    {
                        // Сохраняем
                        using var es = entry.Open();
                        using var ms = new MemoryStream();
                        es.CopyTo(ms);
                        ms.Position = 0;
                        SaveFileToCache(book.Id, fileName, isThumb, ms);
                    }

                    if (isThumb) thumbnails.Add(fileName);
                    else images.Add(fileName);
                }
            }
            else
            {
                // S3
                var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);
                if (archiveStream == null)
                {
                    _logger.LogWarning("Archive not found in object storage: {0}", book.ImageArchiveUrl);
                    return (images, thumbnails);
                }

                using var zip = new ZipArchive(archiveStream, ZipArchiveMode.Read);
                foreach (var entry in zip.Entries)
                {
                    if (string.IsNullOrEmpty(entry.Name)) continue;
                    bool isThumb = entry.FullName.StartsWith("thumbnails/", StringComparison.OrdinalIgnoreCase);
                    var fileName = entry.Name;

                    using var existing = TryGetFromCache(book.Id, fileName, isThumb);
                    if (existing == null)
                    {
                        using var es = entry.Open();
                        using var ms = new MemoryStream();
                        es.CopyTo(ms);
                        ms.Position = 0;
                        SaveFileToCache(book.Id, fileName, isThumb, ms);
                    }

                    if (isThumb) thumbnails.Add(fileName);
                    else images.Add(fileName);
                }
            }

            return (images, thumbnails);
        }

        /// <summary>
        /// Для "legacy" (S3 или локальные папки): получаем все имена,
        /// скачиваем и складываем в кэш, возвращаем списки.
        /// </summary>
        private async Task<(List<string> images, List<string> thumbnails)> FetchLegacyImagesAndCache(
            int bookId, bool useLocalFiles)
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
                {
                    foreach (var path in Directory.GetFiles(imagesPath))
                    {
                        var fileName = Path.GetFileName(path);
                        using var existing = TryGetFromCache(bookId, fileName, false);
                        if (existing == null)
                        {
                            using var fs = File.OpenRead(path);
                            using var ms = new MemoryStream();
                            fs.CopyTo(ms);
                            ms.Position = 0;
                            SaveFileToCache(bookId, fileName, false, ms);
                        }
                        images.Add(fileName);
                    }
                }

                if (Directory.Exists(thumbsPath))
                {
                    foreach (var path in Directory.GetFiles(thumbsPath))
                    {
                        var fileName = Path.GetFileName(path);
                        using var existing = TryGetFromCache(bookId, fileName, true);
                        if (existing == null)
                        {
                            using var fs = File.OpenRead(path);
                            using var ms = new MemoryStream();
                            fs.CopyTo(ms);
                            ms.Position = 0;
                            SaveFileToCache(bookId, fileName, true, ms);
                        }
                        thumbs.Add(fileName);
                    }
                }
            }
            else
            {
                // S3
                var keysImg = await _yandexStorageService.GetImageKeysAsync(bookId);
                var keysThumb = await _yandexStorageService.GetThumbnailKeysAsync(bookId);

                foreach (var key in keysImg)
                {
                    using var existing = TryGetFromCache(bookId, key, false);
                    if (existing == null)
                    {
                        var stream = await _yandexStorageService.GetImageStreamAsync($"{bookId}/images/{key}");
                        if (stream != null)
                        {
                            using var ms = new MemoryStream();
                            await stream.CopyToAsync(ms);
                            ms.Position = 0;
                            SaveFileToCache(bookId, key, false, ms);
                        }
                    }
                    images.Add(key);
                }

                foreach (var key in keysThumb)
                {
                    using var existing = TryGetFromCache(bookId, key, true);
                    if (existing == null)
                    {
                        var stream = await _yandexStorageService.GetThumbnailStreamAsync($"{bookId}/thumbnails/{key}");
                        if (stream != null)
                        {
                            using var ms = new MemoryStream();
                            await stream.CopyToAsync(ms);
                            ms.Position = 0;
                            SaveFileToCache(bookId, key, true, ms);
                        }
                    }
                    thumbs.Add(key);
                }
            }

            return (images, thumbs);
        }

        // ==================================================================================
        //  Чтение одного файла из архива
        // ==================================================================================
        private async Task<ActionResult?> GetFileFromArchive(
            BookDetailDto book,
            string entryPath,
            bool useLocalFiles)
        {
            // Сначала проверим в кэше
            var fileName = Path.GetFileName(entryPath);
            bool isThumb = entryPath.StartsWith("thumbnails/", StringComparison.OrdinalIgnoreCase);

            var cached = TryGetFromCache(book.Id, fileName, isThumb);
            if (cached != null)
            {
                _logger.LogDebug("GetFileFromArchive: {0}/{1} из кэша", book.Id, fileName);
                return new FileStreamResult(cached, "image/jpeg");
            }

            if (useLocalFiles)
            {
                if (!File.Exists(book.ImageArchiveUrl))
                    return new NotFoundResult();

                using var zip = ZipFile.OpenRead(book.ImageArchiveUrl);
                var entry = zip.GetEntry(entryPath);
                if (entry == null) return new NotFoundResult();

                using var es = entry.Open();
                using var ms = new MemoryStream();
                await es.CopyToAsync(ms);
                ms.Position = 0;
                SaveFileToCache(book.Id, fileName, isThumb, ms);
                ms.Position = 0;
                return new FileStreamResult(ms, "image/jpeg");
            }
            else
            {
                var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);
                if (archiveStream == null) return new NotFoundResult();

                using var zip = new ZipArchive(archiveStream, ZipArchiveMode.Read);
                var entry = zip.GetEntry(entryPath);
                if (entry == null) return new NotFoundResult();

                using var es = entry.Open();
                using var ms = new MemoryStream();
                await es.CopyToAsync(ms);
                ms.Position = 0;
                SaveFileToCache(book.Id, fileName, isThumb, ms);
                ms.Position = 0;
                return new FileStreamResult(ms, "image/jpeg");
            }
        }

        // ==================================================================================
        //  Legacy: один файл (S3 или локальные)
        // ==================================================================================
        private async Task<ActionResult?> GetLegacyImageAsync(
            int bookId,
            string fileName,
            bool isThumbnail,
            bool useLocalFiles)
        {
            var cached = TryGetFromCache(bookId, fileName, isThumbnail);
            if (cached != null)
            {
                return new FileStreamResult(cached, "image/jpeg");
            }

            if (useLocalFiles)
            {
                string basePath = Path.Combine(AppContext.BaseDirectory, "books_photos", bookId.ToString());
                var folder = isThumbnail ? "thumbnails" : "images";
                var path = Path.Combine(basePath, folder, fileName);

                if (!File.Exists(path))
                    return new NotFoundResult();

                using var fs = File.OpenRead(path);
                using var ms = new MemoryStream();
                fs.CopyTo(ms);
                ms.Position = 0;
                SaveFileToCache(bookId, fileName, isThumbnail, ms);
                ms.Position = 0;
                return new FileStreamResult(ms, "image/jpeg");
            }
            else
            {
                var prefix = isThumbnail ? "thumbnails" : "images";
                var key = $"{bookId}/{prefix}/{fileName}";

                var stream = isThumbnail
                    ? await _yandexStorageService.GetThumbnailStreamAsync(key)
                    : await _yandexStorageService.GetImageStreamAsync(key);

                if (stream == null)
                    return new NotFoundResult();

                using var ms = new MemoryStream();
                await stream.CopyToAsync(ms);
                ms.Position = 0;
                SaveFileToCache(bookId, fileName, isThumbnail, ms);
                ms.Position = 0;

                return new FileStreamResult(ms, "image/jpeg");
            }
        }

        // ==================================================================================
        //  Загрузка из URL (с таймаутом)
        // ==================================================================================
        private async Task<MemoryStream?> DownloadImageFromUrlAsync(string url, TimeSpan timeout)
        {
            try
            {
                using var cts = new CancellationTokenSource(timeout);
                var resp = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, cts.Token);
                if (!resp.IsSuccessStatusCode)
                    return null;

                var ms = new MemoryStream();
                await resp.Content.CopyToAsync(ms);
                ms.Position = 0;
                return ms;
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Не удалось скачать изображение {0}: {1}", url, ex.Message);
                return null;
            }
        }

        private string? FindByFileName(List<string>? urls, string targetFileName)
        {
            if (urls == null) return null;
            foreach (var u in urls)
            {
                var fn = Path.GetFileName(u);
                if (fn.Equals(targetFileName, StringComparison.OrdinalIgnoreCase))
                    return u;
            }
            return null;
        }

        // ==================================================================================
        //  КЭШ: запись / чтение / удаление устаревших
        // ==================================================================================
        private FileStream? TryGetFromCache(int bookId, string fileName, bool isThumbnail)
        {
            lock (_cacheLock)
            {
                string path = GetCacheFilePath(bookId, fileName, isThumbnail);
                if (!File.Exists(path))
                    return null;

                var fi = new FileInfo(path);
                var age = DateTime.UtcNow - fi.LastWriteTimeUtc;
                if (age > _cacheLifetime)
                {
                    // устарел
                    try
                    {
                        File.Delete(path);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning("Ошибка удаления устаревшего файла кэша {0}: {1}", path, ex.Message);
                    }
                    return null;
                }

                try
                {
                    return new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Ошибка при чтении файла кэша {0}: {1}", path, ex.Message);
                    return null;
                }
            }
        }

        private void SaveFileToCache(int bookId, string fileName, bool isThumbnail, MemoryStream source)
        {
            lock (_cacheLock)
            {
                source.Position = 0;
                string path = GetCacheFilePath(bookId, fileName, isThumbnail);

                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                    using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
                    source.CopyTo(fs);
                    fs.Flush();
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Ошибка сохранения файла в кэш {0}: {1}", path, ex.Message);
                }
            }
        }

        private string GetCacheFilePath(int bookId, string fileName, bool isThumbnail)
        {
            var folder = isThumbnail ? "thumbnails" : "images";
            return Path.Combine(_cacheRootPath, bookId.ToString(), folder, fileName);
        }
    }
}
