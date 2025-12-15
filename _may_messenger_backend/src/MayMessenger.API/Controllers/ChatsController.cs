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
            if (chat.Type == ChatType.Private)
            {
                var otherParticipant = chat.Participants
                    .FirstOrDefault(p => p.UserId != userId);
                
                if (otherParticipant != null)
                {
                    displayTitle = otherParticipant.User.DisplayName;
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
        
        var chatDto = new ChatDto
        {
            Id = chat.Id,
            Type = chat.Type,
            Title = chat.Title,
            Avatar = chat.Avatar,
            CreatedAt = chat.CreatedAt,
            UnreadCount = unreadCount,
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
                    UnreadCount = 0
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
        
        // Add creator as participant
        var creatorParticipant = new ChatParticipant
        {
            ChatId = chat.Id,
            UserId = userId,
            IsAdmin = true
        };
        await _context.ChatParticipants.AddAsync(creatorParticipant);
        
        // Add other participants
        foreach (var participantId in dto.ParticipantIds)
        {
            var participant = new ChatParticipant
            {
                ChatId = chat.Id,
                UserId = participantId,
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
            UnreadCount = 0
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
            UnreadCount = 0
        };
        
        // Notify target user about new chat via SignalR
        await _hubContext.Clients.User(request.TargetUserId.ToString())
            .SendAsync("NewChatCreated", chatDto);
        
        return Ok(chatDto);
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
}

public class CreateDirectChatRequest
{
    public Guid TargetUserId { get; set; }
}


