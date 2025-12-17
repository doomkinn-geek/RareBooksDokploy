using Microsoft.AspNetCore.Mvc;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DiagnosticsController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<DiagnosticsController> _logger;
    private static readonly List<string> _recentLogs = new();
    private static readonly object _logLock = new();

    public DiagnosticsController(IUnitOfWork unitOfWork, ILogger<DiagnosticsController> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public static void AddLog(string log)
    {
        lock (_logLock)
        {
            _recentLogs.Add($"[{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss.fff}] {log}");
            if (_recentLogs.Count > 100)
            {
                _recentLogs.RemoveAt(0);
            }
        }
    }

    [HttpGet("logs")]
    public ActionResult<IEnumerable<string>> GetLogs()
    {
        lock (_logLock)
        {
            return Ok(_recentLogs.ToList());
        }
    }

    [HttpDelete("logs")]
    public ActionResult ClearLogs()
    {
        lock (_logLock)
        {
            _recentLogs.Clear();
        }
        return Ok(new { message = "Logs cleared" });
    }

    [HttpGet("health")]
    public async Task<ActionResult> GetHealth()
    {
        try
        {
            var usersCount = (await _unitOfWork.Users.GetAllAsync()).Count();
            var chatsCount = (await _unitOfWork.Chats.GetAllAsync()).Count();
            var messagesCount = (await _unitOfWork.Messages.GetAllAsync()).Count();

            return Ok(new
            {
                status = "Healthy",
                timestamp = DateTime.UtcNow,
                database = new
                {
                    connected = true,
                    usersCount,
                    chatsCount,
                    messagesCount
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new
            {
                status = "Unhealthy",
                error = ex.Message
            });
        }
    }

    /// <summary>
    /// Get full message lifecycle information for debugging
    /// </summary>
    [HttpGet("message/{messageId}")]
    public async Task<ActionResult> GetMessageDiagnostics(Guid messageId)
    {
        try
        {
            var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
            if (message == null)
            {
                return NotFound(new { error = "Message not found" });
            }

            var chat = await _unitOfWork.Chats.GetByIdAsync(message.ChatId);
            var receipts = await _unitOfWork.DeliveryReceipts.GetByMessageIdAsync(messageId);

            var receiptDetails = new List<object>();
            foreach (var receipt in receipts)
            {
                var user = await _unitOfWork.Users.GetByIdAsync(receipt.UserId);
                receiptDetails.Add(new
                {
                    userId = receipt.UserId,
                    userName = user?.DisplayName ?? "Unknown",
                    deliveredAt = receipt.DeliveredAt,
                    readAt = receipt.ReadAt
                });
            }

            return Ok(new
            {
                message = new
                {
                    id = message.Id,
                    chatId = message.ChatId,
                    senderId = message.SenderId,
                    senderName = message.Sender?.DisplayName,
                    type = message.Type.ToString(),
                    content = message.Content,
                    status = message.Status.ToString(),
                    createdAt = message.CreatedAt,
                    deliveredAt = message.DeliveredAt,
                    readAt = message.ReadAt
                },
                chat = new
                {
                    id = chat?.Id,
                    type = chat?.Type.ToString(),
                    participantsCount = chat?.Participants.Count
                },
                deliveryReceipts = receiptDetails,
                summary = new
                {
                    totalParticipants = chat?.Participants.Count ?? 0,
                    deliveredCount = receipts.Count(r => r.DeliveredAt != null),
                    readCount = receipts.Count(r => r.ReadAt != null),
                    pendingDelivery = (chat?.Participants.Count ?? 0) - 1 - receipts.Count(r => r.DeliveredAt != null)
                }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error getting diagnostics for message {messageId}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Get user's SignalR connection state
    /// </summary>
    [HttpGet("user/{userId}/connection-state")]
    public async Task<ActionResult> GetUserConnectionState(Guid userId)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdAsync(userId);
            if (user == null)
            {
                return NotFound(new { error = "User not found" });
            }

            // Note: In a real implementation, you would track SignalR connections
            // For now, return basic user info
            return Ok(new
            {
                userId = user.Id,
                displayName = user.DisplayName,
                phoneNumber = user.PhoneNumber,
                createdAt = user.CreatedAt,
                // Connection info would come from a connection tracking service
                connectionStatus = "Unknown (requires connection tracking implementation)"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error getting connection state for user {userId}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Get delivery receipts for a specific message
    /// </summary>
    [HttpGet("delivery-receipts/{messageId}")]
    public async Task<ActionResult> GetDeliveryReceipts(Guid messageId)
    {
        try
        {
            var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
            if (message == null)
            {
                return NotFound(new { error = "Message not found" });
            }

            var receipts = await _unitOfWork.DeliveryReceipts.GetByMessageIdAsync(messageId);
            var receiptDetails = new List<object>();

            foreach (var receipt in receipts)
            {
                var user = await _unitOfWork.Users.GetByIdAsync(receipt.UserId);
                receiptDetails.Add(new
                {
                    userId = receipt.UserId,
                    userName = user?.DisplayName ?? "Unknown",
                    phoneNumber = user?.PhoneNumber ?? "Unknown",
                    deliveredAt = receipt.DeliveredAt,
                    deliveredAgo = receipt.DeliveredAt.HasValue 
                        ? $"{(DateTime.UtcNow - receipt.DeliveredAt.Value).TotalSeconds:F0}s ago"
                        : "Not delivered",
                    readAt = receipt.ReadAt,
                    readAgo = receipt.ReadAt.HasValue
                        ? $"{(DateTime.UtcNow - receipt.ReadAt.Value).TotalSeconds:F0}s ago"
                        : "Not read"
                });
            }

            return Ok(new
            {
                messageId,
                totalReceipts = receipts.Count(),
                receipts = receiptDetails
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error getting delivery receipts for message {messageId}");
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Get recent messages with their status
    /// </summary>
    [HttpGet("recent-messages")]
    public async Task<ActionResult> GetRecentMessages([FromQuery] int count = 20)
    {
        try
        {
            var allMessages = await _unitOfWork.Messages.GetAllAsync();
            var recentMessages = allMessages
                .OrderByDescending(m => m.CreatedAt)
                .Take(count)
                .Select(m => new
                {
                    id = m.Id,
                    chatId = m.ChatId,
                    senderName = m.Sender?.DisplayName ?? "Unknown",
                    type = m.Type.ToString(),
                    status = m.Status.ToString(),
                    createdAt = m.CreatedAt,
                    deliveredAt = m.DeliveredAt,
                    readAt = m.ReadAt,
                    ageSeconds = (DateTime.UtcNow - m.CreatedAt).TotalSeconds
                })
                .ToList();

            return Ok(new
            {
                count = recentMessages.Count,
                messages = recentMessages
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting recent messages");
            return StatusCode(500, new { error = ex.Message });
        }
    }
}

