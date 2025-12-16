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
    private readonly MayMessenger.Application.Services.IFirebaseService _firebaseService;
    private readonly ILogger<MessagesController> _logger;
    
    public MessagesController(
        IUnitOfWork unitOfWork, 
        IWebHostEnvironment environment, 
        IHubContext<ChatHub> hubContext,
        MayMessenger.Application.Services.IFirebaseService firebaseService,
        ILogger<MessagesController> logger)
    {
        _unitOfWork = unitOfWork;
        _environment = environment;
        _hubContext = hubContext;
        _firebaseService = firebaseService;
        _logger = logger;
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
        
        // Send SignalR notification to all participants of the chat
        var chat = await _unitOfWork.Chats.GetByIdAsync(dto.ChatId);
        if (chat != null)
        {
            foreach (var participant in chat.Participants)
            {
                // Send to each participant's connection
                await _hubContext.Clients.User(participant.UserId.ToString()).SendAsync("ReceiveMessage", messageDto);
            }
            
            // Also send to group for users currently in the chat
            await _hubContext.Clients.Group(dto.ChatId.ToString()).SendAsync("ReceiveMessage", messageDto);
            
            // Send push notifications to offline users
            await SendPushNotificationsAsync(chat, sender, messageDto);
        }
        
        return Ok(messageDto);
    }
    
    [HttpPost("audio")]
    public async Task<ActionResult<MessageDto>> SendAudioMessage([FromForm] Guid chatId, IFormFile audioFile)
    {
        var userId = GetCurrentUserId();
        
        if (audioFile == null || audioFile.Length == 0)
            return BadRequest("No audio file provided");
        
        // Save audio file
        var uploadsFolder = Path.Combine(_environment.WebRootPath, "audio");
        Directory.CreateDirectory(uploadsFolder);
        
        var fileName = $"{Guid.NewGuid()}{Path.GetExtension(audioFile.FileName)}";
        var filePath = Path.Combine(uploadsFolder, fileName);
        
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await audioFile.CopyToAsync(stream);
        }
        
        var message = new Message
        {
            ChatId = chatId,
            SenderId = userId,
            Type = MessageType.Audio,
            FilePath = $"/audio/{fileName}",
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
            foreach (var participant in chat.Participants)
            {
                // Send to each participant's connection
                await _hubContext.Clients.User(participant.UserId.ToString()).SendAsync("ReceiveMessage", messageDto);
            }
            
            // Also send to group for users currently in the chat
            await _hubContext.Clients.Group(chatId.ToString()).SendAsync("ReceiveMessage", messageDto);
            
            // Send push notifications to offline users
            await SendPushNotificationsAsync(chat, sender, messageDto);
        }
        
        return Ok(messageDto);
    }

    /// <summary>
    /// Отправка push уведомлений пользователям, которые не онлайн
    /// </summary>
    private async Task SendPushNotificationsAsync(Chat chat, User sender, MessageDto message)
    {
        if (!_firebaseService.IsInitialized)
        {
            _logger.LogWarning("Firebase not initialized. Cannot send push notifications.");
            return;
        }

        try
        {
            var title = $"Новое сообщение от {sender.DisplayName}";
            var body = message.Type == MessageType.Text 
                ? (message.Content?.Length > 100 ? message.Content.Substring(0, 100) + "..." : message.Content) 
                : "🎤 Аудио сообщение";

            var data = new Dictionary<string, string>
            {
                { "chatId", message.ChatId.ToString() },
                { "messageId", message.Id.ToString() },
                { "type", message.Type.ToString() }
            };

            // Send to all participants except sender
            foreach (var participant in chat.Participants)
            {
                if (participant.UserId == sender.Id)
                    continue;

                try
                {
                    var tokens = await _unitOfWork.FcmTokens.GetActiveTokensForUserAsync(participant.UserId);
                    
                    if (tokens.Any())
                    {
                        _logger.LogInformation($"Sending push notification to user {participant.UserId}, {tokens.Count} tokens");
                        
                        foreach (var token in tokens)
                        {
                            var sent = await _firebaseService.SendNotificationAsync(
                                token.Token, 
                                title, 
                                body ?? "", 
                                data);
                            
                            if (sent)
                            {
                                // Update last used timestamp
                                token.LastUsedAt = DateTime.UtcNow;
                            }
                        }
                        
                        await _unitOfWork.SaveChangesAsync();
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Failed to send push to user {participant.UserId}");
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in SendPushNotificationsAsync");
        }
    }
    
    [HttpGet("audio/{messageId}/check")]
    public async Task<IActionResult> CheckAudioAvailability(Guid messageId)
    {
        var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
        
        if (message == null)
        {
            return NotFound(new { message = "Сообщение не найдено" });
        }
        
        if (message.Type != MessageType.Audio)
        {
            return BadRequest(new { message = "Это не голосовое сообщение" });
        }
        
        if (string.IsNullOrEmpty(message.FilePath))
        {
            return NotFound(new { 
                message = "Аудиофайл был удален",
                isDeleted = true 
            });
        }
        
        // Check if physical file exists
        var fileName = message.FilePath.TrimStart('/');
        var fullPath = Path.Combine(_environment.WebRootPath, fileName);
        
        if (!System.IO.File.Exists(fullPath))
        {
            // File doesn't exist - mark message
            message.FilePath = null;
            message.Content = "[Аудио удалено]";
            await _unitOfWork.SaveChangesAsync();
            
            return NotFound(new { 
                message = "Аудиофайл больше не доступен",
                isDeleted = true 
            });
        }
        
        return Ok(new { 
            available = true,
            filePath = message.FilePath 
        });
    }
    
    [HttpDelete("{messageId}")]
    public async Task<IActionResult> DeleteMessage(Guid messageId)
    {
        var userId = GetCurrentUserId();
        var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
        
        if (message == null)
        {
            return NotFound(new { message = "Сообщение не найдено" });
        }
        
        // Only sender can delete their own message
        if (message.SenderId != userId)
        {
            return Forbid();
        }
        
        // Delete audio file if exists
        if (message.Type == MessageType.Audio && !string.IsNullOrEmpty(message.FilePath))
        {
            var fileName = message.FilePath.TrimStart('/');
            var fullPath = Path.Combine(_environment.WebRootPath, fileName);
            
            if (System.IO.File.Exists(fullPath))
            {
                try
                {
                    System.IO.File.Delete(fullPath);
                    _logger.LogInformation($"Deleted audio file: {fullPath}");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Failed to delete audio file: {fullPath}");
                }
            }
        }
        
        var chatId = message.ChatId;
        
        // Delete message from database
        await _unitOfWork.Messages.DeleteAsync(message);
        await _unitOfWork.SaveChangesAsync();
        
        // Notify all participants via SignalR
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        if (chat != null)
        {
            var deleteNotification = new
            {
                messageId = messageId,
                chatId = chatId,
                deletedAt = DateTime.UtcNow
            };
            
            foreach (var participant in chat.Participants)
            {
                await _hubContext.Clients.User(participant.UserId.ToString())
                    .SendAsync("MessageDeleted", deleteNotification);
            }
            
            await _hubContext.Clients.Group(chatId.ToString())
                .SendAsync("MessageDeleted", deleteNotification);
        }
        
        return Ok(new { message = "Сообщение удалено" });
    }
}


