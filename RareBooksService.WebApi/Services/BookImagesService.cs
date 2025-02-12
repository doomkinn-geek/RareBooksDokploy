using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
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

        // HttpClient для малоценных книг (внешние URL)
        private static readonly HttpClient _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(10)
        };

        // ------------ НАСТРОЙКИ КЭША ------------
        private readonly string? _cacheRootPath;
        private readonly bool _cacheEnabled = false;

        // Параметры для CacheCleanupService
        private readonly TimeSpan? _cacheLifetime;
        private readonly long? _maxCacheSizeBytes;

        private static readonly object _cacheLock = new object();

        public BookImagesService(
            ILogger<BookImagesService> logger,
            IYandexStorageService yandexStorageService,
            IConfiguration configuration)
        {
            _logger = logger;
            _yandexStorageService = yandexStorageService;

            var cacheSettingsSection = configuration.GetSection("CacheSettings");
            if (cacheSettingsSection.Exists())
            {
                var c = cacheSettingsSection.Get<CacheSettings>();
                if (c != null)
                {
                    _cacheRootPath = Path.Combine(
                        AppContext.BaseDirectory,
                        c.LocalCachePath ?? "image_cache"
                    );
                    _cacheLifetime = TimeSpan.FromDays(c.DaysToKeep);
                    _maxCacheSizeBytes = (long)c.MaxCacheSizeMB * 1024 * 1024;

                    Directory.CreateDirectory(_cacheRootPath);
                    _cacheEnabled = true;
                }
            }

            if (_cacheEnabled)
            {
                _logger.LogInformation(
                    "BookImagesService: кэш включен. Путь={_cacheRootPath}, срок={_cacheLifetime}, макс.размер={_maxCacheSizeBytes}",
                    _cacheRootPath, _cacheLifetime, _maxCacheSizeBytes
                );
            }
            else
            {
                _logger.LogWarning("BookImagesService: секция CacheSettings не найдена или некорректна. Кэширование отключено.");
            }
        }

        // ======================================================================
        //   1) Получение списков файлов (названий)
        // ======================================================================
        public async Task<(List<string> images, List<string> thumbnails)> GetBookImagesAsync(
            BookDetailDto book,
            bool hasSubscription,
            bool useLocalFiles)
        {
            if (!hasSubscription)
            {
                return (new List<string>(), new List<string>());
            }

            // Извлекаем fileName, отрезая query-параметры
            string ExtractCleanFileName(string url)
            {
                var name = Path.GetFileName(url);
                if (string.IsNullOrEmpty(name)) return string.Empty;

                var idx = name.IndexOfAny(new char[] { '?', '#' });
                if (idx >= 0)
                {
                    name = name.Substring(0, idx);
                }
                return name;
            }

            var images = (book.ImageUrls ?? new List<string>())
                .Select(url => ExtractCleanFileName(url))
                .Where(name => !string.IsNullOrEmpty(name))
                .ToList();

            var thumbnails = (book.ThumbnailUrls ?? new List<string>())
                .Select(url => ExtractCleanFileName(url))
                .Where(name => !string.IsNullOrEmpty(name))
                .ToList();

            return (images, thumbnails);
        }

        // ======================================================================
        //   2) Получение ОДНОГО полноразмерного изображения
        // ======================================================================
        public async Task<ActionResult?> GetImageAsync(
            BookDetailDto book,
            string imageName,
            bool hasSubscription,
            bool useLocalFiles)
        {
            if (!hasSubscription)
            {
                return new ForbidResult("Подписка требуется для просмотра изображений.");
            }

            var cachedStream = TryGetFromCache(book.Id, imageName, isThumbnail: false);
            if (cachedStream != null)
            {
                return new FileStreamResult(cachedStream, "image/jpeg");
            }

            if (book.IsLessValuable)
            {
                var foundUrl = FindByFileName(book.ImageUrls, imageName);
                if (foundUrl == null)
                {
                    _logger.LogWarning("Не найден внешний URL '{0}' для малоценной книги {1}", imageName, book.Id);
                    return new NotFoundResult();
                }

                var stream = await DownloadImageFromUrlAsync(foundUrl);
                if (stream == null)
                {
                    return new NotFoundResult();
                }

                SaveFileToCache(book.Id, imageName, false, stream);
                stream.Position = 0;
                return new FileStreamResult(stream, "image/jpeg");
            }
            else
            {
                if (book.IsImagesCompressed)
                {
                    // Извлекаем из ZIP (с кэшированием самого архива)
                    return await GetFileFromArchive(book, $"images/{imageName}", useLocalFiles);
                }
                else
                {
                    // Legacy
                    return await GetLegacyImageAsync(book.Id, imageName, isThumbnail: false, useLocalFiles);
                }
            }
        }

        // ======================================================================
        //   3) Получение ОДНОЙ миниатюры
        // ======================================================================
        public async Task<ActionResult?> GetThumbnailAsync(
            BookDetailDto book,
            string thumbName,
            bool hasSubscription,
            bool useLocalFiles)
        {
            if (!hasSubscription)
            {
                return new ForbidResult("Подписка требуется для просмотра миниатюр.");
            }

            var cachedStream = TryGetFromCache(book.Id, thumbName, isThumbnail: true);
            if (cachedStream != null)
            {
                return new FileStreamResult(cachedStream, "image/jpeg");
            }

            if (book.IsLessValuable)
            {
                var foundUrl = FindByFileName(book.ThumbnailUrls, thumbName);
                if (foundUrl == null)
                {
                    return new NotFoundResult();
                }

                var stream = await DownloadImageFromUrlAsync(foundUrl);
                if (stream == null)
                {
                    return new NotFoundResult();
                }

                SaveFileToCache(book.Id, thumbName, true, stream);
                stream.Position = 0;
                return new FileStreamResult(stream, "image/jpeg");
            }
            else
            {
                if (book.IsImagesCompressed)
                {
                    return await GetFileFromArchive(book, $"thumbnails/{thumbName}", useLocalFiles);
                }
                else
                {
                    return await GetLegacyImageAsync(book.Id, thumbName, isThumbnail: true, useLocalFiles);
                }
            }
        }

        // ----------------------------------------------------------------------
        //  Методы чтения ОТДЕЛЬНОГО файла из архива / legacy
        // ----------------------------------------------------------------------
        private async Task<ActionResult?> GetFileFromArchive(
            BookDetailDto book,
            string entryPath,
            bool useLocalFiles)
        {
            var isThumb = entryPath.StartsWith("thumbnails/");
            var fileName = Path.GetFileName(entryPath);

            // 1) Проверяем: нет ли файла в кэше картинок
            var cachedStream = TryGetFromCache(book.Id, fileName, isThumb);
            if (cachedStream != null)
                return new FileStreamResult(cachedStream, "image/jpeg");

            // 2) Скачиваем / находим локальный ZIP (кэшируем его), 
            //    затем извлекаем нужный файл
            var localZipFolder = Path.Combine(_cacheRootPath!, "_compressed_images");
            Directory.CreateDirectory(localZipFolder);
            var localZipPath = Path.Combine(localZipFolder, $"{book.Id}.zip");

            if (!File.Exists(localZipPath))
            {
                // Если нет — качаем из Object Storage или копируем локально
                if (!useLocalFiles)
                {
                    if (string.IsNullOrWhiteSpace(book.ImageArchiveUrl))
                        return new NotFoundResult();

                    using var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);
                    if (archiveStream == null)
                        return new NotFoundResult();

                    using var fs = File.Create(localZipPath);
                    await archiveStream.CopyToAsync(fs);
                }
                else
                {
                    // Копируем локальный архив в кэш
                    if (!File.Exists(book.ImageArchiveUrl))
                        return new NotFoundResult();

                    File.Copy(book.ImageArchiveUrl, localZipPath, overwrite: true);
                }
            }

            // 3) Читаем локальный ZIP
            using var zip = ZipFile.OpenRead(localZipPath);
            var entry = zip.GetEntry(entryPath);
            if (entry == null)
                return new NotFoundResult();

            // 4) Считываем entry в MemoryStream (без using - нам нужно отдать этот ms)
            using var es = entry.Open();
            MemoryStream ms = new MemoryStream();
            await es.CopyToAsync(ms);
            ms.Position = 0;

            // 5) Кэшируем результат (одиночный файл)
            SaveFileToCache(book.Id, fileName, isThumb, ms);
            ms.Position = 0;

            return new FileStreamResult(ms, "image/jpeg");
        }

        private async Task<ActionResult?> GetLegacyImageAsync(
            int bookId,
            string fileName,
            bool isThumbnail,
            bool useLocalFiles)
        {
            var cachedStream = TryGetFromCache(bookId, fileName, isThumbnail);
            if (cachedStream != null)
            {
                return new FileStreamResult(cachedStream, "image/jpeg");
            }

            if (useLocalFiles)
            {
                // Локальный файл
                string basePath = Path.Combine(AppContext.BaseDirectory, "books_photos", bookId.ToString());
                var folder = isThumbnail ? "thumbnails" : "images";
                var path = Path.Combine(basePath, folder, fileName);

                if (!File.Exists(path))
                    return new NotFoundResult();

                // Считываем файл в MemoryStream
                using var fs = File.OpenRead(path);
                MemoryStream ms = new MemoryStream();
                await fs.CopyToAsync(ms);
                ms.Position = 0;

                SaveFileToCache(bookId, fileName, isThumbnail, ms);
                ms.Position = 0;

                return new FileStreamResult(ms, "image/jpeg");
            }
            else
            {
                // Object Storage
                var prefix = isThumbnail ? "thumbnails" : "images";
                var key = $"{bookId}/{prefix}/{fileName}";

                var stream = isThumbnail
                    ? await _yandexStorageService.GetThumbnailStreamAsync(key)
                    : await _yandexStorageService.GetImageStreamAsync(key);

                if (stream == null)
                    return new NotFoundResult();

                MemoryStream ms = new MemoryStream();
                await stream.CopyToAsync(ms);
                ms.Position = 0;

                SaveFileToCache(bookId, fileName, isThumbnail, ms);
                ms.Position = 0;

                return new FileStreamResult(ms, "image/jpeg");
            }
        }

        // ----------------------------------------------------------------------
        //  Методы скачивания файла из внешних URL (для малоценных книг)
        // ----------------------------------------------------------------------
        private async Task<MemoryStream?> DownloadImageFromUrlAsync(string url)
        {
            try
            {
                var resp = await _httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                if (!resp.IsSuccessStatusCode)
                    return null;

                MemoryStream ms = new MemoryStream();
                await resp.Content.CopyToAsync(ms);
                ms.Position = 0;
                return ms;
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Ошибка загрузки {0}: {1}", url, ex.Message);
                return null;
            }
        }

        /// <summary>
        /// Ищет среди списка URL тот, который заканчивается нужным fileName
        /// </summary>
        private string? FindByFileName(List<string>? urls, string fileName)
        {
            if (urls == null) return null;
            return urls.FirstOrDefault(u =>
                Path.GetFileName(u).Equals(fileName, StringComparison.OrdinalIgnoreCase)
            );
        }

        // ----------------------------------------------------------------------
        //  Методы кэша
        // ----------------------------------------------------------------------
        private FileStream? TryGetFromCache(int bookId, string fileName, bool isThumbnail)
        {
            if (!_cacheEnabled) return null;

            lock (_cacheLock)
            {
                var path = GetCacheFilePath(bookId, fileName, isThumbnail);
                if (!File.Exists(path))
                    return null;

                try
                {
                    // Не используем using, т.к. поток нужен ASP.NET для отправки
                    return new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Ошибка чтения кэша {0}: {1}", path, ex.Message);
                    return null;
                }
            }
        }

        private void SaveFileToCache(int bookId, string fileName, bool isThumbnail, MemoryStream source)
        {
            if (!_cacheEnabled) return;

            lock (_cacheLock)
            {
                var path = GetCacheFilePath(bookId, fileName, isThumbnail);
                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(path)!);

                    // Записываем полученный MemoryStream в файл
                    using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
                    source.Position = 0;
                    source.CopyTo(fs);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Ошибка сохранения в кэшт {0}: {1}", path, ex.Message);
                }
            }
        }

        private string GetCacheFilePath(int bookId, string fileName, bool isThumbnail)
        {
            var folder = isThumbnail ? "thumbnails" : "images";
            return Path.Combine(_cacheRootPath!, bookId.ToString(), folder, fileName);
        }
    }
}
