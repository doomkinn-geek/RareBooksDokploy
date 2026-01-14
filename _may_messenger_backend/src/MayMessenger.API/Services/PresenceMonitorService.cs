using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MayMessenger.API.Hubs;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Services;

/// <summary>
/// Background service that monitors user presence based on heartbeat timestamps
/// Marks users as offline if no heartbeat received for 45 seconds
/// Runs every 30 seconds for faster offline detection
/// </summary>
public class PresenceMonitorService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<PresenceMonitorService> _logger;
    private readonly IHubContext<ChatHub> _hubContext;
    
    // Reduced intervals for faster offline detection:
    // - Check every 30 seconds (was 60)
    // - Timeout after 45 seconds of no heartbeat (was 90)
    private const int CheckIntervalSeconds = 30;
    private const int HeartbeatTimeoutSeconds = 45;

    public PresenceMonitorService(
        IServiceProvider serviceProvider,
        ILogger<PresenceMonitorService> logger,
        IHubContext<ChatHub> hubContext)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _hubContext = hubContext;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("PresenceMonitorService started");

        // Wait 30 seconds before first check to let users connect
        await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CheckUserPresenceAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error checking user presence");
            }

            await Task.Delay(TimeSpan.FromSeconds(CheckIntervalSeconds), stoppingToken);
        }

        _logger.LogInformation("PresenceMonitorService stopped");
    }

    private async Task CheckUserPresenceAsync(CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

        // Get all users who are currently marked as online
        var onlineUsers = await unitOfWork.Users.GetOnlineUsersAsync();

        if (!onlineUsers.Any())
        {
            return;
        }

        var now = DateTime.UtcNow;
        var timeoutThreshold = now.AddSeconds(-HeartbeatTimeoutSeconds);
        var usersToMarkOffline = new List<Domain.Entities.User>();

        foreach (var user in onlineUsers)
        {
            // Check if user's last heartbeat is older than timeout threshold
            if (user.LastHeartbeatAt.HasValue && user.LastHeartbeatAt.Value < timeoutThreshold)
            {
                usersToMarkOffline.Add(user);
            }
            // Fallback: if LastHeartbeatAt is null but user is marked online, check LastSeenAt
            else if (!user.LastHeartbeatAt.HasValue && user.LastSeenAt.HasValue && user.LastSeenAt.Value < timeoutThreshold)
            {
                usersToMarkOffline.Add(user);
            }
        }

        if (usersToMarkOffline.Any())
        {
            _logger.LogInformation($"Marking {usersToMarkOffline.Count} users as offline due to heartbeat timeout");

            foreach (var user in usersToMarkOffline)
            {
                user.IsOnline = false;
                user.LastSeenAt = user.LastHeartbeatAt ?? user.LastSeenAt ?? DateTime.UtcNow;
                await unitOfWork.Users.UpdateAsync(user);

                // Notify all participants in user's chats about status change
                try
                {
                    await NotifyUserStatusChangedAsync(user.Id, false, user.LastSeenAt.Value, unitOfWork);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Error notifying status change for user {user.Id}");
                }
            }

            await unitOfWork.SaveChangesAsync(cancellationToken);
            
            _logger.LogInformation($"Successfully marked {usersToMarkOffline.Count} users as offline");
        }
    }

    private async Task NotifyUserStatusChangedAsync(Guid userId, bool isOnline, DateTime lastSeenAt, IUnitOfWork unitOfWork)
    {
        try
        {
            var chats = await unitOfWork.Chats.GetUserChatsAsync(userId);
            
            foreach (var chat in chats)
            {
                await _hubContext.Clients.Group(chat.Id.ToString())
                    .SendAsync("UserStatusChanged", userId.ToString(), isOnline, lastSeenAt);
            }
            
            _logger.LogInformation($"User {userId} status changed: {(isOnline ? "online" : "offline")} at {lastSeenAt:O}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error notifying user status change for user {userId}");
        }
    }
}

