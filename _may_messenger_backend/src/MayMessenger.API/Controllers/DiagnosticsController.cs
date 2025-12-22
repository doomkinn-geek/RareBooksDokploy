using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using MayMessenger.API.Hubs;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class DiagnosticsController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IHubContext<ChatHub> _hubContext;
    private readonly ILogger<DiagnosticsController> _logger;
    private static readonly DateTime _startTime = DateTime.UtcNow;
    private static int _totalMessagesProcessed = 0;
    private static int _duplicatesDetected = 0;
    private static readonly object _statsLock = new object();

    public DiagnosticsController(
        IUnitOfWork unitOfWork,
        IHubContext<ChatHub> hubContext,
        ILogger<DiagnosticsController> logger)
    {
        _unitOfWork = unitOfWork;
        _hubContext = hubContext;
        _logger = logger;
    }

    /// <summary>
    /// Get comprehensive system metrics for monitoring
    /// </summary>
    [HttpGet("metrics")]
    public async Task<ActionResult<object>> GetMetrics()
    {
        try
        {
            var now = DateTime.UtcNow;
            var uptime = now - _startTime;

            // Database metrics
            var allMessages = await _unitOfWork.Messages.GetAllAsync();
            var totalMessages = allMessages.Count();
            var allUsers = await _unitOfWork.Users.GetAllAsync();
            var totalUsers = allUsers.Count();
            var allChats = await _unitOfWork.Chats.GetAllAsync();
            var totalChats = allChats.Count();
            var onlineUsers = await _unitOfWork.Users.GetOnlineUsersAsync();
            var onlineCount = onlineUsers.Count();

            // Pending operations
            var pendingAcks = await _unitOfWork.PendingAcks.GetAllAsync();
            var pendingAckCount = pendingAcks.Count();
            var pendingByType = pendingAcks
                .GroupBy(a => a.Type)
                .ToDictionary(g => g.Key.ToString(), g => g.Count());

            // Recent activity (last hour)
            var oneHourAgo = now.AddHours(-1);
            var recentMessages = await _unitOfWork.Messages.GetMessagesAfterTimestampAsync(
                Guid.Empty, // Will be filtered by chat
                oneHourAgo,
                1000);
            var recentMessageCount = recentMessages.Count();

            // Status event metrics
            var recentStatusEvents = await _unitOfWork.MessageStatusEvents.GetAllAsync();
            var recentStatusEventCount = recentStatusEvents
                .Count(e => e.CreatedAt > oneHourAgo);

            var metrics = new
            {
                Timestamp = now,
                Uptime = new
                {
                    Days = uptime.Days,
                    Hours = uptime.Hours,
                    Minutes = uptime.Minutes,
                    TotalSeconds = uptime.TotalSeconds
                },
                Database = new
                {
                    TotalMessages = totalMessages,
                    TotalUsers = totalUsers,
                    TotalChats = totalChats,
                    OnlineUsers = onlineCount
                },
                Activity = new
                {
                    MessagesLastHour = recentMessageCount,
                    StatusEventsLastHour = recentStatusEventCount,
                    TotalMessagesProcessed = _totalMessagesProcessed,
                    DuplicatesDetected = _duplicatesDetected
                },
                PendingOperations = new
                {
                    TotalPendingAcks = pendingAckCount,
                    ByType = pendingByType
                },
                Performance = new
                {
                    AverageMessagesPerMinute = uptime.TotalMinutes > 0 
                        ? Math.Round(_totalMessagesProcessed / uptime.TotalMinutes, 2) 
                        : 0,
                    DuplicateRate = _totalMessagesProcessed > 0 
                        ? Math.Round((_duplicatesDetected * 100.0) / _totalMessagesProcessed, 2) 
                        : 0
                }
            };

            return Ok(metrics);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting diagnostics metrics");
            return StatusCode(500, "Error retrieving metrics");
        }
    }

    /// <summary>
    /// Get detailed SignalR connection information
    /// </summary>
    [HttpGet("signalr")]
    public ActionResult<object> GetSignalRInfo()
    {
        // Note: SignalR doesn't expose connection count directly
        // This would require custom tracking in ChatHub
        var info = new
        {
            HubPath = "/hubs/chat",
            Status = "Active",
            Features = new[]
            {
                "WebSockets",
                "Automatic Reconnect",
                "Heartbeat",
                "Incremental Sync",
                "Batch Operations"
            }
        };

        return Ok(info);
    }

    /// <summary>
    /// Get pending acks details for debugging
    /// </summary>
    [HttpGet("pending-acks")]
    public async Task<ActionResult<object>> GetPendingAcks([FromQuery] int take = 50)
    {
        try
        {
            var pendingAcks = await _unitOfWork.PendingAcks.GetAllAsync();
            var acks = pendingAcks
                .OrderByDescending(a => a.CreatedAt)
                .Take(take)
                .Select(a => new
                {
                    a.Id,
                    a.MessageId,
                    a.RecipientUserId,
                    Type = a.Type.ToString(),
                    a.RetryCount,
                    a.CreatedAt,
                    a.LastRetryAt,
                    Age = DateTime.UtcNow - a.CreatedAt
                })
                .ToList();

            return Ok(new
            {
                TotalCount = pendingAcks.Count(),
                Items = acks
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting pending acks");
            return StatusCode(500, "Error retrieving pending acks");
        }
    }

    /// <summary>
    /// Get recent status events for a message (for debugging)
    /// </summary>
    [HttpGet("status-events/{messageId}")]
    public async Task<ActionResult<object>> GetMessageStatusEvents(Guid messageId)
    {
        try
        {
            var events = await _unitOfWork.MessageStatusEvents.GetMessageEventsAsync(messageId);
            
            var eventsList = events.Select(e => new
            {
                e.Id,
                e.MessageId,
                Status = e.Status.ToString(),
                e.UserId,
                e.Source,
                e.Timestamp,
                e.CreatedAt
            }).ToList();

            var aggregateStatus = events.Any() 
                ? await _unitOfWork.MessageStatusEvents.CalculateAggregateStatusAsync(messageId)
                : Domain.Enums.MessageStatus.Sending;

            return Ok(new
            {
                MessageId = messageId,
                Events = eventsList,
                AggregateStatus = aggregateStatus.ToString(),
                EventCount = eventsList.Count
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error getting status events for message {messageId}");
            return StatusCode(500, "Error retrieving status events");
        }
    }

    /// <summary>
    /// Internal method to track message processing stats
    /// Called from MessagesController
    /// </summary>
    public static void IncrementMessageProcessed()
    {
        lock (_statsLock)
        {
            _totalMessagesProcessed++;
        }
    }

    /// <summary>
    /// Internal method to track duplicate detection
    /// Called from MessagesController when duplicate is detected
    /// </summary>
    public static void IncrementDuplicateDetected()
    {
        lock (_statsLock)
        {
            _duplicatesDetected++;
        }
    }

    /// <summary>
    /// Health check specifically for diagnostics
    /// </summary>
    [HttpGet("health")]
    [AllowAnonymous]
    public async Task<ActionResult<object>> GetHealth()
    {
        try
        {
            // Check database connectivity
            var canConnectToDb = false;
            try
            {
                await _unitOfWork.Users.GetAllAsync();
                canConnectToDb = true;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Database health check failed");
            }

            // Check pending acks queue health
            var pendingAcks = await _unitOfWork.PendingAcks.GetAllAsync();
            var oldAcks = pendingAcks.Count(a => DateTime.UtcNow - a.CreatedAt > TimeSpan.FromMinutes(5));
            var pendingAcksHealthy = oldAcks < 100; // Threshold: less than 100 acks older than 5 minutes

            var health = new
            {
                Status = canConnectToDb && pendingAcksHealthy ? "Healthy" : "Degraded",
                Timestamp = DateTime.UtcNow,
                Checks = new
                {
                    Database = canConnectToDb ? "OK" : "Failed",
                    PendingAcksQueue = pendingAcksHealthy ? "OK" : $"Warning: {oldAcks} old acks",
                }
            };

            return Ok(health);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in health check");
            return StatusCode(500, new { Status = "Unhealthy", Error = ex.Message });
        }
    }
}



