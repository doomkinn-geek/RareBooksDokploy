using AutoMapper;
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

namespace RareBooksService.Parser.Services.bak
{
    // Класс опций для хранения настроек сохранения изображений
    public class TypeOfAccessImages
    {
        public bool UseLocalFiles { get; set; }
        public string LocalPathOfImages { get; set; }
    }

    public interface ILotDataHandler
    {
        Task SaveLotDataAsync(MeshokBook lotData, int categoryId, string categoryName = "unknown", bool downloadImages = true, bool isLessValuableLot = false);
        // Новое событие: (lotId, message)
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
        private readonly SemaphoreSlim _semaphore = new SemaphoreSlim(5); // Ограничиваем до 5 одновременных запросов
        private bool _cookiesInitialized = false;

        // Реализация события:
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
            ILogger<LotDataHandler> logger)
        {
            _context = context;
            _mapper = mapper;
            _lotDataService = lotDataService;
            _yandexStorageService = yandexStorageService;
            _imageStorageOptions = imageStorageOptions.Value;
            _logger = logger;

            _cookieContainer = new CookieContainer();


            //Лучше вообще не вызывать в конструкторе асинхронный метод. Можно отложить инициализацию cookie до момента фактического использования.
            //Например, вы можете убрать эту строчку из конструктора и,
            //например, вызвать InitializeCookiesAsync единожды в SaveLotDataAsync(или любой другой метод), но асинхронно.            
            //InitializeCookiesAsync("https://meshok.net").Wait();
        }        


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
                    SslProtocols = System.Security.Authentication.SslProtocols.Tls12 | System.Security.Authentication.SslProtocols.Tls13
                };

                using var httpClient = new HttpClient(handler);
                httpClient.DefaultRequestHeaders.Accept.Clear();
                httpClient.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("text/html"));
                httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

                var response = await httpClient.GetAsync(baseUri);
                response.EnsureSuccessStatusCode();

                _logger.LogInformation("Успешно инициализированы cookies для домена {Domain}", baseUri);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при инициализации cookies для URL {Url}", url);
            }
        }

        public async Task SaveLotDataAsync(MeshokBook lotData, 
                                            int categoryId, 
                                            string categoryName = "unknown", 
                                            bool downloadImages = true, 
                                            bool isLessValuableLot = false)
        {
            try
            {
                await EnsureCookiesInitializedAsync();

                // Сигнализируем, что начали обработку (если нужно):
                OnProgressChanged(lotData.id, $"Начало обработки лота {lotData.id}.");

                _logger.LogInformation("Обработка лота с ID {LotId}", lotData.id);

                if (!await _context.BooksInfo.AnyAsync(b => b.Id == lotData.id))
                {
                    _logger.LogInformation("Лот {LotId} отсутствует в базе данных. Сохранение нового лота.", lotData.id);
                    OnProgressChanged(lotData.id, $"Лот {lotData.id} отсутствует в БД. Сохраняем...");

                    var category = await GetOrCreateCategoryAsync(categoryId, categoryName);
                    _logger.LogInformation("Используется категория с ID {CategoryId} и названием '{CategoryName}'", categoryId, categoryName);

                    var bookInfo = _mapper.Map<RegularBaseBook>(lotData);
                    bookInfo.Category = category;

                    // Установка типа лота
                    bookInfo.Type = lotData.type;

                    // Получение и установка описания
                    bookInfo.Description = await _lotDataService.GetBookDescriptionAsync(lotData.id);
                    bookInfo.NormalizedDescription = bookInfo.Description.ToLower();
                    _logger.LogDebug("Получено описание для лота {LotId}", lotData.id);
                    OnProgressChanged(lotData.id, $"Получено описание для лота {lotData.id}.");

                    // Извлечение года публикации
                    bookInfo.YearPublished = PublishingYearExtractor.ExtractYearFromDescription(bookInfo.Description)
                                            ?? PublishingYearExtractor.ExtractYearFromDescription(bookInfo.Title);
                    _logger.LogDebug("Извлечен год публикации для лота {LotId}: {YearPublished}", lotData.id, bookInfo.YearPublished);

                    if (lotData.endDate == null || lotData.beginDate == null)
                    {
                        bookInfo.IsMonitored = false;
                        bookInfo.FinalPrice = lotData.normalizedPrice;
                    }
                    else
                    {
                        bookInfo.IsMonitored = lotData.endDate >= DateTime.UtcNow;
                        bookInfo.FinalPrice = lotData.endDate < DateTime.UtcNow ? lotData.normalizedPrice : null;
                    }

                    // Добавляем признак малоценного лота:
                    bookInfo.IsLessValuable = isLessValuableLot;

                    // Механизм сжатия теперь используем только для "обычных" недорогих (если бы хотелось).
                    // Но согласно задаче, если IsLessValuable=true — вообще НЕ скачиваем изображения
                    if (isLessValuableLot)
                    {
                        // Явно укажем, что не храним архив:
                        bookInfo.IsImagesCompressed = false;
                        bookInfo.ImageArchiveUrl = null;
                    }

                    _context.BooksInfo.Add(bookInfo);
                    await _context.SaveChangesAsync();
                    _logger.LogInformation("Лот {LotId} сохранен в базе данных.", lotData.id);
                    OnProgressChanged(lotData.id, $"Лот {lotData.id} сохранён в БД.");

                    if (!isLessValuableLot && downloadImages)
                    {
                        _logger.LogInformation("Скачивание изображений для лота {LotId}", lotData.id);
                        OnProgressChanged(lotData.id, $"Скачивание изображений для лота {lotData.id}...");
                        //await DownloadImagesForBookAsync(bookInfo, bookInfo.ImageUrls, bookInfo.ThumbnailUrls, isLessValuableLot);
                        await ArchiveImagesForBookAsync(bookInfo);
                    }
                }
                else
                {
                    _logger.LogInformation("Лот {LotId} уже существует в базе данных.", lotData.id);
                    OnProgressChanged(lotData.id, $"Лот {lotData.id} уже существует в БД (пропускаем).");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Произошла ошибка при сохранении данных лота с ID {LotId}", lotData.id);
                // Можно тоже пробросить сообщение:
                OnProgressChanged(lotData.id, $"Ошибка при сохранении лота {lotData.id}: {ex.Message}");
                throw;
            }
        }

        /// <summary>
        /// Всегда создаёт архив изображений (локально или в ObjectStorage),
        /// проставляет IsImagesCompressed=true и сохраняет bookInfo.ImageArchiveUrl.
        /// </summary>
        private async Task ArchiveImagesForBookAsync(RegularBaseBook bookInfo)
        {
            int bookId = bookInfo.Id;
            // Получаем current lists
            var imageUrls = bookInfo.ImageUrls;
            var thumbnailUrls = bookInfo.ThumbnailUrls;

            _logger.LogInformation("Архивирование изображений для книги {BookId}", bookId);

            string archivePathOrKey = null;

            if (_imageStorageOptions.UseLocalFiles)
            {
                // Архивируем локально
                archivePathOrKey = await SaveImagesLocallyAsZip(bookId, imageUrls, thumbnailUrls);
            }
            else
            {
                // Архивируем и кладём в _compressed_images/xxx.zip (Yandex)
                archivePathOrKey = await UploadCompressedImagesAsync(bookId, imageUrls, thumbnailUrls);
            }

            if (!string.IsNullOrEmpty(archivePathOrKey))
            {
                // Успешно создали архив
                bookInfo.IsImagesCompressed = true;
                bookInfo.ImageArchiveUrl = archivePathOrKey;
                _context.BooksInfo.Update(bookInfo);
                await _context.SaveChangesAsync();
            }
        }

        /// <summary>
        /// Скачиваем все изображения, помещаем их в один zip локально, 
        /// возвращаем путь к архиву (например: /.../images_{bookId}.zip).
        /// </summary>
        private async Task<string> SaveImagesLocallyAsZip(int bookId, List<string> imageUrls, List<string> thumbnailUrls)
        {
            // создаём temp, скачиваем
            string tempDir = Path.Combine(Path.GetTempPath(), $"lot_{bookId}");
            Directory.CreateDirectory(tempDir);

            await DownloadAllImagesAsync(tempDir, imageUrls);
            await DownloadAllImagesAsync(tempDir, thumbnailUrls);

            // Создаём итоговый архив
            string archivePath = Path.Combine(_imageStorageOptions.LocalPathOfImages, $"{bookId}.zip");
            Directory.CreateDirectory(_imageStorageOptions.LocalPathOfImages); // just in case
            if (File.Exists(archivePath)) File.Delete(archivePath);

            ZipFile.CreateFromDirectory(tempDir, archivePath, CompressionLevel.Optimal, false);

            // Удаляем temp
            Directory.Delete(tempDir, true);

            _logger.LogInformation("Локальный архив для книги {BookId} создан: {ArchivePath}", bookId, archivePath);
            return archivePath;
        }

        private async Task DownloadAllImagesAsync(string targetDir, List<string> urls)
        {
            foreach (var url in urls)
            {
                var filename = Path.GetFileName(new Uri(url).AbsolutePath);
                var filePath = Path.Combine(targetDir, filename);

                using var imageStream = await DownloadFileStreamWithRetryAsync(url);
                using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                await imageStream.CopyToAsync(fileStream);
            }
        }

        /// <summary>
        /// Скачиваем все изображения в temp, создаём zip, загружаем в _compressed_images/bookId.zip
        /// Возвращаем ключ objectStorage.
        /// </summary>
        private async Task<string> UploadCompressedImagesAsync(int bookId, List<string> imageUrls, List<string> thumbnailUrls)
        {
            string tempDir = Path.Combine(Path.GetTempPath(), $"lot_{bookId}");
            Directory.CreateDirectory(tempDir);

            await DownloadAllImagesAsync(tempDir, imageUrls);
            await DownloadAllImagesAsync(tempDir, thumbnailUrls);

            string localZip = Path.Combine(Path.GetTempPath(), $"lot_{bookId}.zip");
            if (File.Exists(localZip)) File.Delete(localZip);

            ZipFile.CreateFromDirectory(tempDir, localZip, CompressionLevel.Optimal, false);

            string key = $"_compressed_images/{bookId}.zip";

            using var archiveStream = new FileStream(localZip, FileMode.Open, FileAccess.Read);
            await _yandexStorageService.UploadCompressedImageArchiveAsync(key, archiveStream);

            Directory.Delete(tempDir, true);
            File.Delete(localZip);

            _logger.LogInformation("ObjectStorage-архив для книги {BookId} создан: {Key}", bookId, key);
            return key;
        }



        private async Task<RegularBaseCategory> GetOrCreateCategoryAsync(int categoryId, string categoryName)
        {
            _logger.LogDebug("Получение категории с ID {CategoryId}", categoryId);

            var category = await _context.Categories.FirstOrDefaultAsync(c => c.CategoryId == categoryId);
            if (category == null)
            {
                _logger.LogInformation("Категория с ID {CategoryId} не найдена. Создание новой категории с названием '{CategoryName}'", categoryId, categoryName);

                category = new RegularBaseCategory { CategoryId = categoryId, Name = categoryName };
                _context.Categories.Add(category);
                await _context.SaveChangesAsync();

                _logger.LogInformation("Создана новая категория с ID {CategoryId} и названием '{CategoryName}'", categoryId, categoryName);
            }
            else
            {
                _logger.LogDebug("Категория с ID {CategoryId} найдена с названием '{CategoryName}'", categoryId, category.Name);
            }

            return category;
        }

        private async Task DownloadImagesForBookAsync(RegularBaseBook bookInfo, List<string> imageUrls, List<string> thumbnailUrls, bool isLessValuableLot)
        {
            int bookId = bookInfo.Id;
            _logger.LogInformation("Начало скачивания изображений для книги с ID {BookId}", bookId);
            OnProgressChanged(bookId, $"Начало скачивания изображений (ID {bookId})...");

            string imageArchivePathOrKey = null;

            if (_imageStorageOptions.UseLocalFiles)
            {
                _logger.LogInformation("Сохранение изображений локально в папку '{LocalPath}'", _imageStorageOptions.LocalPathOfImages);
                OnProgressChanged(bookId, $"Сохранение изображений локально для лота {bookId}...");
                imageArchivePathOrKey = await SaveImagesLocallyAsync(bookId, imageUrls, thumbnailUrls, isLessValuableLot);
            }
            else
            {
                _logger.LogInformation("Загрузка изображений в облачное хранилище Yandex Object Storage");
                OnProgressChanged(bookId, $"Загрузка в Yandex Object Storage (ID {bookId})...");
                if (isLessValuableLot)
                {
                    imageArchivePathOrKey = await UploadCompressedImagesAsync(bookId, imageUrls, thumbnailUrls);
                }
                else
                {
                    await UploadImagesToYandexAsync(bookId, imageUrls, thumbnailUrls);
                }
            }

            // Обновляем информацию о пути или ключе архива
            if (isLessValuableLot && !string.IsNullOrEmpty(imageArchivePathOrKey))
            {
                bookInfo.ImageArchiveUrl = imageArchivePathOrKey;
            }

            _logger.LogInformation("Завершено скачивание изображений для книги с ID {BookId}", bookId);
            OnProgressChanged(bookId, $"Изображения для лота {bookId} скачаны/загружены.");
        }


        /*private async Task<string> UploadCompressedImagesAsync(int bookId, List<string> imageUrls, List<string> thumbnailUrls)
        {
            try
            {
                _logger.LogInformation("Скачивание и сжатие изображений для лота с ID {BookId}", bookId);

                // Создаем временную директорию для хранения изображений
                string tempDirectory = Path.Combine(Path.GetTempPath(), $"lot_{bookId}");
                Directory.CreateDirectory(tempDirectory);

                // Список путей к скачанным изображениям
                List<string> downloadedImagePaths = new List<string>();

                // Скачиваем изображения
                foreach (var imageUrl in imageUrls)
                {
                    var filename = Path.GetFileName(new Uri(imageUrl).AbsolutePath);
                    var filePath = Path.Combine(tempDirectory, filename);

                    using var imageStream = await DownloadFileStreamWithRetryAsync(imageUrl);
                    using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                    await imageStream.CopyToAsync(fileStream);

                    downloadedImagePaths.Add(filePath);
                }

                // Скачиваем миниатюры
                foreach (var thumbnailUrl in thumbnailUrls)
                {
                    var filename = Path.GetFileName(new Uri(thumbnailUrl).AbsolutePath);
                    var filePath = Path.Combine(tempDirectory, filename);

                    using var imageStream = await DownloadFileStreamWithRetryAsync(thumbnailUrl);
                    using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                    await imageStream.CopyToAsync(fileStream);

                    downloadedImagePaths.Add(filePath);
                }

                // Сжимаем изображения в архив
                string archivePath = Path.Combine(Path.GetTempPath(), $"lot_{bookId}.zip");
                ZipFile.CreateFromDirectory(tempDirectory, archivePath, CompressionLevel.Optimal, false);

                _logger.LogInformation("Изображения для лота {BookId} сжаты в архив {ArchivePath}", bookId, archivePath);

                // Загружаем архив в object storage
                string key = $"_compressed_images/{bookId}.zip";

                using var archiveStream = new FileStream(archivePath, FileMode.Open, FileAccess.Read);
                await _yandexStorageService.UploadCompressedImageArchiveAsync(key, archiveStream);

                _logger.LogInformation("Архив изображений для лота {BookId} загружен с ключом {Key}", bookId, key);

                // Удаляем временные файлы
                Directory.Delete(tempDirectory, true);
                File.Delete(archivePath);

                return key; // Возвращаем ключ архива
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при сжатии и загрузке изображений для лота {BookId}", bookId);
                return null;
            }
        }*/

        private async Task<string> SaveImagesLocallyAsync(int bookId, List<string> imageUrls, List<string> thumbnailUrls, bool isLessValuableLot)
        {
            string basePath = Path.Combine(_imageStorageOptions.LocalPathOfImages, bookId.ToString());

            if (isLessValuableLot)
            {
                // Создаем временную директорию для хранения изображений
                string tempDirectory = Path.Combine(Path.GetTempPath(), $"lot_{bookId}");
                Directory.CreateDirectory(tempDirectory);

                // Список путей к скачанным изображениям
                List<string> downloadedImagePaths = new List<string>();

                // Скачиваем изображения
                foreach (var imageUrl in imageUrls)
                {
                    var filename = Path.GetFileName(new Uri(imageUrl).AbsolutePath);
                    var filePath = Path.Combine(tempDirectory, filename);

                    using var imageStream = await DownloadFileStreamWithRetryAsync(imageUrl);
                    using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                    await imageStream.CopyToAsync(fileStream);

                    downloadedImagePaths.Add(filePath);
                }

                // Скачиваем миниатюры
                foreach (var thumbnailUrl in thumbnailUrls)
                {
                    var filename = Path.GetFileName(new Uri(thumbnailUrl).AbsolutePath);
                    var filePath = Path.Combine(tempDirectory, filename);

                    using var imageStream = await DownloadFileStreamWithRetryAsync(thumbnailUrl);
                    using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                    await imageStream.CopyToAsync(fileStream);

                    downloadedImagePaths.Add(filePath);
                }

                // Сжимаем изображения в архив
                Directory.CreateDirectory(basePath);
                string archivePath = Path.Combine(basePath, $"images_{bookId}.zip");
                ZipFile.CreateFromDirectory(tempDirectory, archivePath, CompressionLevel.Optimal, false);

                _logger.LogInformation("Изображения для лота {BookId} сжаты и сохранены локально в архив {ArchivePath}", bookId, archivePath);

                // Удаляем временные файлы
                Directory.Delete(tempDirectory, true);

                return archivePath; // Возвращаем путь к архиву
            }
            else
            {
                string imagesPath = Path.Combine(basePath, "images");
                string thumbnailsPath = Path.Combine(basePath, "thumbnails");

                Directory.CreateDirectory(imagesPath);
                Directory.CreateDirectory(thumbnailsPath);

                // Скачивание полноразмерных изображений
                foreach (var imageUrl in imageUrls)
                {
                    await DownloadAndSaveImageAsync(imageUrl, imagesPath, bookId, "изображение");
                }

                // Скачивание миниатюр
                foreach (var thumbnailUrl in thumbnailUrls)
                {
                    await DownloadAndSaveImageAsync(thumbnailUrl, thumbnailsPath, bookId, "миниатюра");
                }

                return null; // Нет архива, возвращаем null
            }
        }


        private async Task UploadImagesToYandexAsync(int bookId, List<string> imageUrls, List<string> thumbnailUrls)
        {
            // Загрузка полноразмерных изображений
            foreach (var imageUrl in imageUrls)
            {
                await DownloadAndUploadImageAsync(imageUrl, $"{bookId}/images", bookId, "изображение");
            }

            // Загрузка миниатюр
            foreach (var thumbnailUrl in thumbnailUrls)
            {
                await DownloadAndUploadImageAsync(thumbnailUrl, $"{bookId}/thumbnails", bookId, "миниатюра");
            }
        }

        private async Task DownloadAndSaveImageAsync(string imageUrl, string savePath, int bookId, string imageType)
        {
            try
            {
                var filename = Path.GetFileName(new Uri(imageUrl).AbsolutePath);
                var filePath = Path.Combine(savePath, filename);

                using var imageStream = await DownloadFileStreamWithRetryAsync(imageUrl);
                using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
                await imageStream.CopyToAsync(fileStream);

                _logger.LogInformation("Сохранено {ImageType} '{FileName}' для книги с ID {BookId}", imageType, filename, bookId);
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Ошибка при скачивании {ImageType} с {ImageUrl}", imageType, imageUrl);
            }
        }

        private async Task DownloadAndUploadImageAsync(string imageUrl, string keyPrefix, int bookId, string imageType)
        {
            try
            {
                var filename = Path.GetFileName(new Uri(imageUrl).AbsolutePath);
                var key = $"{keyPrefix}/{filename}";

                using var imageStream = await DownloadFileStreamWithRetryAsync(imageUrl);

                if (imageType == "изображение")
                {
                    await _yandexStorageService.UploadImageAsync(key, imageStream);
                }
                else
                {
                    await _yandexStorageService.UploadThumbnailAsync(key, imageStream);
                }

                _logger.LogInformation("Загружено {ImageType} '{FileName}' для книги с ID {BookId}", imageType, filename, bookId);
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Ошибка при загрузке {ImageType} с {ImageUrl}", imageType, imageUrl);
            }
        }

        // Кастомное исключение для передачи кода состояния
        public class HttpStatusCodeException : Exception
        {
            public HttpStatusCode StatusCode { get; }

            public HttpStatusCodeException(HttpStatusCode statusCode, string message) : base(message)
            {
                StatusCode = statusCode;
            }
        }

        private async Task<Stream> DownloadFileStreamWithRetryAsync(string url)
        {
            int maxRetries = 3;
            int delayMilliseconds = 1000; // Начинаем с 1 секунды
            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    return await DownloadFileStreamAsync(url);
                }
                catch (HttpStatusCodeException ex) when (ex.StatusCode == HttpStatusCode.BadRequest)
                {
                    _logger.LogError(ex, "Получен статус 400 Bad Request при запросе к {Url}. Повторная попытка не будет предпринята.", url);
                    throw;
                }
                catch (Exception ex) when (ex is HttpRequestException || ex is TaskCanceledException || ex is IOException || ex is SocketException)
                {
                    _logger.LogWarning(ex, "Попытка {Attempt} из {MaxRetries}: ошибка при скачивании из {Url}", attempt, maxRetries, url);

                    if (attempt == maxRetries)
                    {
                        _logger.LogError(ex, "Не удалось скачать файл после {MaxRetries} попыток из {Url}", maxRetries, url);
                        throw;
                    }

                    _logger.LogInformation("Получение новых cookies и повторная попытка скачивания из {Url}", url);
                    await InitializeCookiesAsync("https://meshok.net"); // Используем базовый URL

                    // Добавляем задержку перед повторной попыткой
                    await Task.Delay(delayMilliseconds);
                    delayMilliseconds *= 2; // Экспоненциальная задержка
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Неожиданная ошибка при скачивании из {Url}", url);
                    throw;
                }
            }

            throw new Exception($"Не удалось скачать файл из {url} после {maxRetries} попыток.");
        }

        private async Task<Stream> DownloadFileStreamAsync(string url)
        {
            await _semaphore.WaitAsync();
            try
            {
                using var handler = new HttpClientHandler
                {
                    CookieContainer = _cookieContainer,
                    AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate,
                    SslProtocols = System.Security.Authentication.SslProtocols.Tls12 | System.Security.Authentication.SslProtocols.Tls13
                };

                using var httpClient = new HttpClient(handler);

                var request = new HttpRequestMessage(HttpMethod.Get, url);
                request.Headers.Accept.Clear();
                request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("image/jpeg"));
                request.Headers.UserAgent.ParseAdd("Mozilla/5.0 (Windows NT 10.0; Win64; x64)");

                // Устанавливаем Referer на базовый адрес
                request.Headers.Referrer = new Uri("https://meshok.net");

                var response = await httpClient.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);

                if (!response.IsSuccessStatusCode)
                {
                    var message = $"Response status code does not indicate success: {(int)response.StatusCode} ({response.StatusCode}).";
                    throw new HttpStatusCodeException(response.StatusCode, message);
                }

                return await response.Content.ReadAsStreamAsync();
            }
            finally
            {
                _semaphore.Release();
            }
        }

        public void Dispose()
        {
            _semaphore?.Dispose();
        }        
    }
}
