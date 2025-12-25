using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;
using MayMessenger.API.Hubs;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ChatsController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly AppDbContext _context;
    private readonly IHubContext<ChatHub> _hubContext;
    
    public ChatsController(IUnitOfWork unitOfWork, AppDbContext context, IHubContext<ChatHub> hubContext)
    {
        _unitOfWork = unitOfWork;
        _context = context;
        _hubContext = hubContext;
    }
    
    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }
    
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ChatDto>>> GetChats()
    {
        var userId = GetCurrentUserId();
        var chats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
        
        var chatDtos = new List<ChatDto>();
        foreach (var chat in chats)
        {
            var lastMessage = chat.Messages.FirstOrDefault();
            var unreadCount = await _unitOfWork.Messages.GetUnreadCountAsync(chat.Id, userId);
            
            // For private chats, generate title from other participant's name
            var displayTitle = chat.Title;
            Guid? otherParticipantId = null;
            
            if (chat.Type == ChatType.Private)
            {
                var otherParticipant = chat.Participants
                    .FirstOrDefault(p => p.UserId != userId);
                
                if (otherParticipant != null)
                {
                    displayTitle = otherParticipant.User.DisplayName;
                    otherParticipantId = otherParticipant.UserId;
                }
            }
            
            chatDtos.Add(new ChatDto
            {
                Id = chat.Id,
                Type = chat.Type,
                Title = displayTitle,
                Avatar = chat.Avatar,
                CreatedAt = chat.CreatedAt,
                UnreadCount = unreadCount,
                OtherParticipantId = otherParticipantId,
                LastMessage = lastMessage != null ? new MessageDto
                {
                    Id = lastMessage.Id,
                    ChatId = lastMessage.ChatId,
                    SenderId = lastMessage.SenderId,
                    SenderName = lastMessage.Sender.DisplayName,
                    Type = lastMessage.Type,
                    Content = lastMessage.Content,
                    FilePath = lastMessage.FilePath,
                    Status = lastMessage.Status,
                    CreatedAt = lastMessage.CreatedAt
                } : null
            });
        }
        
        return Ok(chatDtos);
    }
    
    [HttpGet("{chatId}")]
    public async Task<ActionResult<ChatDto>> GetChat(Guid chatId)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
            return NotFound();
        
        // Check if user is participant
        var participants = await _unitOfWork.Chats.GetByIdAsync(chatId);
        // Simplified check - in production should verify participation
        
        var lastMessage = await _unitOfWork.Messages.GetLastMessageAsync(chatId);
        var unreadCount = await _unitOfWork.Messages.GetUnreadCountAsync(chatId, userId);
        
        // For private chats, get otherParticipantId
        var displayTitle = chat.Title;
        Guid? otherParticipantId = null;
        
        if (chat.Type == ChatType.Private)
        {
            var otherParticipant = chat.Participants
                .FirstOrDefault(p => p.UserId != userId);
            
            if (otherParticipant != null)
            {
                displayTitle = otherParticipant.User.DisplayName;
                otherParticipantId = otherParticipant.UserId;
            }
        }
        
        var chatDto = new ChatDto
        {
            Id = chat.Id,
            Type = chat.Type,
            Title = displayTitle,
            Avatar = chat.Avatar,
            CreatedAt = chat.CreatedAt,
            UnreadCount = unreadCount,
            OtherParticipantId = otherParticipantId,
            LastMessage = lastMessage != null ? new MessageDto
            {
                Id = lastMessage.Id,
                ChatId = lastMessage.ChatId,
                SenderId = lastMessage.SenderId,
                SenderName = lastMessage.Sender.DisplayName,
                Type = lastMessage.Type,
                Content = lastMessage.Content,
                FilePath = lastMessage.FilePath,
                Status = lastMessage.Status,
                CreatedAt = lastMessage.CreatedAt
            } : null
        };
        
        return Ok(chatDto);
    }
    
    [HttpPost]
    public async Task<ActionResult<ChatDto>> CreateChat([FromBody] CreateChatDto dto)
    {
        var userId = GetCurrentUserId();
        
        // For private chat
        if (dto.ParticipantIds.Count == 1)
        {
            var existingChat = await _unitOfWork.Chats.GetPrivateChatAsync(userId, dto.ParticipantIds[0]);
            if (existingChat != null)
            {
                return Ok(new ChatDto
                {
                    Id = existingChat.Id,
                    Type = existingChat.Type,
                    Title = existingChat.Title,
                    Avatar = existingChat.Avatar,
                    CreatedAt = existingChat.CreatedAt,
                    UnreadCount = 0,
                    OtherParticipantId = dto.ParticipantIds[0] // Add otherParticipantId
                });
            }
        }
        
        var chat = new Chat
        {
            Type = dto.ParticipantIds.Count == 1 ? ChatType.Private : ChatType.Group,
            Title = dto.Title
        };
        
        await _unitOfWork.Chats.AddAsync(chat);
        await _unitOfWork.SaveChangesAsync(); // Save chat first to get ID
        
        // For group chats, creator is owner; for private chats, no owner/admin
        var isGroupChat = dto.ParticipantIds.Count > 1;
        
        // Add creator as participant
        var creatorParticipant = new ChatParticipant
        {
            ChatId = chat.Id,
            UserId = userId,
            IsOwner = isGroupChat, // Owner only for group chats
            IsAdmin = isGroupChat  // Admin only for group chats
        };
        await _context.ChatParticipants.AddAsync(creatorParticipant);
        
        // Add other participants
        foreach (var participantId in dto.ParticipantIds)
        {
            var participant = new ChatParticipant
            {
                ChatId = chat.Id,
                UserId = participantId,
                IsOwner = false,
                IsAdmin = false
            };
            await _context.ChatParticipants.AddAsync(participant);
        }
        
        await _unitOfWork.SaveChangesAsync();
        
        var chatDto = new ChatDto
        {
            Id = chat.Id,
            Type = chat.Type,
            Title = chat.Title,
            Avatar = chat.Avatar,
            CreatedAt = chat.CreatedAt,
            UnreadCount = 0,
            OtherParticipantId = chat.Type == ChatType.Private && dto.ParticipantIds.Count == 1 ? dto.ParticipantIds[0] : null
        };
        
        // Notify all participants (except creator) about new chat via SignalR
        foreach (var participantId in dto.ParticipantIds)
        {
            await _hubContext.Clients.User(participantId.ToString())
                .SendAsync("NewChatCreated", chatDto);
        }
        
        return Ok(chatDto);
    }

    [HttpPost("create-or-get")]
    public async Task<ActionResult<ChatDto>> CreateOrGetDirectChat([FromBody] CreateDirectChatRequest request)
    {
        var userId = GetCurrentUserId();
        
        // Check if target user exists
        var targetUser = await _unitOfWork.Users.GetByIdAsync(request.TargetUserId);
        if (targetUser == null)
        {
            return NotFound("User not found");
        }
        
        // Check if direct chat already exists between these two users
        var userChats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
        var existingChat = userChats.FirstOrDefault(c => 
            c.Participants.Count == 2 && 
            c.Participants.Any(p => p.UserId == request.TargetUserId));
        
        if (existingChat != null)
        {
            var lastMessage1 = await _unitOfWork.Messages.GetLastMessageAsync(existingChat.Id);
            var unreadCount1 = await _unitOfWork.Messages.GetUnreadCountAsync(existingChat.Id, userId);
            
            return Ok(new ChatDto
            {
                Id = existingChat.Id,
                Type = existingChat.Type,
                Title = targetUser.DisplayName,
                Avatar = existingChat.Avatar,
                CreatedAt = existingChat.CreatedAt,
                UnreadCount = unreadCount1,
                OtherParticipantId = request.TargetUserId, // Add otherParticipantId
                LastMessage = lastMessage1 != null ? new MessageDto
                {
                    Id = lastMessage1.Id,
                    ChatId = lastMessage1.ChatId,
                    SenderId = lastMessage1.SenderId,
                    SenderName = lastMessage1.Sender.DisplayName,
                    Type = lastMessage1.Type,
                    Content = lastMessage1.Content,
                    FilePath = lastMessage1.FilePath,
                    Status = lastMessage1.Status,
                    CreatedAt = lastMessage1.CreatedAt
                } : null
            });
        }
        
        // Create new direct chat
        var chat = new Chat
        {
            Type = ChatType.Private,
            Title = targetUser.DisplayName
        };
        
        await _unitOfWork.Chats.AddAsync(chat);
        await _unitOfWork.SaveChangesAsync();
        
        // Add both users as participants
        var participant1 = new ChatParticipant
        {
            ChatId = chat.Id,
            UserId = userId,
            IsAdmin = false
        };
        var participant2 = new ChatParticipant
        {
            ChatId = chat.Id,
            UserId = request.TargetUserId,
            IsAdmin = false
        };
        
        await _context.ChatParticipants.AddAsync(participant1);
        await _context.ChatParticipants.AddAsync(participant2);
        await _unitOfWork.SaveChangesAsync();
        
        var chatDto = new ChatDto
        {
            Id = chat.Id,
            Type = chat.Type,
            Title = targetUser.DisplayName,
            Avatar = chat.Avatar,
            CreatedAt = chat.CreatedAt,
            UnreadCount = 0,
            OtherParticipantId = request.TargetUserId // Add otherParticipantId
        };
        
        // Notify target user about new chat via SignalR
        await _hubContext.Clients.User(request.TargetUserId.ToString())
            .SendAsync("NewChatCreated", chatDto);
        
        return Ok(chatDto);
    }

    [HttpDelete("{chatId}")]
    public async Task<IActionResult> DeleteChat(Guid chatId)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
        {
            return NotFound(new { message = "Чат не найден" });
        }
        
        // Check if user is a participant
        var isParticipant = chat.Participants.Any(p => p.UserId == userId);
        if (!isParticipant)
        {
            return Forbid();
        }
        
        // Get all messages to delete audio files
        var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chatId, 0, int.MaxValue);
        var webRootPath = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
        
        foreach (var message in messages)
        {
            if (message.Type == MessageType.Audio && !string.IsNullOrEmpty(message.FilePath))
            {
                var fileName = message.FilePath.TrimStart('/');
                var fullPath = Path.Combine(webRootPath, fileName);
                
                if (System.IO.File.Exists(fullPath))
                {
                    try
                    {
                        System.IO.File.Delete(fullPath);
                    }
                    catch (Exception ex)
                    {
                        // Log but continue
                        Console.WriteLine($"Failed to delete audio: {ex.Message}");
                    }
                }
            }
            
            _context.Remove(message);
        }
        
        // Remove all participants
        foreach (var participant in chat.Participants.ToList())
        {
            _context.ChatParticipants.Remove(participant);
        }
        
        // Delete the chat itself
        _context.Remove(chat);
        await _unitOfWork.SaveChangesAsync();
        
        // Notify all participants via SignalR
        var deleteNotification = new
        {
            chatId = chatId,
            deletedAt = DateTime.UtcNow,
            deletedBy = userId
        };
        
        foreach (var participant in chat.Participants)
        {
            await _hubContext.Clients.User(participant.UserId.ToString())
                .SendAsync("ChatDeleted", deleteNotification);
        }
        
        await _hubContext.Clients.Group(chatId.ToString())
            .SendAsync("ChatDeleted", deleteNotification);
        
        return Ok(new { message = "Чат удален" });
    }

    [HttpDelete("reset-all")]
    public async Task<IActionResult> ResetAllChats()
    {
        var userId = GetCurrentUserId();
        
        // Get all user's chats
        var userChats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
        
        // Remove user from all chats
        foreach (var chat in userChats)
        {
            // Remove participant
            var participant = chat.Participants.FirstOrDefault(p => p.UserId == userId);
            if (participant != null)
            {
                _context.ChatParticipants.Remove(participant);
            }
            
            // If this was a private chat and user was the only or last participant, delete the chat entirely
            if (chat.Type == ChatType.Private || chat.Participants.Count <= 1)
            {
                // Delete all messages in the chat
                var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chat.Id, 0, int.MaxValue);
                foreach (var message in messages)
                {
                    _context.Remove(message);
                }
                
                // Delete the chat itself
                _context.Remove(chat);
            }
        }
        
        await _unitOfWork.SaveChangesAsync();
        
        return Ok(new { message = "All chats reset successfully" });
    }

    #region Group Participants Management
    
    /// <summary>
    /// Get all participants of a chat with their roles
    /// </summary>
    [HttpGet("{chatId}/participants")]
    public async Task<ActionResult<IEnumerable<ParticipantDto>>> GetParticipants(Guid chatId)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
            return NotFound(new { message = "Чат не найден" });
        
        // Check if user is a participant
        var isParticipant = chat.Participants.Any(p => p.UserId == userId);
        if (!isParticipant)
            return Forbid();
        
        var participants = chat.Participants.Select(p => new ParticipantDto
        {
            UserId = p.UserId,
            DisplayName = p.User.DisplayName,
            IsOwner = p.IsOwner,
            IsAdmin = p.IsAdmin,
            JoinedAt = p.JoinedAt
        }).ToList();
        
        return Ok(participants);
    }
    
    /// <summary>
    /// Add participants to a group chat (owner or admin only)
    /// </summary>
    [HttpPost("{chatId}/participants")]
    public async Task<IActionResult> AddParticipants(Guid chatId, [FromBody] AddParticipantsDto dto)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
            return NotFound(new { message = "Чат не найден" });
        
        if (chat.Type != ChatType.Group)
            return BadRequest(new { message = "Можно добавлять участников только в групповые чаты" });
        
        // Check if user is owner or admin
        var currentParticipant = chat.Participants.FirstOrDefault(p => p.UserId == userId);
        if (currentParticipant == null || (!currentParticipant.IsOwner && !currentParticipant.IsAdmin))
            return Forbid();
        
        var addedCount = 0;
        foreach (var newUserId in dto.UserIds)
        {
            // Check if user exists
            var user = await _unitOfWork.Users.GetByIdAsync(newUserId);
            if (user == null) continue;
            
            // Check if already a participant
            if (chat.Participants.Any(p => p.UserId == newUserId)) continue;
            
            var newParticipant = new ChatParticipant
            {
                ChatId = chatId,
                UserId = newUserId,
                IsOwner = false,
                IsAdmin = false
            };
            await _context.ChatParticipants.AddAsync(newParticipant);
            addedCount++;
            
            // Notify the new participant via SignalR
            await _hubContext.Clients.User(newUserId.ToString())
                .SendAsync("AddedToChat", new { chatId, addedBy = userId });
        }
        
        await _unitOfWork.SaveChangesAsync();
        
        // Notify all chat participants about changes
        await _hubContext.Clients.Group(chatId.ToString())
            .SendAsync("ParticipantsChanged", new { chatId, action = "added", count = addedCount });
        
        return Ok(new { message = $"Добавлено {addedCount} участников" });
    }
    
    /// <summary>
    /// Remove a participant from a group chat (owner or admin only)
    /// </summary>
    [HttpDelete("{chatId}/participants/{targetUserId}")]
    public async Task<IActionResult> RemoveParticipant(Guid chatId, Guid targetUserId)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
            return NotFound(new { message = "Чат не найден" });
        
        if (chat.Type != ChatType.Group)
            return BadRequest(new { message = "Нельзя удалить участника из приватного чата" });
        
        // Check if user is owner or admin
        var currentParticipant = chat.Participants.FirstOrDefault(p => p.UserId == userId);
        if (currentParticipant == null || (!currentParticipant.IsOwner && !currentParticipant.IsAdmin))
            return Forbid();
        
        // Find target participant
        var targetParticipant = chat.Participants.FirstOrDefault(p => p.UserId == targetUserId);
        if (targetParticipant == null)
            return NotFound(new { message = "Участник не найден в чате" });
        
        // Owners cannot be removed
        if (targetParticipant.IsOwner)
            return BadRequest(new { message = "Нельзя удалить создателя группы" });
        
        // Admins can only be removed by owners
        if (targetParticipant.IsAdmin && !currentParticipant.IsOwner)
            return Forbid();
        
        _context.ChatParticipants.Remove(targetParticipant);
        await _unitOfWork.SaveChangesAsync();
        
        // Notify the removed participant
        await _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("RemovedFromChat", new { chatId, removedBy = userId });
        
        // Notify all chat participants about changes
        await _hubContext.Clients.Group(chatId.ToString())
            .SendAsync("ParticipantsChanged", new { chatId, action = "removed", userId = targetUserId });
        
        return Ok(new { message = "Участник удален" });
    }
    
    /// <summary>
    /// Promote a participant to admin (owner only)
    /// </summary>
    [HttpPost("{chatId}/admins/{targetUserId}")]
    public async Task<IActionResult> PromoteToAdmin(Guid chatId, Guid targetUserId)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
            return NotFound(new { message = "Чат не найден" });
        
        if (chat.Type != ChatType.Group)
            return BadRequest(new { message = "Администраторы есть только в групповых чатах" });
        
        // Check if user is owner (only owner can promote)
        var currentParticipant = chat.Participants.FirstOrDefault(p => p.UserId == userId);
        if (currentParticipant == null || !currentParticipant.IsOwner)
            return Forbid();
        
        // Find target participant
        var targetParticipant = chat.Participants.FirstOrDefault(p => p.UserId == targetUserId);
        if (targetParticipant == null)
            return NotFound(new { message = "Участник не найден в чате" });
        
        if (targetParticipant.IsAdmin)
            return BadRequest(new { message = "Участник уже является администратором" });
        
        targetParticipant.IsAdmin = true;
        await _unitOfWork.SaveChangesAsync();
        
        // Notify the promoted participant
        await _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("PromotedToAdmin", new { chatId, promotedBy = userId });
        
        // Notify all chat participants
        await _hubContext.Clients.Group(chatId.ToString())
            .SendAsync("ParticipantsChanged", new { chatId, action = "promoted", userId = targetUserId });
        
        return Ok(new { message = "Участник назначен администратором" });
    }
    
    /// <summary>
    /// Demote an admin to regular participant (owner only)
    /// </summary>
    [HttpDelete("{chatId}/admins/{targetUserId}")]
    public async Task<IActionResult> DemoteAdmin(Guid chatId, Guid targetUserId)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
            return NotFound(new { message = "Чат не найден" });
        
        if (chat.Type != ChatType.Group)
            return BadRequest(new { message = "Администраторы есть только в групповых чатах" });
        
        // Check if user is owner (only owner can demote)
        var currentParticipant = chat.Participants.FirstOrDefault(p => p.UserId == userId);
        if (currentParticipant == null || !currentParticipant.IsOwner)
            return Forbid();
        
        // Find target participant
        var targetParticipant = chat.Participants.FirstOrDefault(p => p.UserId == targetUserId);
        if (targetParticipant == null)
            return NotFound(new { message = "Участник не найден в чате" });
        
        if (!targetParticipant.IsAdmin)
            return BadRequest(new { message = "Участник не является администратором" });
        
        // Cannot demote owner
        if (targetParticipant.IsOwner)
            return BadRequest(new { message = "Нельзя снять права создателя группы" });
        
        targetParticipant.IsAdmin = false;
        await _unitOfWork.SaveChangesAsync();
        
        // Notify the demoted participant
        await _hubContext.Clients.User(targetUserId.ToString())
            .SendAsync("DemotedFromAdmin", new { chatId, demotedBy = userId });
        
        // Notify all chat participants
        await _hubContext.Clients.Group(chatId.ToString())
            .SendAsync("ParticipantsChanged", new { chatId, action = "demoted", userId = targetUserId });
        
        return Ok(new { message = "Права администратора сняты" });
    }
    
    /// <summary>
    /// Leave a group chat
    /// </summary>
    [HttpPost("{chatId}/leave")]
    public async Task<IActionResult> LeaveChat(Guid chatId)
    {
        var userId = GetCurrentUserId();
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        
        if (chat == null)
            return NotFound(new { message = "Чат не найден" });
        
        if (chat.Type != ChatType.Group)
            return BadRequest(new { message = "Можно покинуть только групповой чат" });
        
        var participant = chat.Participants.FirstOrDefault(p => p.UserId == userId);
        if (participant == null)
            return NotFound(new { message = "Вы не являетесь участником этого чата" });
        
        // If owner is leaving, transfer ownership to another admin or oldest member
        if (participant.IsOwner && chat.Participants.Count > 1)
        {
            var newOwner = chat.Participants
                .Where(p => p.UserId != userId && p.IsAdmin)
                .OrderBy(p => p.JoinedAt)
                .FirstOrDefault();
            
            if (newOwner == null)
            {
                newOwner = chat.Participants
                    .Where(p => p.UserId != userId)
                    .OrderBy(p => p.JoinedAt)
                    .FirstOrDefault();
            }
            
            if (newOwner != null)
            {
                newOwner.IsOwner = true;
                newOwner.IsAdmin = true;
                
                // Notify new owner
                await _hubContext.Clients.User(newOwner.UserId.ToString())
                    .SendAsync("PromotedToOwner", new { chatId });
            }
        }
        
        _context.ChatParticipants.Remove(participant);
        await _unitOfWork.SaveChangesAsync();
        
        // Notify chat participants
        await _hubContext.Clients.Group(chatId.ToString())
            .SendAsync("ParticipantsChanged", new { chatId, action = "left", userId });
        
        return Ok(new { message = "Вы покинули чат" });
    }
    
    #endregion
}

public class CreateDirectChatRequest
{
    public Guid TargetUserId { get; set; }
}

public class ParticipantDto
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public bool IsOwner { get; set; }
    public bool IsAdmin { get; set; }
    public DateTime JoinedAt { get; set; }
}

public class AddParticipantsDto
{
    public List<Guid> UserIds { get; set; } = new();
}


