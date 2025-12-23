using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Hubs;

[Authorize]
public class ChatHub : Hub
{
    private readonly IUnitOfWork _unitOfWork;
    
    public ChatHub(IUnitOfWork unitOfWork)
    {
        _unitOfWork = unitOfWork;
    }
    
    private Guid GetCurrentUserId()
    {
        var userIdClaim = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }
    
    public override async Task OnConnectedAsync()
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user != null)
        {
            // Update user online status and heartbeat
            user.IsOnline = true;
            user.LastSeenAt = DateTime.UtcNow;
            user.LastHeartbeatAt = DateTime.UtcNow;
            await _unitOfWork.Users.UpdateAsync(user);
            await _unitOfWork.SaveChangesAsync();
            
            // Notify all participants in user's chats about status change
            await NotifyUserStatusChanged(userId, true, DateTime.UtcNow);
        }
        
        // Join user's chats
        var chats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
        
        foreach (var chat in chats)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, chat.Id.ToString());
        }
        
        Console.WriteLine($"[ChatHub] User {userId} connected. ConnectionId: {Context.ConnectionId}");
        
        await base.OnConnectedAsync();
    }
    
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        try
        {
            var userId = GetCurrentUserId();
            var user = await _unitOfWork.Users.GetByIdAsync(userId);
            
            if (user != null)
            {
                // Update user offline status
                user.IsOnline = false;
                user.LastSeenAt = DateTime.UtcNow;
                await _unitOfWork.Users.UpdateAsync(user);
                await _unitOfWork.SaveChangesAsync();
                
                // Notify all participants in user's chats about status change
                await NotifyUserStatusChanged(userId, false, DateTime.UtcNow);
            }
        }
        catch (Exception ex)
        {
            // Log error but don't throw - disconnection should always succeed
            Console.WriteLine($"[ChatHub] Error in OnDisconnectedAsync: {ex.Message}");
        }
        
        await base.OnDisconnectedAsync(exception);
    }
    
    public async Task JoinChat(string chatId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, chatId);
    }
    
    public async Task LeaveChat(string chatId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, chatId);
    }
    
    /// <summary>
    /// DEPRECATED: Use REST API POST /api/messages instead for better reliability and idempotency
    /// This method is kept for backward compatibility but should not be used
    /// </summary>
    [Obsolete("Use REST API POST /api/messages instead. This method will be removed in future versions.")]
    public Task SendMessage(SendMessageDto dto)
    {
        // Log warning that deprecated method is being used
        Console.WriteLine($"[WARNING] Deprecated SendMessage method called via SignalR. Client should use REST API instead.");
        
        // Return error to client
        throw new InvalidOperationException("SendMessage via SignalR is deprecated. Please use REST API POST /api/messages instead.");
    }
    
    public async Task MessageDelivered(Guid messageId, Guid chatId)
    {
        // #region agent log - Hypothesis C/E: Check ACK received
        Console.WriteLine($"[DEBUG_ACK_A] MessageDelivered called for message {messageId}, chat {chatId}");
        // #endregion
        var userId = GetCurrentUserId();
        // #region agent log - Hypothesis C/E
        Console.WriteLine($"[DEBUG_ACK_B] UserId: {userId}");
        // #endregion
        var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
        
        if (message == null) 
        {
            // #region agent log - Hypothesis C/E
            Console.WriteLine($"[DEBUG_ACK_C] Message not found: {messageId}");
            // #endregion
            return;
        }
        
        // Don't create receipt for sender's own message
        if (message.SenderId == userId) 
        {
            // #region agent log - Hypothesis C/E
            Console.WriteLine($"[DEBUG_ACK_D] Skipping ACK for own message");
            // #endregion
            return;
        }
        
        // Create or update delivery receipt for this user
        var receipt = await _unitOfWork.DeliveryReceipts.GetByMessageAndUserAsync(messageId, userId);
        
        if (receipt == null)
        {
            receipt = new DeliveryReceipt
            {
                MessageId = messageId,
                UserId = userId,
                DeliveredAt = DateTime.UtcNow
            };
            await _unitOfWork.DeliveryReceipts.AddAsync(receipt);
        }
        else if (receipt.DeliveredAt == null)
        {
            receipt.DeliveredAt = DateTime.UtcNow;
            await _unitOfWork.DeliveryReceipts.UpdateAsync(receipt);
        }
        
        // EVENT SOURCING: Create status event instead of directly updating message
        await _unitOfWork.MessageStatusEvents.CreateEventAsync(
            messageId, 
            MessageStatus.Delivered, 
            userId, 
            "SignalR");
        
        // Calculate aggregate status based on all events
        var aggregateStatus = await _unitOfWork.MessageStatusEvents.CalculateAggregateStatusAsync(messageId);
        
        // Update message status if it changed
        if (message.Status != aggregateStatus)
        {
            message.Status = aggregateStatus;
            if (aggregateStatus == MessageStatus.Delivered && message.DeliveredAt == null)
            {
            message.DeliveredAt = DateTime.UtcNow;
            }
            await _unitOfWork.Messages.UpdateAsync(message);
            
            // #region agent log - Hypothesis C: Check MessageStatusUpdated sending
            Console.WriteLine($"[DEBUG_STATUS_A] Sending MessageStatusUpdated for message {messageId}, status {aggregateStatus} to group {chatId}");
            // #endregion
            // Notify all participants about status change
            await Clients.Group(chatId.ToString()).SendAsync("MessageStatusUpdated", messageId, (int)aggregateStatus);
            // #region agent log - Hypothesis C
            Console.WriteLine($"[DEBUG_STATUS_B] MessageStatusUpdated sent successfully");
            // #endregion
        }
        else
        {
            // #region agent log - Hypothesis C
            Console.WriteLine($"[DEBUG_STATUS_C] Status unchanged for message {messageId}, current: {message.Status}, aggregate: {aggregateStatus}");
            // #endregion
        }
        
            await _unitOfWork.SaveChangesAsync();
    }
    
    public async Task MessageRead(Guid messageId, Guid chatId)
    {
        var userId = GetCurrentUserId();
        var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (message == null || chat == null) return;
        
        // Don't create receipt for sender's own message
        if (message.SenderId == userId) return;
        
        // Create or update delivery receipt for this user
        var receipt = await _unitOfWork.DeliveryReceipts.GetByMessageAndUserAsync(messageId, userId);
        
        if (receipt == null)
        {
            receipt = new DeliveryReceipt
            {
                MessageId = messageId,
                UserId = userId,
                DeliveredAt = DateTime.UtcNow,
                ReadAt = DateTime.UtcNow
            };
            await _unitOfWork.DeliveryReceipts.AddAsync(receipt);
        }
        else if (receipt.ReadAt == null)
        {
            receipt.ReadAt = DateTime.UtcNow;
            if (receipt.DeliveredAt == null)
            {
                receipt.DeliveredAt = DateTime.UtcNow;
            }
            await _unitOfWork.DeliveryReceipts.UpdateAsync(receipt);
        }
        
        // EVENT SOURCING: Create status event instead of directly updating message
        await _unitOfWork.MessageStatusEvents.CreateEventAsync(
            messageId, 
            MessageStatus.Read, 
            userId, 
            "SignalR");
        
        // Calculate aggregate status based on all events
        var aggregateStatus = await _unitOfWork.MessageStatusEvents.CalculateAggregateStatusAsync(messageId);
            
        // Update message status if it changed
        if (message.Status != aggregateStatus)
        {
            message.Status = aggregateStatus;
            if (aggregateStatus == MessageStatus.Read && message.ReadAt == null)
            {
                message.ReadAt = DateTime.UtcNow;
            }
            await _unitOfWork.Messages.UpdateAsync(message);
            
            // Notify all participants about status change
            await Clients.Group(chatId.ToString()).SendAsync("MessageStatusUpdated", messageId, (int)aggregateStatus);
        }
        
        await _unitOfWork.SaveChangesAsync();
    }
    
    public async Task TypingIndicator(Guid chatId, bool isTyping)
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        // Notify others in the chat (except sender)
        // Include chatId so clients know which chat the typing indicator is for
        await Clients.OthersInGroup(chatId.ToString()).SendAsync("UserTyping", userId, user?.DisplayName ?? "Unknown", isTyping, chatId.ToString());
    }
    
    /// <summary>
    /// Batch mark multiple messages with a specific status
    /// Optimized for group chats where user reads multiple messages at once
    /// </summary>
    public async Task BatchMarkMessagesAs(Guid chatId, List<Guid> messageIds, MessageStatus status)
    {
        if (messageIds == null || !messageIds.Any() || messageIds.Count > 100)
        {
            Console.WriteLine($"[ChatHub] Invalid batch size: {messageIds?.Count ?? 0}");
            return;
        }
        
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
        {
            Console.WriteLine($"[ChatHub] Chat {chatId} not found");
            return;
        }
        
        var updatedMessages = new List<Guid>();
        
        foreach (var messageId in messageIds)
        {
            var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
            if (message == null || message.SenderId == userId) continue;
            
            // Create or update delivery receipt
            var receipt = await _unitOfWork.DeliveryReceipts.GetByMessageAndUserAsync(messageId, userId);
            
            if (receipt == null)
            {
                receipt = new DeliveryReceipt
                {
                    MessageId = messageId,
                    UserId = userId,
                    DeliveredAt = status >= MessageStatus.Delivered ? DateTime.UtcNow : null,
                    ReadAt = status >= MessageStatus.Read ? DateTime.UtcNow : null
                };
                await _unitOfWork.DeliveryReceipts.AddAsync(receipt);
            }
            else
            {
                if (status >= MessageStatus.Delivered && receipt.DeliveredAt == null)
                {
                    receipt.DeliveredAt = DateTime.UtcNow;
                }
                if (status >= MessageStatus.Read && receipt.ReadAt == null)
                {
                    receipt.ReadAt = DateTime.UtcNow;
                }
                await _unitOfWork.DeliveryReceipts.UpdateAsync(receipt);
            }
            
            // EVENT SOURCING: Create status event
            await _unitOfWork.MessageStatusEvents.CreateEventAsync(messageId, status, userId, "SignalR-Batch");
            
            // Calculate aggregate status
            var aggregateStatus = await _unitOfWork.MessageStatusEvents.CalculateAggregateStatusAsync(messageId);
            
            // Update message if status changed
            if (message.Status != aggregateStatus)
            {
                message.Status = aggregateStatus;
                if (aggregateStatus == MessageStatus.Delivered && message.DeliveredAt == null)
                {
                    message.DeliveredAt = DateTime.UtcNow;
                }
                if (aggregateStatus == MessageStatus.Read && message.ReadAt == null)
                {
                    message.ReadAt = DateTime.UtcNow;
                }
                await _unitOfWork.Messages.UpdateAsync(message);
                updatedMessages.Add(messageId);
            }
        }
        
        await _unitOfWork.SaveChangesAsync();
        
        // Notify about all updated messages in one batch
        if (updatedMessages.Any())
        {
            await Clients.Group(chatId.ToString()).SendAsync("BatchMessageStatusUpdated", updatedMessages, (int)status);
        }
        
        Console.WriteLine($"[ChatHub] Batch updated {updatedMessages.Count} messages to status {status}");
    }
    
    /// <summary>
    /// Client acknowledges that it received a message via SignalR
    /// </summary>
    public async Task AckMessageReceived(Guid messageId)
    {
        var userId = GetCurrentUserId();
        
        try
        {
            // Remove pending ack for this message
            await _unitOfWork.PendingAcks.DeleteByMessageAndRecipientAsync(messageId, userId, AckType.Message);
            
            Console.WriteLine($"[ACK] Message {messageId} acknowledged by user {userId}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ACK] Error processing message ack: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Client acknowledges that it received a status update via SignalR
    /// </summary>
    public async Task AckStatusUpdate(Guid messageId, int status)
    {
        var userId = GetCurrentUserId();
        
        try
        {
            // Remove pending ack for this status update
            await _unitOfWork.PendingAcks.DeleteByMessageAndRecipientAsync(messageId, userId, AckType.StatusUpdate);
            
            Console.WriteLine($"[ACK] Status update for message {messageId} (status: {status}) acknowledged by user {userId}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ACK] Error processing status ack: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Client sends heartbeat to keep connection alive and update presence
    /// Called every 30 seconds from client
    /// </summary>
    public async Task Heartbeat()
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user != null)
        {
            user.LastHeartbeatAt = DateTime.UtcNow;
            user.IsOnline = true;
            await _unitOfWork.Users.UpdateAsync(user);
            await _unitOfWork.SaveChangesAsync();
        }
        
        // Send Pong back to client
        await Clients.Caller.SendAsync("Pong");
    }
    
    /// <summary>
    /// Incremental sync - client requests all missed events since last sync
    /// </summary>
    public async Task IncrementalSync(DateTime lastSyncTimestamp, List<string>? chatIds = null)
    {
        var userId = GetCurrentUserId();
        
        Console.WriteLine($"[ChatHub] IncrementalSync requested by user {userId} since {lastSyncTimestamp:O}");
        
        try
        {
            // Get user's chats or use provided chatIds
            List<Guid> targetChatIds;
            if (chatIds != null && chatIds.Any())
            {
                targetChatIds = chatIds.Select(id => Guid.Parse(id)).ToList();
            }
            else
            {
                var chats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
                targetChatIds = chats.Select(c => c.Id).ToList();
            }
            
            // Collect all missed messages and status updates
            var missedMessages = new List<object>();
            var missedStatusUpdates = new List<object>();
            
            foreach (var chatId in targetChatIds)
            {
                // Get messages created or updated after lastSyncTimestamp
                var messages = await _unitOfWork.Messages.GetMessagesAfterTimestampAsync(
                    chatId, 
                    lastSyncTimestamp, 
                    take: 100);
                
                foreach (var msg in messages)
                {
                    var sender = await _unitOfWork.Users.GetByIdAsync(msg.SenderId);
                    missedMessages.Add(new
                    {
                        Id = msg.Id,
                        ChatId = msg.ChatId,
                        SenderId = msg.SenderId,
                        SenderName = sender?.DisplayName ?? "Unknown",
                        Type = msg.Type,
                        Content = msg.Content,
                        FilePath = msg.FilePath,
                        Status = msg.Status,
                        CreatedAt = msg.CreatedAt,
                        ClientMessageId = msg.ClientMessageId
                    });
                    
                    // Also send status update if message was updated after creation
                    if (msg.UpdatedAt.HasValue && msg.UpdatedAt.Value > lastSyncTimestamp)
                    {
                        missedStatusUpdates.Add(new
                        {
                            MessageId = msg.Id,
                            Status = (int)msg.Status,
                            UpdatedAt = msg.UpdatedAt.Value
                        });
                    }
                }
            }
            
            Console.WriteLine($"[ChatHub] IncrementalSync: {missedMessages.Count} messages, {missedStatusUpdates.Count} status updates");
            
            // Send all missed data to client
            await Clients.Caller.SendAsync("IncrementalSyncResult", new
            {
                Messages = missedMessages,
                StatusUpdates = missedStatusUpdates,
                SyncTimestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ChatHub] Error in IncrementalSync: {ex.Message}");
            await Clients.Caller.SendAsync("IncrementalSyncError", ex.Message);
        }
    }
    
    /// <summary>
    /// Notify all participants in user's chats about user status change
    /// </summary>
    private async Task NotifyUserStatusChanged(Guid userId, bool isOnline, DateTime lastSeenAt)
    {
        try
        {
            var chats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
            foreach (var chat in chats)
            {
                await Clients.Group(chat.Id.ToString())
                    .SendAsync("UserStatusChanged", userId.ToString(), isOnline, lastSeenAt);
            }
            
            Console.WriteLine($"[ChatHub] User {userId} status changed: {(isOnline ? "online" : "offline")} at {lastSeenAt:O}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[ChatHub] Error notifying user status change: {ex.Message}");
        }
    }
}


