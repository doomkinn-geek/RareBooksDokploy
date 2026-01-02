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
    private const int FcmFallbackAfterSeconds = 60; // Send FCM if SignalR fails for 60 seconds (increased from 30)
    private const int FcmRetryAfterSeconds = 600; // Retry FCM every 10 minutes if still pending (increased from 5 min)

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
        // DEDUPLICATION: Check if message was already delivered via DeliveryReceipt
        // If so, no need to retry - just delete the PendingAck
        var existingReceipt = await unitOfWork.DeliveryReceipts.GetByMessageAndUserAsync(
            ack.MessageId, ack.RecipientUserId);
        
        if (existingReceipt?.DeliveredAt != null)
        {
            _logger.LogDebug($"Message {ack.MessageId} already delivered to {ack.RecipientUserId}, removing PendingAck");
            await unitOfWork.PendingAcks.DeleteAsync(ack.Id);
            return;
        }
        
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
        
        // FCM FALLBACK: If SignalR has been failing for 60+ seconds, try FCM
        if (timeSinceCreation.TotalSeconds >= FcmFallbackAfterSeconds && _firebaseService.IsInitialized)
        {
            var timeSinceLastFcm = ack.LastRetryAt.HasValue ? DateTime.UtcNow - ack.LastRetryAt.Value : timeSinceCreation;
            
            // Only send FCM once every 10 minutes to avoid spam
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
    /// Only for new messages - status updates should NOT trigger push notifications
    /// </summary>
    private async Task TryFcmFallbackAsync(Domain.Entities.PendingAck ack, IUnitOfWork unitOfWork)
    {
        try
        {
            // IMPORTANT: Never send push for status updates - only for new messages
            // Status updates should be delivered via SignalR only
            if (ack.Type != Domain.Enums.AckType.Message)
            {
                _logger.LogDebug($"Skipping FCM fallback for non-message ack type: {ack.Type}");
                return;
            }
            
            // DEDUPLICATION: Check if already delivered via DeliveryReceipt
            var existingReceipt = await unitOfWork.DeliveryReceipts.GetByMessageAndUserAsync(
                ack.MessageId, ack.RecipientUserId);
            
            if (existingReceipt?.DeliveredAt != null)
            {
                _logger.LogDebug($"Message {ack.MessageId} already delivered, skipping FCM fallback");
                return;
            }
            
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
            
            // Prepare notification content for new message
            var title = $"Новое сообщение от {sender.DisplayName}";
            var body = message.Type switch
            {
                Domain.Enums.MessageType.Text => message.Content?.Length > 100 
                    ? message.Content.Substring(0, 100) + "..." 
                    : message.Content ?? "Сообщение",
                Domain.Enums.MessageType.Audio => "🎤 Голосовое сообщение",
                Domain.Enums.MessageType.Image => "📷 Изображение",
                Domain.Enums.MessageType.File => $"📎 Файл: {message.OriginalFileName ?? "Файл"}",
                _ => "Новое сообщение"
            };
            
            var data = new Dictionary<string, string>
            {
                { "chatId", message.ChatId.ToString() },
                { "messageId", message.Id.ToString() },
                { "type", "Message" }
            };
            
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

