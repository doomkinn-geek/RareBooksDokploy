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
        /// <summary>
        /// Возвращает списки доступных изображений и миниатюр (только названия файлов).
        /// Фронтенд может потом вызывать /books/{id}/images/{filename}.
        /// </summary>
        Task<(List<string> images, List<string> thumbnails)> GetBookImagesAsync(
            BookDetailDto book,
            bool hasSubscription,
            bool useLocalFiles);

        /// <summary>
        /// Возвращает конкретный полноразмерный файл (blob).
        /// </summary>
        Task<ActionResult?> GetImageAsync(
            BookDetailDto book,
            string imageName,
            bool hasSubscription,
            bool useLocalFiles);

        /// <summary>
        /// Возвращает конкретную миниатюру (blob).
        /// </summary>
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

        // Общий HttpClient для скачивания внешних URL
        private static readonly HttpClient _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(10)
        };

        // ------------ НАСТРОЙКИ КЭША ------------
        private readonly string? _cacheRootPath;
        private readonly bool _cacheEnabled = false;

        private readonly TimeSpan? _cacheLifetime;    // Нужно только для удаления устаревших файлов
        private readonly long? _maxCacheSizeBytes;   // Тоже для cleanup-сервиса

        private static readonly object _cacheLock = new object();

        public BookImagesService(
            ILogger<BookImagesService> logger,
            IYandexStorageService yandexStorageService,
            IConfiguration configuration)
        {
            _logger = logger;
            _yandexStorageService = yandexStorageService;

            // Читаем CacheSettings, если есть
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
            // 1) Если нет подписки — возвращаем пустой список
            // (Хотя контроллер уже это проверил, дублируем логику для безопасности)
            if (!hasSubscription)
            {
                return (new List<string>(), new List<string>());
            }

            // 2) Малоценные книги: только внешние URL
            if (book.IsLessValuable)
            {
                // Берём имена файлов из URL
                // Если url пустые — значит картинок нет
                var imageNames = book.ImageUrls?
                    .Select(url => Path.GetFileName(url))
                    .ToList() ?? new List<string>();

                var thumbNames = book.ThumbnailUrls?
                    .Select(url => Path.GetFileName(url))
                    .ToList() ?? new List<string>();

                return (imageNames, thumbNames);
            }
            else
            {
                // 3) Обычные книги
                if (book.IsImagesCompressed)
                {
                    // Сжато => откроем архив (локально или из Object Storage),
                    // прочитаем список файлов (entry.FullName).
                    return await FetchArchiveFileList(book, useLocalFiles);
                }
                else
                {
                    // "Legacy" => прочитаем список из папки или Object Storage
                    return await FetchLegacyFileList(book.Id, useLocalFiles);
                }
            }
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
            // Для всех книг (малоценных/обычных) нужна подписка:
            if (!hasSubscription)
            {
                return new ForbidResult("Подписка требуется для просмотра изображений.");
            }

            // Сначала смотрим в кэше
            var cachedStream = TryGetFromCache(book.Id, imageName, isThumbnail: false);
            if (cachedStream != null)
            {
                return new FileStreamResult(cachedStream, "image/jpeg");
            }

            // Разделяем логику:
            if (book.IsLessValuable)
            {
                // Малоценные => только внешние URL
                var foundUrl = FindByFileName(book.ImageUrls, imageName);
                if (foundUrl == null)
                {
                    _logger.LogWarning("Не найден внешний URL '{0}' для малоценной книги {1}", imageName, book.Id);
                    return new NotFoundResult();
                }

                // Скачиваем из внешнего URL + кладём в кэш
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
                // Обычная книга
                if (book.IsImagesCompressed)
                {
                    // Из архива
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
            // Тоже нужна подписка
            if (!hasSubscription)
            {
                return new ForbidResult("Подписка требуется для просмотра миниатюр.");
            }

            // проверяем кэш
            var cachedStream = TryGetFromCache(book.Id, thumbName, isThumbnail: true);
            if (cachedStream != null)
            {
                return new FileStreamResult(cachedStream, "image/jpeg");
            }

            if (book.IsLessValuable)
            {
                // Малоценная => только внешние URL
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
                // Обычная
                if (book.IsImagesCompressed)
                {
                    // Отдаём из архива
                    return await GetFileFromArchive(book, $"thumbnails/{thumbName}", useLocalFiles);
                }
                else
                {
                    // Legacy
                    return await GetLegacyImageAsync(book.Id, thumbName, isThumbnail: true, useLocalFiles);
                }
            }
        }

        // ----------------------------------------------------------------------
        //  Вспомогательные методы чтения СПИСКОВ из архива / legacy-папок
        // ----------------------------------------------------------------------
        private async Task<(List<string> images, List<string> thumbnails)> FetchArchiveFileList(
            BookDetailDto book,
            bool useLocalFiles)
        {
            var images = new List<string>();
            var thumbs = new List<string>();

            if (string.IsNullOrWhiteSpace(book.ImageArchiveUrl))
            {
                // Архив не задан
                return (images, thumbs);
            }

            if (useLocalFiles)
            {
                // Локальный ZIP
                if (!File.Exists(book.ImageArchiveUrl))
                    return (images, thumbs);

                using var zip = ZipFile.OpenRead(book.ImageArchiveUrl);
                foreach (var entry in zip.Entries)
                {
                    if (entry.FullName.StartsWith("images/") && !string.IsNullOrEmpty(entry.Name))
                        images.Add(entry.Name);
                    else if (entry.FullName.StartsWith("thumbnails/") && !string.IsNullOrEmpty(entry.Name))
                        thumbs.Add(entry.Name);
                }
            }
            else
            {
                // В Object Storage
                var archiveStream = await _yandexStorageService.GetArchiveStreamAsync(book.ImageArchiveUrl);
                if (archiveStream == null) return (images, thumbs);

                using var zip = new ZipArchive(archiveStream, ZipArchiveMode.Read);
                foreach (var entry in zip.Entries)
                {
                    if (entry.FullName.StartsWith("images/") && !string.IsNullOrEmpty(entry.Name))
                        images.Add(entry.Name);
                    else if (entry.FullName.StartsWith("thumbnails/") && !string.IsNullOrEmpty(entry.Name))
                        thumbs.Add(entry.Name);
                }
            }

            return (images, thumbs);
        }

        private async Task<(List<string> images, List<string> thumbnails)> FetchLegacyFileList(
            int bookId,
            bool useLocalFiles)
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
                    var files = Directory.GetFiles(imagesPath);
                    foreach (var f in files)
                    {
                        images.Add(Path.GetFileName(f));
                    }
                }
                if (Directory.Exists(thumbsPath))
                {
                    var files = Directory.GetFiles(thumbsPath);
                    foreach (var f in files)
                    {
                        thumbs.Add(Path.GetFileName(f));
                    }
                }
            }
            else
            {
                // Object Storage
                var keysImg = await _yandexStorageService.GetImageKeysAsync(bookId);
                var keysThumb = await _yandexStorageService.GetThumbnailKeysAsync(bookId);

                images.AddRange(keysImg);
                thumbs.AddRange(keysThumb);
            }

            return (images, thumbs);
        }

        // ----------------------------------------------------------------------
        //  Вспомогательные методы получения ОТДЕЛЬНОГО файла
        // ----------------------------------------------------------------------
        private async Task<ActionResult?> GetFileFromArchive(
            BookDetailDto book,
            string entryPath,
            bool useLocalFiles)
        {
            var isThumb = entryPath.StartsWith("thumbnails/");
            var fileName = Path.GetFileName(entryPath);

            // Смотрим кэш
            var cachedStream = TryGetFromCache(book.Id, fileName, isThumb);
            if (cachedStream != null)
            {
                return new FileStreamResult(cachedStream, "image/jpeg");
            }

            if (string.IsNullOrWhiteSpace(book.ImageArchiveUrl))
                return new NotFoundResult();

            if (useLocalFiles)
            {
                if (!File.Exists(book.ImageArchiveUrl))
                    return new NotFoundResult();

                using var zip = ZipFile.OpenRead(book.ImageArchiveUrl);
                var entry = zip.GetEntry(entryPath);
                if (entry == null)
                    return new NotFoundResult();

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
                if (archiveStream == null)
                    return new NotFoundResult();

                using var zip = new ZipArchive(archiveStream, ZipArchiveMode.Read);
                var entry = zip.GetEntry(entryPath);
                if (entry == null)
                    return new NotFoundResult();

                using var es = entry.Open();
                using var ms = new MemoryStream();
                await es.CopyToAsync(ms);
                ms.Position = 0;

                SaveFileToCache(book.Id, fileName, isThumb, ms);
                ms.Position = 0;

                return new FileStreamResult(ms, "image/jpeg");
            }
        }

        private async Task<ActionResult?> GetLegacyImageAsync(
            int bookId,
            string fileName,
            bool isThumbnail,
            bool useLocalFiles)
        {
            // кэш?
            var cachedStream = TryGetFromCache(bookId, fileName, isThumbnail);
            if (cachedStream != null)
            {
                return new FileStreamResult(cachedStream, "image/jpeg");
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

                using var ms = new MemoryStream();
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

                var ms = new MemoryStream();
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
            return urls.FirstOrDefault(u => Path.GetFileName(u)
                .Equals(fileName, StringComparison.OrdinalIgnoreCase));
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
                    // Возвращаем сразу FileStream
                    // (CacheCleanupService сам удаляет просроченные файлы)
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
                string path = GetCacheFilePath(bookId, fileName, isThumbnail);
                try
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                    using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);

                    source.Position = 0;
                    source.CopyTo(fs);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning("Ошибка сохранения в кэш {0}: {1}", path, ex.Message);
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
