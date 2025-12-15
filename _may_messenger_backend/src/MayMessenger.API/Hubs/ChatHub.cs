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
    
    public async Task SendMessage(SendMessageDto dto)
    {
        var userId = GetCurrentUserId();
        
        var message = new Message
        {
            ChatId = dto.ChatId,
            SenderId = userId,
            Type = dto.Type,
            Content = dto.Content,
            Status = MessageStatus.Sent
        };
        
        await _unitOfWork.Messages.AddAsync(message);
        await _unitOfWork.SaveChangesAsync();
        
        var sender = await _unitOfWork.Users.GetByIdAsync(userId);
        
        var messageDto = new MessageDto
        {
            Id = message.Id,
            ChatId = message.ChatId,
            SenderId = message.SenderId,
            SenderName = sender?.DisplayName ?? "Unknown",
            Type = message.Type,
            Content = message.Content,
            FilePath = message.FilePath,
            Status = message.Status,
            CreatedAt = message.CreatedAt
        };
        
        // Send to all users in the chat
        await Clients.Group(dto.ChatId.ToString()).SendAsync("ReceiveMessage", messageDto);
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
            
            // Notify all participants about status change
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
}


