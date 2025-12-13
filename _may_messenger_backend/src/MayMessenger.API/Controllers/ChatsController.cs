using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ChatsController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly AppDbContext _context;
    
    public ChatsController(IUnitOfWork unitOfWork, AppDbContext context)
    {
        _unitOfWork = unitOfWork;
        _context = context;
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
        
        return Ok(new ChatDto
        {
            Id = chat.Id,
            Type = chat.Type,
            Title = chat.Title,
            Avatar = chat.Avatar,
            CreatedAt = chat.CreatedAt,
            UnreadCount = 0
        });
    }
}


