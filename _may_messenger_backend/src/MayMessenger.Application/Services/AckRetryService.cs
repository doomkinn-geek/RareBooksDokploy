using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MayMessenger.API.Hubs;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.Application.Services;

/// <summary>
/// Background service that retries sending unacknowledged messages via SignalR.
/// Runs every 5 seconds to check for pending acks that need retry.
/// </summary>
public class AckRetryService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<AckRetryService> _logger;
    private readonly IHubContext<ChatHub> _hubContext;
    private const int RetryIntervalSeconds = 5;
    private const int MaxRetries = 3;
    private const int CleanupAfterHours = 24;

    public AckRetryService(
        IServiceProvider serviceProvider,
        ILogger<AckRetryService> logger,
        IHubContext<ChatHub> hubContext)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _hubContext = hubContext;
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
        // Update retry count
        ack.RetryCount++;
        ack.LastRetryAt = DateTime.UtcNow;

        if (ack.RetryCount >= MaxRetries)
        {
            _logger.LogWarning($"Pending ack {ack.Id} exceeded max retries ({MaxRetries}), removing");
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
                        CreatedAt = message.CreatedAt
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
}

