using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Services;

/// <summary>
/// Background service that cleans up video files after all participants have received them.
/// - For private chats: deletes video when receiver has DeliveredAt set
/// - For group chats: deletes video when all participants (except sender) have DeliveredAt set,
///   or after 7 days (fallback for offline users)
/// Runs every 5 minutes
/// </summary>
public class VideoCleanupService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<VideoCleanupService> _logger;
    private readonly IWebHostEnvironment _environment;
    
    private const int CheckIntervalMinutes = 5;
    private const int MaxAgeForGroupVideosDays = 7;

    public VideoCleanupService(
        IServiceProvider serviceProvider,
        ILogger<VideoCleanupService> logger,
        IWebHostEnvironment environment)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _environment = environment;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("VideoCleanupService started");

        // Wait 2 minutes before first check
        await Task.Delay(TimeSpan.FromMinutes(2), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CleanupDeliveredVideosAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during video cleanup");
            }

            await Task.Delay(TimeSpan.FromMinutes(CheckIntervalMinutes), stoppingToken);
        }

        _logger.LogInformation("VideoCleanupService stopped");
    }

    private async Task CleanupDeliveredVideosAsync(CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

        // Get all video messages that still have files
        var videoMessages = await unitOfWork.Messages.GetVideoMessagesWithFilesAsync();
        
        if (!videoMessages.Any())
        {
            return;
        }

        _logger.LogInformation($"Checking {videoMessages.Count()} video messages for cleanup");
        
        var deletedCount = 0;
        var now = DateTime.UtcNow;
        var maxAgeThreshold = now.AddDays(-MaxAgeForGroupVideosDays);

        foreach (var message in videoMessages)
        {
            try
            {
                var chat = await unitOfWork.Chats.GetByIdAsync(message.ChatId);
                if (chat == null)
                {
                    continue;
                }

                var shouldDelete = false;
                var reason = "";

                // Get delivery receipts for this message
                var receipts = await unitOfWork.DeliveryReceipts.GetReceiptsForMessageAsync(message.Id);
                var recipientCount = chat.Participants.Count - 1; // Exclude sender
                var deliveredCount = receipts.Count(r => r.DeliveredAt.HasValue);

                if (chat.Type == ChatType.Private)
                {
                    // For private chats, delete when the single recipient has received
                    if (deliveredCount >= 1)
                    {
                        shouldDelete = true;
                        reason = "delivered to recipient in private chat";
                    }
                }
                else
                {
                    // For group chats, check if all participants received
                    if (deliveredCount >= recipientCount)
                    {
                        shouldDelete = true;
                        reason = $"delivered to all {recipientCount} recipients in group";
                    }
                    // Fallback: delete after 7 days regardless of delivery status
                    else if (message.CreatedAt < maxAgeThreshold)
                    {
                        shouldDelete = true;
                        reason = $"exceeded {MaxAgeForGroupVideosDays} day age limit (delivered to {deliveredCount}/{recipientCount})";
                    }
                }

                if (shouldDelete && !string.IsNullOrEmpty(message.FilePath))
                {
                    var filePath = Path.Combine(_environment.WebRootPath, message.FilePath.TrimStart('/'));
                    
                    if (File.Exists(filePath))
                    {
                        File.Delete(filePath);
                        deletedCount++;
                        _logger.LogInformation($"[VIDEO_CLEANUP] Deleted video {message.Id}: {reason}");
                    }
                    
                    // Clear FilePath to mark as cleaned up (keep message for history)
                    // Note: Clients should use local cache after download
                    message.FilePath = null;
                    await unitOfWork.Messages.UpdateAsync(message);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error processing video message {message.Id} for cleanup");
            }
        }

        if (deletedCount > 0)
        {
            await unitOfWork.SaveChangesAsync(cancellationToken);
            _logger.LogInformation($"[VIDEO_CLEANUP] Cleaned up {deletedCount} video files");
        }
    }
}
