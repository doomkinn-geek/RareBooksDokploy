using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.API.Hubs;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class MessagesController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IWebHostEnvironment _environment;
    private readonly IHubContext<ChatHub> _hubContext;
    
    public MessagesController(IUnitOfWork unitOfWork, IWebHostEnvironment environment, IHubContext<ChatHub> hubContext)
    {
        _unitOfWork = unitOfWork;
        _environment = environment;
        _hubContext = hubContext;
    }
    
    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }
    
    [HttpGet("{chatId}")]
    public async Task<ActionResult<IEnumerable<MessageDto>>> GetMessages(Guid chatId, [FromQuery] int skip = 0, [FromQuery] int take = 50)
    {
        var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chatId, skip, take);
        
        var messageDtos = messages.Select(m => new MessageDto
        {
            Id = m.Id,
            ChatId = m.ChatId,
            SenderId = m.SenderId,
            SenderName = m.Sender.DisplayName,
            Type = m.Type,
            Content = m.Content,
            FilePath = m.FilePath,
            Status = m.Status,
            CreatedAt = m.CreatedAt
        });
        
        return Ok(messageDtos);
    }
    
    [HttpPost]
    public async Task<ActionResult<MessageDto>> SendMessage([FromBody] SendMessageDto dto)
    {
        // #region agent log
        DiagnosticsController.AddLog($"[H1,H4] REST SendMessage called - ChatId: {dto.ChatId}, Type: {dto.Type}, Content: {dto.Content?.Substring(0, Math.Min(20, dto.Content?.Length ?? 0))}");
        // #endregion
        
        var userId = GetCurrentUserId();
        
        // #region agent log
        DiagnosticsController.AddLog($"[H1,H4] SendMessage userId: {userId}");
        // #endregion
        
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
        
        // #region agent log
        DiagnosticsController.AddLog($"[H1,H4] Message saved to DB - Id: {message.Id}");
        // #endregion
        
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
        
        // Send SignalR notification to all participants of the chat
        var chat = await _unitOfWork.Chats.GetByIdAsync(dto.ChatId);
        if (chat != null)
        {
            // #region agent log
            DiagnosticsController.AddLog($"[H1,H4-FIX] Chat found, participants count: {chat.Participants.Count}");
            // #endregion
            
            foreach (var participant in chat.Participants)
            {
                // Send to each participant's connection
                await _hubContext.Clients.User(participant.UserId.ToString()).SendAsync("ReceiveMessage", messageDto);
                
                // #region agent log
                DiagnosticsController.AddLog($"[H1,H4-FIX] SignalR notification sent to user {participant.UserId}");
                // #endregion
            }
            
            // Also send to group for users currently in the chat
            await _hubContext.Clients.Group(dto.ChatId.ToString()).SendAsync("ReceiveMessage", messageDto);
        }
        
        return Ok(messageDto);
    }
    
    [HttpPost("audio")]
    public async Task<ActionResult<MessageDto>> SendAudioMessage([FromForm] Guid chatId, IFormFile audioFile)
    {
        // #region agent log
        DiagnosticsController.AddLog($"[H5] REST SendAudioMessage called - ChatId: {chatId}");
        // #endregion
        
        var userId = GetCurrentUserId();
        
        if (audioFile == null || audioFile.Length == 0)
            return BadRequest("No audio file provided");
        
        // Save audio file
        var uploadsFolder = Path.Combine(_environment.ContentRootPath, "uploads", "audio");
        Directory.CreateDirectory(uploadsFolder);
        
        var fileName = $"{Guid.NewGuid()}{Path.GetExtension(audioFile.FileName)}";
        var filePath = Path.Combine(uploadsFolder, fileName);
        
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await audioFile.CopyToAsync(stream);
        }
        
        // #region agent log
        DiagnosticsController.AddLog($"[H5] Audio file saved - Path: /uploads/audio/{fileName}");
        // #endregion
        
        var message = new Message
        {
            ChatId = chatId,
            SenderId = userId,
            Type = MessageType.Audio,
            FilePath = $"/uploads/audio/{fileName}",
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
        
        // Send SignalR notification to all participants of the chat
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        if (chat != null)
        {
            // #region agent log
            DiagnosticsController.AddLog($"[H5-FIX] Audio - Chat found, participants count: {chat.Participants.Count}");
            // #endregion
            
            foreach (var participant in chat.Participants)
            {
                // Send to each participant's connection
                await _hubContext.Clients.User(participant.UserId.ToString()).SendAsync("ReceiveMessage", messageDto);
                
                // #region agent log
                DiagnosticsController.AddLog($"[H5-FIX] Audio SignalR notification sent to user {participant.UserId}");
                // #endregion
            }
            
            // Also send to group for users currently in the chat
            await _hubContext.Clients.Group(chatId.ToString()).SendAsync("ReceiveMessage", messageDto);
        }
        
        return Ok(messageDto);
    }
}


