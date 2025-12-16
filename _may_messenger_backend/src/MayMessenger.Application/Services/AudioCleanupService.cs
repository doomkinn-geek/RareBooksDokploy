using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Domain.Enums;
using Microsoft.Extensions.Hosting;

namespace MayMessenger.Application.Services;

public class AudioCleanupService : IHostedService, IDisposable
{
    private Timer? _timer;
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<AudioCleanupService> _logger;
    private readonly string _webRootPath;
    
    public AudioCleanupService(
        IServiceProvider serviceProvider, 
        ILogger<AudioCleanupService> logger,
        IConfiguration configuration)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        
        // Get web root path from configuration or use default
        _webRootPath = configuration["WebRootPath"] ?? Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
    }
    
    public Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Audio Cleanup Service starting...");
        
        // Run immediately on startup, then every 24 hours
        _timer = new Timer(DoWork, null, TimeSpan.Zero, TimeSpan.FromHours(24));
        
        return Task.CompletedTask;
    }
    
    private async void DoWork(object? state)
    {
        _logger.LogInformation("Starting audio cleanup task...");
        
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
            
            // Get all audio messages older than 7 days
            var cutoffDate = DateTime.UtcNow.AddDays(-7);
            var oldMessages = await unitOfWork.Messages.GetOldAudioMessagesAsync(cutoffDate);
            
            var audioFolder = Path.Combine(_webRootPath, "audio");
            int deletedCount = 0;
            int updatedCount = 0;
            
            foreach (var message in oldMessages)
            {
                if (!string.IsNullOrEmpty(message.FilePath))
                {
                    // Extract filename from path
                    var fileName = message.FilePath.TrimStart('/');
                    var fullPath = Path.Combine(_webRootPath, fileName);
                    
                    // Delete physical file
                    if (File.Exists(fullPath))
                    {
                        try
                        {
                            File.Delete(fullPath);
                            deletedCount++;
                            _logger.LogDebug($"Deleted audio file: {fullPath}");
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, $"Failed to delete audio file: {fullPath}");
                        }
                    }
                    
                    // Mark message as having no file
                    message.FilePath = null;
                    message.Content = "[Аудио удалено]";
                    updatedCount++;
                }
            }
            
            if (updatedCount > 0)
            {
                await unitOfWork.SaveChangesAsync();
            }
            
            _logger.LogInformation($"Audio cleanup completed. Deleted {deletedCount} files, updated {updatedCount} message records.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during audio cleanup task");
        }
    }
    
    public Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Audio Cleanup Service stopping...");
        _timer?.Change(Timeout.Infinite, 0);
        return Task.CompletedTask;
    }
    
    public void Dispose()
    {
        _timer?.Dispose();
    }
}
