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
        
        // #region agent log
        var logger = HttpContext.RequestServices.GetRequiredService<ILogger<ChatsController>>();
        logger.LogInformation("[H6] GET /chats called, userId: {UserId}", userId);
        // #endregion
        
        var chats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
        
        // #region agent log
        logger.LogInformation("[H6] GetUserChatsAsync returned {Count} chats for userId: {UserId}", chats.Count(), userId);
        // #endregion
        
        var chatDtos = new List<ChatDto>();
        foreach (var chat in chats)
        {
            var lastMessage = chat.Messages.FirstOrDefault();
            var unreadCount = await _unitOfWork.Messages.GetUnreadCountAsync(chat.Id, userId);
            
            chatDtos.Add(new ChatDto
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
            });
        }
        
        // #region agent log
        logger.LogInformation("[H6] Returning {Count} chatDtos", chatDtos.Count);
        // #endregion
        
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
        
        // #region agent log
        var logger = HttpContext.RequestServices.GetRequiredService<ILogger<ChatsController>>();
        logger.LogInformation("[H6] POST /chats called, userId: {UserId}, participantIds: {ParticipantIds}", userId, string.Join(",", dto.ParticipantIds));
        // #endregion
        
        // For private chat
        if (dto.ParticipantIds.Count == 1)
        {
            var existingChat = await _unitOfWork.Chats.GetPrivateChatAsync(userId, dto.ParticipantIds[0]);
            if (existingChat != null)
            {
                // #region agent log
                logger.LogInformation("[H6] Existing private chat found: {ChatId}", existingChat.Id);
                // #endregion
                
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
        
        // #region agent log
        logger.LogInformation("[H6] New chat created: {ChatId}, type: {Type}", chat.Id, chat.Type);
        // #endregion
        
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
            
            // #region agent log
            logger.LogInformation("[H6] Added participant: userId={UserId}, chatId={ChatId}", participantId, chat.Id);
            // #endregion
        }
        
        await _unitOfWork.SaveChangesAsync();
        
        // #region agent log
        logger.LogInformation("[H6] Chat creation completed: {ChatId}", chat.Id);
        // #endregion
        
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


