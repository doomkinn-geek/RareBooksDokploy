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
            
            // Send push notifications to offline users
            await SendPushNotificationsAsync(chat, sender, messageDto);
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
        var uploadsFolder = Path.Combine(_environment.WebRootPath, "audio");
        Directory.CreateDirectory(uploadsFolder);
        
        var fileName = $"{Guid.NewGuid()}{Path.GetExtension(audioFile.FileName)}";
        var filePath = Path.Combine(uploadsFolder, fileName);
        
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await audioFile.CopyToAsync(stream);
        }
        
        // #region agent log
        DiagnosticsController.AddLog($"[H5] Audio file saved - Path: /audio/{fileName}");
        // #endregion
        
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
        // #region agent log
        DiagnosticsController.AddLog($"[H3-ENTRY] SendPushNotificationsAsync called - MessageId: {message.Id}, ChatId: {message.ChatId}, SenderId: {sender.Id}");
        // #endregion
        
        if (!_firebaseService.IsInitialized)
        {
            // #region agent log
            DiagnosticsController.AddLog($"[H3-FIREBASE] Firebase NOT initialized - push skipped");
            // #endregion
            
            _logger.LogWarning("Firebase not initialized. Cannot send push notifications.");
            return;
        }

        // #region agent log
        DiagnosticsController.AddLog($"[H3-FIREBASE] Firebase IS initialized - proceeding with push");
        // #endregion

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

            // #region agent log
            DiagnosticsController.AddLog($"[H3-PARTICIPANTS] Chat has {chat.Participants.Count} participants");
            // #endregion

            // Send to all participants except sender
            foreach (var participant in chat.Participants)
            {
                // #region agent log
                DiagnosticsController.AddLog($"[H3-LOOP] Checking participant UserId: {participant.UserId}, IsSender: {participant.UserId == sender.Id}");
                // #endregion
                
                if (participant.UserId == sender.Id)
                    continue;

                try
                {
                    var tokens = await _unitOfWork.FcmTokens.GetActiveTokensForUserAsync(participant.UserId);
                    
                    // #region agent log
                    DiagnosticsController.AddLog($"[H4-TOKENS] Retrieved {tokens.Count} FCM tokens for user {participant.UserId}");
                    // #endregion
                    
                    if (tokens.Any())
                    {
                        _logger.LogInformation($"Sending push notification to user {participant.UserId}, {tokens.Count} tokens");
                        
                        // #region agent log
                        DiagnosticsController.AddLog($"[H3-PUSH] Sending push to user {participant.UserId} with {tokens.Count} tokens");
                        // #endregion
                        
                        foreach (var token in tokens)
                        {
                            // #region agent log
                            DiagnosticsController.AddLog($"[H3-SEND] Calling FirebaseService.SendNotificationAsync - Token: {token.Token.Substring(0, 20)}..., Title: {title}");
                            // #endregion
                            
                            var sent = await _firebaseService.SendNotificationAsync(
                                token.Token, 
                                title, 
                                body ?? "", 
                                data);
                            
                            // #region agent log
                            DiagnosticsController.AddLog($"[H3-RESULT] Push send result: {sent}");
                            // #endregion
                            
                            if (sent)
                            {
                                // Update last used timestamp
                                token.LastUsedAt = DateTime.UtcNow;
                            }
                        }
                        
                        await _unitOfWork.SaveChangesAsync();
                    }
                    else
                    {
                        // #region agent log
                        DiagnosticsController.AddLog($"[H4-NO-TOKENS] User {participant.UserId} has NO active FCM tokens registered");
                        // #endregion
                    }
                }
                catch (Exception ex)
                {
                    // #region agent log
                    DiagnosticsController.AddLog($"[H3-ERROR] Exception in push loop for user {participant.UserId}: {ex.Message}");
                    // #endregion
                    
                    _logger.LogError(ex, $"Failed to send push to user {participant.UserId}");
                }
            }
        }
        catch (Exception ex)
        {
            // #region agent log
            DiagnosticsController.AddLog($"[H3-OUTER-ERROR] Exception in SendPushNotificationsAsync: {ex.Message}");
            // #endregion
            
            _logger.LogError(ex, "Error in SendPushNotificationsAsync");
        }
    }
}


