using Amazon.S3;
using Amazon.S3.Model;
using Amazon.S3.Transfer;
using Microsoft.Extensions.Configuration;

namespace RareBooksService.Parser.Services
{
    public interface IYandexStorageService
    {
        Task<List<string>> GetImageKeysAsync(int bookId);
        Task<List<string>> GetThumbnailKeysAsync(int bookId);
        Task<Stream> GetImageStreamAsync(string key);
        Task<Stream> GetThumbnailStreamAsync(string key);

        // Добавленные методы
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

        public YandexStorageService(IConfiguration configuration)
        {
            try
            {
                var accessKey = configuration["YandexCloud:AccessKey"];
                var secretKey = configuration["YandexCloud:SecretKey"];
                var serviceUrl = configuration["YandexCloud:ServiceUrl"];
                _bucketName = configuration["YandexCloud:BucketName"];

                if (string.IsNullOrEmpty(accessKey) || string.IsNullOrEmpty(secretKey) || string.IsNullOrEmpty(serviceUrl) || string.IsNullOrEmpty(_bucketName))
                {
                    throw new ArgumentException("Invalid configuration for Yandex Object Storage.");
                }

                _s3Client = new AmazonS3Client(accessKey, secretKey, new AmazonS3Config
                {
                    ServiceURL = serviceUrl,
                    ForcePathStyle = true
                });

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
                Console.WriteLine($"Error retrieving stream: {e.Message}");
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
                Console.WriteLine($"Error uploading file: {e.Message}");
            }
        }
    }
}
