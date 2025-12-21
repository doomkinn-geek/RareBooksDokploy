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
        
        // Join user's chats
        var chats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
        
        foreach (var chat in chats)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, chat.Id.ToString());
        }
        
        await base.OnConnectedAsync();
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
        var userId = GetCurrentUserId();
        var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
        
        if (message == null) return;
        
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
                DeliveredAt = DateTime.UtcNow
            };
            await _unitOfWork.DeliveryReceipts.AddAsync(receipt);
        }
        else if (receipt.DeliveredAt == null)
        {
            receipt.DeliveredAt = DateTime.UtcNow;
            await _unitOfWork.DeliveryReceipts.UpdateAsync(receipt);
        }
        
        // If this is the first delivery and message status is Sent, change to Delivered
        if (message.Status == MessageStatus.Sent)
        {
            message.Status = MessageStatus.Delivered;
            message.DeliveredAt = DateTime.UtcNow;
            await _unitOfWork.Messages.UpdateAsync(message);
            await _unitOfWork.SaveChangesAsync();
            
            // Notify all participants about status change (without acks - status changes don't need acks)
            await Clients.Group(chatId.ToString()).SendAsync("MessageStatusUpdated", messageId, (int)MessageStatus.Delivered);
        }
        else
        {
            await _unitOfWork.SaveChangesAsync();
        }
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
        
        await _unitOfWork.SaveChangesAsync();
        
        // For private chats, mark as read immediately
        if (chat.Type == ChatType.Private && message.Status != MessageStatus.Read)
        {
            message.Status = MessageStatus.Read;
            message.ReadAt = DateTime.UtcNow;
            await _unitOfWork.Messages.UpdateAsync(message);
            await _unitOfWork.SaveChangesAsync();
            
            await Clients.Group(chatId.ToString()).SendAsync("MessageStatusUpdated", messageId, (int)MessageStatus.Read);
        }
        // For group chats, check if ALL participants (except sender) have read it
        else if (chat.Type == ChatType.Group)
        {
            var participantsCount = chat.Participants.Count;
            var readCount = await _unitOfWork.DeliveryReceipts.GetReadCountAsync(messageId);
            
            // If all participants except sender have read it, mark message as read
            if (readCount >= participantsCount - 1 && message.Status != MessageStatus.Read)
            {
                message.Status = MessageStatus.Read;
                message.ReadAt = DateTime.UtcNow;
                await _unitOfWork.Messages.UpdateAsync(message);
                await _unitOfWork.SaveChangesAsync();
                
                await Clients.Group(chatId.ToString()).SendAsync("MessageStatusUpdated", messageId, (int)MessageStatus.Read);
            }
        }
    }
    
    public async Task TypingIndicator(Guid chatId, bool isTyping)
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        // Notify others in the chat (except sender)
        await Clients.OthersInGroup(chatId.ToString()).SendAsync("UserTyping", userId, user?.DisplayName ?? "Unknown", isTyping);
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
}


