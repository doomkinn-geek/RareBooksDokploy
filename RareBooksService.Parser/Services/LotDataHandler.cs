﻿using AutoMapper;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.FromMeshok;
using RareBooksService.Data;
using System.IO.Compression;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Sockets;
using System.Text.Json;

namespace RareBooksService.Parser.Services
{
    public class TypeOfAccessImages
    {
        public bool UseLocalFiles { get; set; }
        public string LocalPathOfImages { get; set; }
    }

    public interface ILotDataHandler
    {
        Task SaveLotDataAsync(MeshokBook lotData, int categoryId,
                              string categoryName = "unknown",
                              bool downloadImages = true,
                              bool isLessValuableLot = false);

        event Action<int, string> ProgressChanged;
    }

    public class LotDataHandler : ILotDataHandler, IDisposable
    {
        private readonly BooksDbContext _context;
        private readonly IMapper _mapper;
        private readonly ILotDataWebService _lotDataService;
        private readonly IYandexStorageService _yandexStorageService;
        private readonly TypeOfAccessImages _imageStorageOptions;
        private readonly ILogger<LotDataHandler> _logger;
        private readonly CookieContainer _cookieContainer;
        private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(2);
        private readonly Random _random = new Random();
        private bool _cookiesInitialized = false;

        private readonly IProgressReporter _progressReporter;

        private readonly string _appSettingsPath;

        public event Action<int, string> ProgressChanged;
        private void OnProgressChanged(int lotId, string message)
        {
            ProgressChanged?.Invoke(lotId, message);
        }

        public LotDataHandler(
            BooksDbContext context,
            IMapper mapper,
            ILotDataWebService lotDataService,
            IYandexStorageService yandexStorageService,
            IOptions<TypeOfAccessImages> imageStorageOptions,
            ILogger<LotDataHandler> logger,
            IProgressReporter progressReporter)
        {
            _appSettingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");

            _context = context;
            _mapper = mapper;
            _lotDataService = lotDataService;
            _yandexStorageService = yandexStorageService;
            _imageStorageOptions = imageStorageOptions.Value;
            _logger = logger;
            _cookieContainer = new CookieContainer();

            _progressReporter = progressReporter;   

            var jsonText = File.ReadAllText(_appSettingsPath);
            using var doc = JsonDocument.Parse(jsonText);
            var root = doc.RootElement;

            // 2) Ищем секцию "YandexCloud"
            if (!root.TryGetProperty("TypeOfAccessImages", out var typeOfAccessImagesElement))
                throw new Exception("Section 'TypeOfAccessImages' not found in appsettings.json");

            // 3) Достаём поля AccessKey / SecretKey / ServiceUrl / BucketName
            var useLocal = typeOfAccessImagesElement.GetProperty("UseLocalFiles").GetString();
            var localPath = typeOfAccessImagesElement.GetProperty("LocalPathOfImages").GetString();            

            // 4) Проверяем
            //if (string.IsNullOrEmpty(useLocal) ||
            //    string.IsNullOrEmpty(localPath))
            //{
            //    throw new ArgumentException("Invalid TypeOfAccessImages config in appsettings.json");
            //}
            _imageStorageOptions.LocalPathOfImages = localPath;
            _imageStorageOptions.UseLocalFiles = Convert.ToBoolean(useLocal);

            if (string.IsNullOrEmpty(_imageStorageOptions.LocalPathOfImages))
                _imageStorageOptions.UseLocalFiles = false;
        }

        // Инициализация cookies
        public async Task EnsureCookiesInitializedAsync()
        {
            if (!_cookiesInitialized)
            {
                await InitializeCookiesAsync("https://meshok.net");
                _cookiesInitialized = true;
            }
        }

        private async Task InitializeCookiesAsync(string url)
        {
            try
            {
                var baseUri = new Uri(url).GetLeftPart(UriPartial.Authority);
                using var handler = new HttpClientHandler
                {
                    CookieContainer = _cookieContainer,
                    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
                    SslProtocols = System.Security.Authentication.SslProtocols.Tls12 | System.Security.Authentication.SslProtocols.Tls13,
                    UseCookies = true,
                    AllowAutoRedirect = true
                };

                using var httpClient = new HttpClient(handler);
                httpClient.DefaultRequestHeaders.Accept.Clear();
                httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("text/html"));
                httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/xhtml+xml"));
                httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("image/avif"));
                httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("image/webp"));
                
                // Более реалистичный User-Agent
                httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
                
                // Добавляем другие заголовки, имитирующие браузер
                httpClient.DefaultRequestHeaders.Add("Accept-Language", "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7");
                httpClient.DefaultRequestHeaders.Add("Cache-Control", "max-age=0");
                httpClient.DefaultRequestHeaders.Add("sec-ch-ua", "\"Not A(Brand\";v=\"99\", \"Google Chrome\";v=\"121\", \"Chromium\";v=\"121\"");
                httpClient.DefaultRequestHeaders.Add("sec-ch-ua-mobile", "?0");
                httpClient.DefaultRequestHeaders.Add("sec-ch-ua-platform", "\"Windows\"");
                httpClient.DefaultRequestHeaders.Add("Sec-Fetch-Dest", "document");
                httpClient.DefaultRequestHeaders.Add("Sec-Fetch-Mode", "navigate");
                httpClient.DefaultRequestHeaders.Add("Sec-Fetch-Site", "none");
                httpClient.DefaultRequestHeaders.Add("Sec-Fetch-User", "?1");
                
                // Добавляем также заголовок Upgrade-Insecure-Requests
                httpClient.DefaultRequestHeaders.Add("Upgrade-Insecure-Requests", "1");

                _logger.LogInformation("Пытаемся инициализировать cookies для домена {Domain}", baseUri);
                var response = await httpClient.GetAsync(baseUri);
                response.EnsureSuccessStatusCode();

                // Логгируем полученные cookies для диагностики
                var cookies = _cookieContainer.GetCookies(new Uri(baseUri)).Cast<Cookie>().ToList();
                _logger.LogInformation("Получено {count} cookies от {domain}", cookies.Count, baseUri);
                foreach (var cookie in cookies)
                {
                    _logger.LogDebug("Cookie: {name}={value}, domain={domain}, path={path}, expires={expires}", 
                        cookie.Name, cookie.Value, cookie.Domain, cookie.Path, cookie.Expires);
                }

                _logger.LogInformation("Успешно инициализированы cookies для домена {Domain}", baseUri);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при инициализации cookies для URL {Url}", url);
            }
        }        

        public async Task SaveLotDataAsync(
                    MeshokBook lotData,
                    int categoryId,
                    string categoryName = "unknown",
                    bool downloadImages = true,
                    bool isLessValuableLot = false)
        {
            try
            {
                await EnsureCookiesInitializedAsync();

                OnProgressChanged(lotData.id, $"Начало обработки лота {lotData.id}.");
                _logger.LogInformation("Обработка лота с ID {LotId}", lotData.id);

                // Проверяем, есть ли уже такой лот в БД
                var existingBook = await _context.BooksInfo
                                                 .Include(b => b.Category)
                                                 .FirstOrDefaultAsync(b => b.Id == lotData.id);

                // Получаем (или создаём) сущность Category
                var category = await GetOrCreateCategoryAsync(categoryId, categoryName);

                // Содержимое описания
                var descriptionFromWeb = await _lotDataService.GetBookDescriptionAsync(lotData.id);
                var normalizedDesc = descriptionFromWeb?.ToLower() ?? string.Empty;

                // Пытаемся вычислить год из описания или заголовка
                int? year = PublishingYearExtractor.ExtractYearFromDescription(descriptionFromWeb)
                          ?? PublishingYearExtractor.ExtractYearFromDescription(lotData.title);

                // Если записи нет в БД, создаём новую
                if (existingBook == null)
                {
                    _logger.LogInformation("Лот {LotId} отсутствует в БД. Создаём новую запись.", lotData.id);

                    var newBook = _mapper.Map<RegularBaseBook>(lotData);

                    // Дополнительные поля, которых нет в MeshokBook напрямую
                    newBook.Category = category;
                    newBook.Type = lotData.type;
                    newBook.Description = descriptionFromWeb;
                    newBook.NormalizedDescription = normalizedDesc;
                    newBook.YearPublished = year;
                    newBook.IsLessValuable = isLessValuableLot;

                    // По умолчанию до архивации
                    newBook.IsImagesCompressed = false;
                    newBook.ImageArchiveUrl = null;

                    // Логику IsMonitored и FinalPrice определяем
                    if (lotData.beginDate == null || lotData.endDate == null)
                    {
                        newBook.IsMonitored = false;
                        newBook.FinalPrice = lotData.normalizedPrice;
                    }
                    else
                    {
                        newBook.IsMonitored = (lotData.endDate >= DateTime.UtcNow);
                        newBook.FinalPrice = (lotData.endDate < DateTime.UtcNow)
                                                ? lotData.normalizedPrice
                                                : null;
                    }

                    _context.BooksInfo.Add(newBook);
                    await _context.SaveChangesAsync();

                    // Если лот не «малоценный» и требуется скачивать изображения
                    if (!isLessValuableLot && downloadImages)
                    {
                        await ArchiveImagesForBookAsync(newBook);
                    }
                }
                else
                {
                    // ---------- Обновление существующей записи ----------
                    _logger.LogInformation("Лот {LotId} уже есть в БД. Обновляем поля.", lotData.id);

                    // Обновляем поля. Можно вручную, можно частично использовать AutoMapper.
                    // Например, так: _mapper.Map(lotData, existingBook) – но внимательно
                    // следите, чтобы не потерять нужные данные. Ниже – пример ручного обновления.

                    existingBook.Category = category;
                    existingBook.Title = lotData.title;
                    existingBook.NormalizedTitle = lotData.title?.ToLower() ?? string.Empty;

                    existingBook.Description = descriptionFromWeb;
                    existingBook.NormalizedDescription = normalizedDesc;
                    existingBook.BeginDate = lotData.beginDate ?? DateTime.MinValue;
                    existingBook.EndDate = lotData.endDate ?? DateTime.MinValue;
                    existingBook.Price = lotData.price ?? 0;
                    existingBook.City = lotData.city?.name;
                    existingBook.Type = lotData.type;
                    existingBook.Status = lotData.status ?? 0;
                    existingBook.StartPrice = (int)(lotData.startPrice ?? 0);
                    existingBook.SoldQuantity = lotData.soldQuantity ?? 0;
                    existingBook.BidsCount = lotData.bidsCount ?? 0;
                    existingBook.SellerName = lotData.seller?.displayName;
                    existingBook.PicsCount = lotData.picsCount ?? 0;
                    existingBook.YearPublished = year;
                    existingBook.IsLessValuable = isLessValuableLot;  // Можно решить, перезаписывать ли

                    // Обновляем изображения
                    existingBook.ImageUrls = lotData.pictures
                        ?.Select(p => p.url)
                        .Where(url => !string.IsNullOrEmpty(url))
                        .ToList() ?? new List<string>();

                    existingBook.ThumbnailUrls = lotData.pictures
                        ?.Select(p => p.thumbnail.x1)
                        .Where(url => !string.IsNullOrEmpty(url))
                        .ToList() ?? new List<string>();

                    existingBook.PicsRatio = lotData.pictures
                        ?.Select(p => p.ratio)
                        .ToArray() ?? new float[0];

                    // Пересчёт IsMonitored / FinalPrice
                    if (lotData.beginDate == null || lotData.endDate == null)
                    {
                        existingBook.IsMonitored = false;
                        existingBook.FinalPrice = lotData.normalizedPrice;
                    }
                    else
                    {
                        existingBook.IsMonitored = (lotData.endDate >= DateTime.UtcNow);
                        if (lotData.endDate < DateTime.UtcNow && lotData.normalizedPrice.HasValue)
                        {
                            existingBook.FinalPrice = lotData.normalizedPrice.Value;
                        }
                    }

                    // Если надо заново архивать изображения (например, «сбросить» старые) – можно:
                    //  1) Проверить наличие новых URL
                    //  2) Или всегда скачивать, если downloadImages = true
                    // Ниже – самый простой вариант: если не малоценный и downloadImages=true, то
                    // перекачать/переархивировать. Если вы не хотите перезакачивать – уберите этот блок.

                    if (!existingBook.IsLessValuable && downloadImages)
                    {
                        // Можно «сбросить» архив, чтобы пересоздать.
                        // existingBook.IsImagesCompressed = false;
                        // existingBook.ImageArchiveUrl = null;

                        await ArchiveImagesForBookAsync(existingBook);
                    }

                    // Сохраняем изменения
                    _context.BooksInfo.Update(existingBook);
                    await _context.SaveChangesAsync();
                }

                _logger.LogInformation("Лот {LotId} успешно сохранён/обновлён в БД.", lotData.id);
                _progressReporter.ReportInfo($"Лот {lotData.id} успешно сохранён/обновлён в БД.", "SaveLotDataAsync", lotData.id);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при сохранении (upsert) лота {LotId}", lotData.id);
                OnProgressChanged(lotData.id, $"Ошибка при сохранении лота {lotData.id}: {ex.Message}");
                _progressReporter.ReportError(ex, $"Ошибка при сохранении (upsert) лота {lotData.id}", "SaveLotDataAsync", lotData.id);
                throw;
            }
        }

        /// <summary>
        /// Качаем все изображения (images + thumbnails), помещаем в папки "images/" и "thumbnails/" внутри архива.
        /// После удачного архивирования -> IsImagesCompressed = true, ImageArchiveUrl = ... 
        /// </summary>
        private async Task ArchiveImagesForBookAsync(RegularBaseBook bookInfo)
        {
            int bookId = bookInfo.Id;
            var imageUrls = bookInfo.ImageUrls;
            var thumbnailUrls = bookInfo.ThumbnailUrls;

            _logger.LogInformation("Архивирование изображений для лота {LotId}", bookId);
            OnProgressChanged(bookId, $"Архивирование изображений (ID {bookId})...");
            _progressReporter.ReportInfo($"Архивирование изображений (ID {bookId})...", "ArchiveImagesForBookAsync", bookId);

            string archiveKeyOrPath = null;

            if (imageUrls != null && imageUrls?.Count != 0)
            {
                if (_imageStorageOptions.UseLocalFiles)
                {
                    archiveKeyOrPath = await CreateLocalArchiveWithFolders(bookId, imageUrls, thumbnailUrls);
                }
                else
                {
                    archiveKeyOrPath = await CreateObjectStorageArchiveWithFolders(bookId, imageUrls, thumbnailUrls);
                }
                archiveKeyOrPath = $"_compressed_images/{bookId}.zip";

                if (!string.IsNullOrEmpty(archiveKeyOrPath))
                {
                    bookInfo.IsImagesCompressed = true;
                    bookInfo.ImageArchiveUrl = archiveKeyOrPath;
                    _context.BooksInfo.Update(bookInfo);
                    await _context.SaveChangesAsync();
                }
            }            
        }

        /// <summary>
        /// Создаёт локальный архив {bookId}.zip
        ///   в котором файлы лежат в папках "images/" и "thumbnails/" 
        /// </summary>
        private async Task<string> CreateLocalArchiveWithFolders(int bookId, List<string> imageUrls, List<string> thumbnailUrls)
        {
            string tempDir = Path.Combine(Path.GetTempPath(), $"lot_{bookId}");
            Directory.CreateDirectory(tempDir);

            // Подпапки images/ и thumbnails/
            var imagesDir = Path.Combine(tempDir, "images");
            var thumbsDir = Path.Combine(tempDir, "thumbnails");
            Directory.CreateDirectory(imagesDir);
            Directory.CreateDirectory(thumbsDir);

            // Скачиваем полноразмерные
            await DownloadAllImagesAsync(imagesDir, imageUrls);
            // Скачиваем миниатюры
            await DownloadAllImagesAsync(thumbsDir, thumbnailUrls);

            // Создаём архив {bookId}.zip в LocalPathOfImages
            Directory.CreateDirectory(_imageStorageOptions.LocalPathOfImages);
            string archivePath = Path.Combine(_imageStorageOptions.LocalPathOfImages, $"{bookId}.zip");
            if (File.Exists(archivePath)) File.Delete(archivePath);

            ZipFile.CreateFromDirectory(tempDir, archivePath, CompressionLevel.Optimal, false);

            // Удаляем tempDir
            Directory.Delete(tempDir, true);

            _logger.LogInformation("Локальный архив с папками images/ и thumbnails/ создан: {ArchivePath}", archivePath);
            return archivePath;
        }

        /// <summary>
        /// Создаёт архив с images/ и thumbnails/, 
        /// загружает в ObjectStorage в _compressed_images/bookId.zip
        /// </summary>
        private async Task<string> CreateObjectStorageArchiveWithFolders(int bookId, List<string> imageUrls, List<string> thumbnailUrls)
        {
            string tempDir = Path.Combine(Path.GetTempPath(), $"lot_{bookId}");
            Directory.CreateDirectory(tempDir);

            var imagesDir = Path.Combine(tempDir, "images");
            var thumbsDir = Path.Combine(tempDir, "thumbnails");
            Directory.CreateDirectory(imagesDir);
            Directory.CreateDirectory(thumbsDir);

            // Скачиваем
            await DownloadAllImagesAsync(imagesDir, imageUrls);
            await DownloadAllImagesAsync(thumbsDir, thumbnailUrls);

            // Архивируем во временный zip
            string zipPath = Path.Combine(Path.GetTempPath(), $"lot_{bookId}.zip");
            if (File.Exists(zipPath)) File.Delete(zipPath);

            ZipFile.CreateFromDirectory(tempDir, zipPath, CompressionLevel.Optimal, false);

            // Загружаем
            string objectKey = $"_compressed_images/{bookId}.zip";
            using var archiveStream = new FileStream(zipPath, FileMode.Open, FileAccess.Read);
            await _yandexStorageService.UploadCompressedImageArchiveAsync(objectKey, archiveStream);

            // CleanUp
            Directory.Delete(tempDir, true);
            File.Delete(zipPath);

            _logger.LogInformation("ObjectStorage архив (images/thumbnails) = {Key}", objectKey);
            return objectKey;
        }

        private async Task DownloadAllImagesAsync(string targetDir, List<string> urls)
        {
            foreach (var url in urls)
            {
                try {
                    // Проверяем, является ли URL относительным путем и дополняем его базовым URL если нужно
                    string fullUrl = url;
                    if (url.StartsWith("/"))
                    {
                        fullUrl = $"https://meshok.net{url}";
                        _logger.LogDebug("Преобразован относительный URL {0} в абсолютный {1}", url, fullUrl);
                    }
                    
                    // Получаем имя файла из URL, корректно обрабатывая как абсолютные, так и относительные URL
                    string path;
                    if (url.StartsWith("/"))
                    {
                        // Для относительных URL просто берем путь как есть
                        path = url;
                    }
                    else
                    {
                        // Для абсолютных URL используем Uri
                        try {
                            var uri = new Uri(fullUrl);
                            path = uri.AbsolutePath;
                        } catch {
                            // При ошибке парсинга используем исходную строку
                            path = fullUrl;
                        }
                    }
                    
                    var filename = Path.GetFileName(path);
                    if (string.IsNullOrEmpty(filename)) {
                        _logger.LogWarning("Невозможно извлечь имя файла из URL: {0}", fullUrl);
                        continue;
                    }
                    
                    // Удаляем query-параметры из имени файла (всё после ? включительно)
                    int queryIndex = filename.IndexOf('?');
                    if (queryIndex > 0) {
                        filename = filename.Substring(0, queryIndex);
                        _logger.LogDebug("Удалены query-параметры из имени файла: {0}", filename);
                    }
                    
                    // Удаляем другие недопустимые символы из имени файла
                    char[] invalidChars = Path.GetInvalidFileNameChars();
                    foreach (char c in invalidChars) {
                        filename = filename.Replace(c, '_');
                    }
    
                    var filePath = Path.Combine(targetDir, filename);
    
                    _logger.LogDebug("Скачивание {url} в {path}", fullUrl, filePath);
                    using var imageStream = await DownloadFileStreamWithRetryAsync(fullUrl);
                    using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                    await imageStream.CopyToAsync(fileStream);
                } catch (Exception ex) {
                    _logger.LogError(ex, "Ошибка при скачивании/сохранении изображения: {0}", url);
                    // Продолжаем со следующим URL, не прерывая весь процесс
                }
            }
        }

        // Мелкий метод для скачивания (с ретраями)
        private async Task<Stream> DownloadFileStreamWithRetryAsync(string url)
        {
            int maxRetries = 3;
            int delayMs = 1000;

            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    return await DownloadFileStreamAsync(url);
                }
                catch (Exception ex) when (
                    ex is HttpRequestException ||
                    ex is TaskCanceledException ||
                    ex is IOException ||
                    ex is SocketException)
                {
                    if (attempt == maxRetries) throw;
                    _logger.LogWarning(ex, "Ошибка скачивания {Url}, attempt={Attempt}, max={Max}", url, attempt, maxRetries);
                    await InitializeCookiesAsync("https://meshok.net");
                    await Task.Delay(delayMs);
                    delayMs *= 2;
                }
            }
            throw new Exception($"Не удалось скачать {url} после {maxRetries} попыток");
        }

        private async Task<Stream> DownloadFileStreamAsync(string url)
        {
            await _semaphore.WaitAsync();
            try
            {
                // Добавляем случайную задержку перед каждым запросом
                await RandomDelayAsync();
                
                using var handler = new HttpClientHandler
                {
                    CookieContainer = _cookieContainer,
                    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
                    UseCookies = true,
                    AllowAutoRedirect = true
                };
                using var httpClient = new HttpClient(handler);
                httpClient.DefaultRequestHeaders.Referrer = new Uri("https://meshok.net");
                
                // Добавляем User-Agent для имитации браузера
                httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
                
                // Добавляем другие заголовки, которые обычно отправляет браузер
                httpClient.DefaultRequestHeaders.Add("Accept", "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8");
                httpClient.DefaultRequestHeaders.Add("Accept-Language", "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7");
                httpClient.DefaultRequestHeaders.Add("sec-ch-ua", "\"Not A(Brand\";v=\"99\", \"Google Chrome\";v=\"121\", \"Chromium\";v=\"121\"");
                httpClient.DefaultRequestHeaders.Add("sec-ch-ua-mobile", "?0");
                httpClient.DefaultRequestHeaders.Add("sec-ch-ua-platform", "\"Windows\"");
                
                _logger.LogDebug("Скачивание изображения: {Url}", url);
                var response = await httpClient.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
                
                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning("Ошибка скачивания {0}: {1} {2}", url, (int)response.StatusCode, response.ReasonPhrase);
                }
                
                response.EnsureSuccessStatusCode();
                return await response.Content.ReadAsStreamAsync();
            }
            finally
            {
                _semaphore.Release();
            }
        }

        private async Task<RegularBaseCategory> GetOrCreateCategoryAsync(int categoryId, string categoryName)
        {
            var category = await _context.Categories.FirstOrDefaultAsync(c => c.CategoryId == categoryId);
            if (category == null)
            {
                category = new RegularBaseCategory { CategoryId = categoryId, Name = categoryName };
                _context.Categories.Add(category);
                await _context.SaveChangesAsync();
            }
            return category;
        }

        // Добавляем задержку между запросами для имитации поведения человека
        private async Task RandomDelayAsync()
        {
            // Задержка от 200 мс до 1500 мс для имитации человеческого поведения
            int delay = _random.Next(200, 1500);
            _logger.LogDebug("Ожидание {delay}мс между запросами", delay);
            await Task.Delay(delay);
        }

        public void Dispose()
        {
            _semaphore?.Dispose();
        }
    }
}
