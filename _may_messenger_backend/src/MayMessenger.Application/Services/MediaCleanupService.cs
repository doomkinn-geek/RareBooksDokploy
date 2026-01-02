using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Domain.Enums;
using Microsoft.Extensions.Hosting;

namespace MayMessenger.Application.Services;

/// <summary>
/// Сервис автоматической очистки медиа файлов (аудио и изображений).
/// Запускается каждые 24 часа и удаляет файлы старше 7 дней с сервера.
/// Локальные копии на устройствах пользователей сохраняются.
/// </summary>
public class MediaCleanupService : IHostedService, IDisposable
{
    private Timer? _timer;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<MediaCleanupService> _logger;
    private readonly string _webRootPath;
    private readonly int _retentionDays;
    
    public MediaCleanupService(
        IServiceProvider serviceProvider, 
        ILogger<MediaCleanupService> logger,
        IConfiguration configuration)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        
        // Get web root path from configuration or use default
        _webRootPath = configuration["WebRootPath"] ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        
        // Get retention period in days (default: 7 days)
        _retentionDays = configuration.GetValue<int>("MediaRetentionDays", 7);
    }
    
    public Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Media Cleanup Service starting... Retention period: {Days} days", _retentionDays);
        
        // Run immediately on startup, then every 24 hours
        _timer = new Timer(DoWork, null, TimeSpan.Zero, TimeSpan.FromHours(24));
        
        return Task.CompletedTask;
    }
    
    private async void DoWork(object? state)
    {
        _logger.LogInformation("Starting media cleanup task...");
        
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
            
            // Get all media messages (audio + images) older than retention period
            var cutoffDate = DateTime.UtcNow.AddDays(-_retentionDays);
            var oldMessages = await unitOfWork.Messages.GetOldMediaMessagesAsync(cutoffDate);
            
            int audioDeleted = 0;
            int imagesDeleted = 0;
            int filesDeleted = 0;
            int audioUpdated = 0;
            int imagesUpdated = 0;
            int filesUpdated = 0;
            
            foreach (var message in oldMessages)
            {
                if (!string.IsNullOrEmpty(message.FilePath))
                {
                    // Extract filename from path (e.g., "/audio/file.m4a" or "/images/file.jpg")
                    var fileName = message.FilePath.TrimStart('/');
                    var fullPath = Path.Combine(_webRootPath, fileName);
                    
                    // Delete physical file from server
                    if (File.Exists(fullPath))
                    {
                        try
                        {
                            File.Delete(fullPath);
                            
                            if (message.Type == MessageType.Audio)
                                audioDeleted++;
                            else if (message.Type == MessageType.Image)
                                imagesDeleted++;
                            else if (message.Type == MessageType.File)
                                filesDeleted++;
                            
                            _logger.LogDebug("Deleted {Type} file: {Path}", message.Type, fullPath);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Failed to delete {Type} file: {Path}", message.Type, fullPath);
                        }
                    }
                    
                    // Mark message as having no file on server
                    // Note: Local copies on user devices remain intact
                    message.FilePath = null;
                    
                    if (message.Type == MessageType.Audio)
                    {
                        message.Content = "[Аудио удалено с сервера]";
                        audioUpdated++;
                    }
                    else if (message.Type == MessageType.Image)
                    {
                        message.Content = "[Изображение удалено с сервера]";
                        imagesUpdated++;
                    }
                    else if (message.Type == MessageType.File)
                    {
                        message.Content = "[Файл удалён с сервера]";
                        filesUpdated++;
                    }
                }
            }
            
            if (audioUpdated > 0 || imagesUpdated > 0 || filesUpdated > 0)
            {
                await unitOfWork.SaveChangesAsync();
            }
            
            _logger.LogInformation(
                "Media cleanup completed. Audio: {AudioDeleted} files deleted, {AudioUpdated} records updated. " +
                "Images: {ImagesDeleted} files deleted, {ImagesUpdated} records updated. " +
                "Files: {FilesDeleted} files deleted, {FilesUpdated} records updated.",
                audioDeleted, audioUpdated, imagesDeleted, imagesUpdated, filesDeleted, filesUpdated);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during media cleanup task");
        }
    }
    
    public Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Media Cleanup Service stopping...");
        _timer?.Change(Timeout.Infinite, 0);
        return Task.CompletedTask;
    }
    
    public void Dispose()
    {
        _timer?.Dispose();
    }
}

