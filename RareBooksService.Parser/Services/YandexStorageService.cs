using Amazon.S3;
using Amazon.S3.Model;
using Amazon.S3.Transfer;
using System.Text.Json;

namespace RareBooksService.Parser.Services
{
    public interface IYandexStorageService
    {
        Task<List<string>> GetImageKeysAsync(int bookId);
        Task<List<string>> GetThumbnailKeysAsync(int bookId);
        Task<Stream> GetImageStreamAsync(string key);
        Task<Stream> GetThumbnailStreamAsync(string key);

        Task UploadImageAsync(string key, Stream imageStream);
        Task UploadThumbnailAsync(string key, Stream thumbnailStream);
        Task UploadCompressedImageArchiveAsync(string key, Stream archiveStream);
        Task<Stream> GetArchiveStreamAsync(string key);
    }

    public class YandexStorageService : IYandexStorageService
    {
        private readonly AmazonS3Client _s3Client;
        private readonly string _bucketName;
        private readonly bool _isInitialized;

        private readonly string _appSettingsPath;

        public YandexStorageService()
        {
            _appSettingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");

            try
            {
                // 1) Читаем файл appsettings.json (из /app папки внутри контейнера)
                if (!File.Exists(_appSettingsPath))
                    throw new FileNotFoundException("appsettings.json not found at " + _appSettingsPath);

                var jsonText = File.ReadAllText(_appSettingsPath);
                using var doc = JsonDocument.Parse(jsonText);
                var root = doc.RootElement;

                // 2) Ищем секцию "YandexCloud"
                if (!root.TryGetProperty("YandexCloud", out var yandexCloudElement))
                    throw new Exception("Section 'YandexCloud' not found in appsettings.json");

                // 3) Достаём поля AccessKey / SecretKey / ServiceUrl / BucketName
                var accessKey = yandexCloudElement.GetProperty("AccessKey").GetString();
                var secretKey = yandexCloudElement.GetProperty("SecretKey").GetString();
                var serviceUrl = yandexCloudElement.GetProperty("ServiceUrl").GetString();
                var bucketName = yandexCloudElement.GetProperty("BucketName").GetString();

                // 4) Проверяем
                if (string.IsNullOrEmpty(accessKey) ||
                    string.IsNullOrEmpty(secretKey) ||
                    string.IsNullOrEmpty(serviceUrl) ||
                    string.IsNullOrEmpty(bucketName))
                {
                    throw new ArgumentException("Invalid YandexCloud config in appsettings.json");
                }

                // 5) Создаём AmazonS3Client
                _s3Client = new AmazonS3Client(accessKey, secretKey, new AmazonS3Config
                {
                    ServiceURL = serviceUrl,
                    ForcePathStyle = true
                });
                _bucketName = bucketName;
                _isInitialized = true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Failed to initialize YandexStorageService: {ex.Message}");
                _isInitialized = false;
            }
        }

        private void EnsureInitialized()
        {
            if (!_isInitialized)
            {
                Console.WriteLine("YandexStorageService is not initialized. Operation skipped.");
            }
        }

        public async Task<List<string>> GetImageKeysAsync(int bookId)
        {
            EnsureInitialized();
            if (!_isInitialized) return new List<string>();
            return await GetKeysAsync($"{bookId}/images/");
        }

        public async Task<List<string>> GetThumbnailKeysAsync(int bookId)
        {
            EnsureInitialized();
            if (!_isInitialized) return new List<string>();
            return await GetKeysAsync($"{bookId}/thumbnails/");
        }

        private async Task<List<string>> GetKeysAsync(string prefix)
        {
            try
            {
                var request = new ListObjectsV2Request
                {
                    BucketName = _bucketName,
                    Prefix = prefix
                };

                var response = await _s3Client.ListObjectsV2Async(request);

                return response.S3Objects
                    .Select(o => o.Key.Replace(prefix, ""))
                    .ToList();
            }
            catch (Exception e)
            {
                Console.WriteLine($"Error retrieving keys: {e.Message}");
                return new List<string>();
            }
        }

        public async Task<Stream> GetImageStreamAsync(string key)
        {
            EnsureInitialized();
            if (!_isInitialized) return null;
            return await GetStreamAsync(key);
        }

        public async Task<Stream> GetThumbnailStreamAsync(string key)
        {
            EnsureInitialized();
            if (!_isInitialized) return null;
            return await GetStreamAsync(key);
        }

        private async Task<Stream> GetStreamAsync(string key)
        {
            try
            {
                var response = await _s3Client.GetObjectAsync(_bucketName, key);
                return response.ResponseStream;
            }
            catch (Exception e)
            {
                Console.WriteLine($"Error retrieving stream for '{key}': {e.Message}");
                return null;
            }
        }

        public async Task UploadImageAsync(string key, Stream imageStream)
        {
            EnsureInitialized();
            if (!_isInitialized) return;
            await UploadFileAsync(key, imageStream);
        }

        public async Task UploadThumbnailAsync(string key, Stream thumbnailStream)
        {
            EnsureInitialized();
            if (!_isInitialized) return;
            await UploadFileAsync(key, thumbnailStream);
        }

        public async Task UploadCompressedImageArchiveAsync(string key, Stream archiveStream)
        {
            EnsureInitialized();
            if (!_isInitialized) return;
            await UploadFileAsync(key, archiveStream);
        }

        public async Task<Stream> GetArchiveStreamAsync(string key)
        {
            EnsureInitialized();
            if (!_isInitialized) return null;
            return await GetStreamAsync(key);
        }

        private async Task UploadFileAsync(string key, Stream inputStream)
        {
            try
            {
                var uploadRequest = new TransferUtilityUploadRequest
                {
                    InputStream = inputStream,
                    Key = key,
                    BucketName = _bucketName
                };

                var fileTransferUtility = new TransferUtility(_s3Client);
                await fileTransferUtility.UploadAsync(uploadRequest);
                Console.WriteLine($"File uploaded as {key}.");
            }
            catch (Exception e)
            {
                Console.WriteLine($"Error uploading file '{key}': {e.Message}");
            }
        }
    }
}
