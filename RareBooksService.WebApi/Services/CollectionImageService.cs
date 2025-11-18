using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models.Dto;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Processing;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Services
{
    public interface ICollectionImageService
    {
        Task<UserCollectionBookImageDto> SaveImageAsync(string userId, int bookId, IFormFile file);
        Task<string> GetImagePathAsync(string userId, int bookId, string fileName);
        Task DeleteImageAsync(string userId, int bookId, string fileName);
        Task DeleteAllBookImagesAsync(string userId, int bookId);
        string GetImageUrl(string userId, int bookId, string fileName);
    }

    public class CollectionImageService : ICollectionImageService
    {
        private readonly ILogger<CollectionImageService> _logger;
        private readonly IWebHostEnvironment _environment;
        private const string CollectionImagesFolder = "collection_images";
        private const int MaxFileSizeMB = 10;
        private const int ThumbnailSize = 200;
        private readonly string[] AllowedExtensions = { ".jpg", ".jpeg", ".png", ".webp" };

        public CollectionImageService(
            ILogger<CollectionImageService> logger,
            IWebHostEnvironment environment)
        {
            _logger = logger;
            _environment = environment;
        }

        public async Task<UserCollectionBookImageDto> SaveImageAsync(string userId, int bookId, IFormFile file)
        {
            try
            {
                // Проверка размера файла
                if (file.Length > MaxFileSizeMB * 1024 * 1024)
                {
                    throw new InvalidOperationException($"Размер файла превышает {MaxFileSizeMB}MB");
                }

                // Проверка расширения
                var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!AllowedExtensions.Contains(extension))
                {
                    throw new InvalidOperationException($"Недопустимый формат файла. Разрешены: {string.Join(", ", AllowedExtensions)}");
                }

                // Создаем уникальное имя файла
                var fileName = $"{Guid.NewGuid()}{extension}";
                var userFolder = GetUserFolder(userId, bookId);
                Directory.CreateDirectory(userFolder);

                var filePath = Path.Combine(userFolder, fileName);

                // Сохраняем оригинальное изображение
                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }

                // Создаем миниатюру
                await CreateThumbnailAsync(filePath, userFolder, fileName);

                _logger.LogInformation("Изображение сохранено: {FileName} для книги {BookId} пользователя {UserId}", 
                    fileName, bookId, userId);

                return new UserCollectionBookImageDto
                {
                    FileName = fileName,
                    ImageUrl = GetImageUrl(userId, bookId, fileName),
                    UploadedDate = DateTime.UtcNow,
                    IsMainImage = false
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при сохранении изображения для книги {BookId} пользователя {UserId}", 
                    bookId, userId);
                throw;
            }
        }

        private async Task CreateThumbnailAsync(string originalPath, string folder, string fileName)
        {
            try
            {
                var thumbnailFileName = $"thumb_{fileName}";
                var thumbnailPath = Path.Combine(folder, thumbnailFileName);

                using (var image = await Image.LoadAsync(originalPath))
                {
                    image.Mutate(x => x.Resize(new ResizeOptions
                    {
                        Size = new Size(ThumbnailSize, ThumbnailSize),
                        Mode = ResizeMode.Max
                    }));

                    await image.SaveAsync(thumbnailPath);
                }

                _logger.LogDebug("Создана миниатюра: {ThumbnailFileName}", thumbnailFileName);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Не удалось создать миниатюру для {FileName}", fileName);
                // Не прерываем выполнение, если миниатюра не создана
            }
        }

        public async Task<string> GetImagePathAsync(string userId, int bookId, string fileName)
        {
            var userFolder = GetUserFolder(userId, bookId);
            var filePath = Path.Combine(userFolder, fileName);

            if (!File.Exists(filePath))
            {
                throw new FileNotFoundException($"Изображение не найдено: {fileName}");
            }

            return await Task.FromResult(filePath);
        }

        public async Task DeleteImageAsync(string userId, int bookId, string fileName)
        {
            try
            {
                var userFolder = GetUserFolder(userId, bookId);
                var filePath = Path.Combine(userFolder, fileName);
                var thumbnailPath = Path.Combine(userFolder, $"thumb_{fileName}");

                if (File.Exists(filePath))
                {
                    File.Delete(filePath);
                    _logger.LogInformation("Удалено изображение: {FileName}", filePath);
                }

                if (File.Exists(thumbnailPath))
                {
                    File.Delete(thumbnailPath);
                    _logger.LogDebug("Удалена миниатюра: {ThumbnailFileName}", thumbnailPath);
                }

                await Task.CompletedTask;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении изображения {FileName} для книги {BookId}", 
                    fileName, bookId);
                throw;
            }
        }

        public async Task DeleteAllBookImagesAsync(string userId, int bookId)
        {
            try
            {
                var userFolder = GetUserFolder(userId, bookId);

                if (Directory.Exists(userFolder))
                {
                    Directory.Delete(userFolder, true);
                    _logger.LogInformation("Удалены все изображения для книги {BookId} пользователя {UserId}", 
                        bookId, userId);
                }

                await Task.CompletedTask;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при удалении всех изображений для книги {BookId}", bookId);
                throw;
            }
        }

        public string GetImageUrl(string userId, int bookId, string fileName)
        {
            return $"/api/usercollection/{bookId}/images/{fileName}";
        }

        private string GetUserFolder(string userId, int bookId)
        {
            var wwwrootPath = _environment.WebRootPath ?? Path.Combine(_environment.ContentRootPath, "wwwroot");
            return Path.Combine(wwwrootPath, CollectionImagesFolder, userId, bookId.ToString());
        }
    }
}

