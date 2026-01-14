using MayMessenger.Domain.Interfaces;
using Microsoft.AspNetCore.SignalR;
using MayMessenger.API.Hubs;

namespace MayMessenger.API.Services;

/// <summary>
/// Background service that monitors user presence based on heartbeat
/// Automatically marks users as offline if they haven't sent heartbeat in 2 minutes
/// </summary>
public class PresenceMonitorService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<PresenceMonitorService> _logger;
    private readonly TimeSpan _checkInterval = TimeSpan.FromSeconds(60); // Check every 60 seconds
    private readonly TimeSpan _heartbeatTimeout = TimeSpan.FromMinutes(2); // 2 minutes without heartbeat = offline

    public PresenceMonitorService(
        IServiceProvider serviceProvider,
        ILogger<PresenceMonitorService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("[PresenceMonitor] Service started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CheckAndUpdatePresence();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "[PresenceMonitor] Error during presence check");
            }

            await Task.Delay(_checkInterval, stoppingToken);
        }

        _logger.LogInformation("[PresenceMonitor] Service stopped");
    }

    private async Task CheckAndUpdatePresence()
    {
        using var scope = _serviceProvider.CreateScope();
        var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
        var hubContext = scope.ServiceProvider.GetRequiredService<IHubContext<ChatHub>>();

        var cutoffTime = DateTime.UtcNow - _heartbeatTimeout;

        // Find users who are marked online but haven't sent heartbeat recently
        var staleOnlineUsers = await unitOfWork.Users.GetStaleOnlineUsersAsync(cutoffTime);

        if (staleOnlineUsers.Any())
        {
            _logger.LogInformation($"[PresenceMonitor] Found {staleOnlineUsers.Count} users with stale heartbeat");

            foreach (var user in staleOnlineUsers)
            {
                try
                {
                    // Mark user as offline
                    user.IsOnline = false;
                    user.LastSeenAt = DateTime.UtcNow;
                    await unitOfWork.Users.UpdateAsync(user);

                    _logger.LogInformation($"[PresenceMonitor] User {user.Id} ({user.DisplayName}) marked offline due to heartbeat timeout");

                    // Notify all participants in user's chats about status change
                    var userChats = await unitOfWork.Chats.GetUserChatsAsync(user.Id);
                    
                    foreach (var chat in userChats)
                    {
                        try
                        {
                            // Send status update to chat group
                            await hubContext.Clients.Group(chat.Id.ToString())
                                .SendAsync("UserStatusChanged", new
                                {
                                    UserId = user.Id,
                                    IsOnline = false,
                                    LastSeenAt = user.LastSeenAt
                                });
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, $"[PresenceMonitor] Failed to notify chat {chat.Id} about user {user.Id} status change");
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"[PresenceMonitor] Failed to update user {user.Id} presence");
                }
            }

            await unitOfWork.SaveChangesAsync();
            _logger.LogInformation($"[PresenceMonitor] Successfully updated {staleOnlineUsers.Count} users to offline");
        }
    }
}
