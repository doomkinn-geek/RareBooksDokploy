using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MayMessenger.API.Hubs;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Application.Services;

namespace MayMessenger.API.Services;

/// <summary>
/// Background service that retries sending unacknowledged messages via SignalR.
/// Implements exponential backoff and FCM fallback for offline users.
/// Runs every 3 seconds to check for pending acks that need retry.
/// </summary>
public class AckRetryService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<AckRetryService> _logger;
    private readonly IHubContext<ChatHub> _hubContext;
    private readonly IFirebaseService _firebaseService;
    
    // Retry configuration with exponential backoff
    private const int RetryIntervalSeconds = 3;
    private const int MaxRetries = 10; // Increased from 5 to 10 for more reliable delivery
    private const int CleanupAfterHours = 24;
    
    // FCM fallback configuration
    private const int FcmFallbackAfterSeconds = 30; // Send FCM if SignalR fails for 30 seconds
    private const int FcmRetryAfterSeconds = 300; // Retry FCM every 5 minutes if still pending

    public AckRetryService(
        IServiceProvider serviceProvider,
        ILogger<AckRetryService> logger,
        IHubContext<ChatHub> hubContext,
        IFirebaseService firebaseService)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _hubContext = hubContext;
        _firebaseService = firebaseService;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("AckRetryService started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessPendingAcksAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing pending acks");
            }

            await Task.Delay(TimeSpan.FromSeconds(RetryIntervalSeconds), stoppingToken);
        }

        _logger.LogInformation("AckRetryService stopped");
    }

    private async Task ProcessPendingAcksAsync(CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

        // Get pending acks older than 5 seconds
        var olderThan = DateTime.UtcNow.AddSeconds(-RetryIntervalSeconds);
        var pendingAcks = await unitOfWork.PendingAcks.GetPendingAcksAsync(olderThan, MaxRetries);

        if (pendingAcks.Any())
        {
            _logger.LogInformation($"Processing {pendingAcks.Count()} pending acks");

            foreach (var ack in pendingAcks)
            {
                try
                {
                    await RetryAckAsync(ack, unitOfWork);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error retrying ack {ack.Id}");
                }
            }
        }

        // Cleanup old acks (older than 24 hours)
        try
        {
            var cleanupOlderThan = DateTime.UtcNow.AddHours(-CleanupAfterHours);
            await unitOfWork.PendingAcks.CleanupOldAcksAsync(cleanupOlderThan);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error cleaning up old pending acks");
        }
    }

    private async Task RetryAckAsync(Domain.Entities.PendingAck ack, IUnitOfWork unitOfWork)
    {
        // Check if enough time has passed based on exponential backoff
        // Delays: 3s, 6s, 12s, 24s, 48s (approximately)
        var minDelaySeconds = RetryIntervalSeconds * Math.Pow(2, ack.RetryCount);
        var timeSinceCreation = DateTime.UtcNow - ack.CreatedAt;
        var timeSinceLastRetry = ack.LastRetryAt.HasValue ? DateTime.UtcNow - ack.LastRetryAt.Value : timeSinceCreation;
        
        if (timeSinceLastRetry.TotalSeconds < minDelaySeconds)
        {
            // Not time to retry yet (exponential backoff)
            return;
        }
        
        // FCM FALLBACK: If SignalR has been failing for 30+ seconds, try FCM
        if (timeSinceCreation.TotalSeconds >= FcmFallbackAfterSeconds && _firebaseService.IsInitialized)
        {
            var timeSinceLastFcm = ack.LastRetryAt.HasValue ? DateTime.UtcNow - ack.LastRetryAt.Value : timeSinceCreation;
            
            // Only send FCM once every 5 minutes to avoid spam
            if (timeSinceLastFcm.TotalSeconds >= FcmRetryAfterSeconds)
            {
                await TryFcmFallbackAsync(ack, unitOfWork);
            }
        }
        
        // Update retry count
        ack.RetryCount++;
        ack.LastRetryAt = DateTime.UtcNow;

        if (ack.RetryCount >= MaxRetries)
        {
            _logger.LogWarning($"Pending ack {ack.Id} exceeded max retries ({MaxRetries}), removing. " +
                              $"Message: {ack.MessageId}, Recipient: {ack.RecipientUserId}");
            await unitOfWork.PendingAcks.DeleteAsync(ack.Id);
            return;
        }

        await unitOfWork.PendingAcks.UpdateAsync(ack);

        // Retry sending via SignalR
        try
        {
            if (ack.Type == Domain.Enums.AckType.Message)
            {
                // Resend message to specific user
                var message = ack.Message;
                var sender = await unitOfWork.Users.GetByIdAsync(message.SenderId);

                if (sender != null)
                {
                    var messageDto = new MessageDto
                    {
                        Id = message.Id,
                        ChatId = message.ChatId,
                        SenderId = message.SenderId,
                        SenderName = sender.DisplayName,
                        Type = message.Type,
                        Content = message.Content,
                        FilePath = message.FilePath,
                        Status = message.Status,
                        CreatedAt = message.CreatedAt,
                        ClientMessageId = message.ClientMessageId
                    };

                    // Send to specific user
                    await _hubContext.Clients.User(ack.RecipientUserId.ToString())
                        .SendAsync("ReceiveMessage", messageDto);

                    _logger.LogInformation($"Resent message {message.Id} to user {ack.RecipientUserId} (retry {ack.RetryCount}/{MaxRetries})");
                }
            }
            else if (ack.Type == Domain.Enums.AckType.StatusUpdate)
            {
                // Resend status update to specific user
                var message = ack.Message;

                await _hubContext.Clients.User(ack.RecipientUserId.ToString())
                    .SendAsync("MessageStatusUpdated", message.Id, (int)message.Status);

                _logger.LogInformation($"Resent status update for message {message.Id} to user {ack.RecipientUserId} (retry {ack.RetryCount}/{MaxRetries})");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error retrying ack {ack.Id} (type: {ack.Type})");
        }
    }
    
    /// <summary>
    /// Fallback to FCM push notification when SignalR delivery fails
    /// </summary>
    private async Task TryFcmFallbackAsync(Domain.Entities.PendingAck ack, IUnitOfWork unitOfWork)
    {
        try
        {
            // Get FCM tokens for the recipient
            var tokens = await unitOfWork.FcmTokens.GetActiveTokensForUserAsync(ack.RecipientUserId);
            
            if (!tokens.Any())
            {
                _logger.LogInformation($"No FCM tokens for user {ack.RecipientUserId}, skipping FCM fallback");
                return;
            }
            
            var message = ack.Message;
            var sender = await unitOfWork.Users.GetByIdAsync(message.SenderId);
            
            if (sender == null)
            {
                _logger.LogWarning($"Sender {message.SenderId} not found for FCM fallback");
                return;
            }
            
            // Prepare notification content
            string title, body;
            var data = new Dictionary<string, string>
            {
                { "chatId", message.ChatId.ToString() },
                { "messageId", message.Id.ToString() },
                { "type", ack.Type.ToString() }
            };
            
            if (ack.Type == Domain.Enums.AckType.Message)
            {
                title = $"Новое сообщение от {sender.DisplayName}";
                body = message.Type switch
                {
                    Domain.Enums.MessageType.Text => message.Content?.Length > 100 
                        ? message.Content.Substring(0, 100) + "..." 
                        : message.Content ?? "Сообщение",
                    Domain.Enums.MessageType.Audio => "🎤 Голосовое сообщение",
                    Domain.Enums.MessageType.Image => "📷 Изображение",
                    _ => "Новое сообщение"
                };
            }
            else // StatusUpdate
            {
                title = "Обновление статуса сообщения";
                body = $"Сообщение {message.Status}";
            }
            
            // Send FCM to all tokens
            int successCount = 0;
            foreach (var token in tokens)
            {
                var (success, shouldDeactivate) = await _firebaseService.SendNotificationAsync(
                    token.Token,
                    title,
                    body,
                    data);
                
                if (success)
                {
                    successCount++;
                    token.LastUsedAt = DateTime.UtcNow;
                }
                else if (shouldDeactivate)
                {
                    _logger.LogWarning($"Deactivating invalid FCM token for user {ack.RecipientUserId}");
                    await unitOfWork.FcmTokens.DeactivateTokenAsync(token.Token);
                }
            }
            
            if (successCount > 0)
            {
                _logger.LogInformation($"FCM fallback sent to {successCount} device(s) for user {ack.RecipientUserId}");
                await unitOfWork.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error in FCM fallback for ack {ack.Id}");
        }
    }
}

