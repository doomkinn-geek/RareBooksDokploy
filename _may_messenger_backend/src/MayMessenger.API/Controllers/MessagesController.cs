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
        var userId = GetCurrentUserId();
        var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chatId, skip, take);
        
        // Mark messages as delivered when retrieved (automatic delivery tracking)
        foreach (var message in messages)
        {
            if (message.SenderId != userId && message.Status == MessageStatus.Sent)
            {
                message.Status = MessageStatus.Delivered;
                message.DeliveredAt = DateTime.UtcNow;
                await _unitOfWork.Messages.UpdateAsync(message);
            }
        }
        
        await _unitOfWork.SaveChangesAsync();
        
        return Ok(messages.Select(m => new MessageDto
        {
            Id = m.Id,
            ChatId = m.ChatId,
            SenderId = m.SenderId,
            SenderName = m.Sender?.DisplayName ?? "Unknown",
            Type = m.Type,
            Content = m.Content,
            FilePath = m.FilePath,
            Status = m.Status,
            CreatedAt = m.CreatedAt
        }));
    }
    
    /// <summary>
    /// Получить обновления сообщений с определенного времени (для incremental sync)
    /// </summary>
    [HttpGet("{chatId}/updates")]
    public async Task<ActionResult<IEnumerable<MessageDto>>> GetMessageUpdates(
        Guid chatId, 
        [FromQuery] DateTime since, 
        [FromQuery] int take = 100)
    {
        try
        {
            var userId = GetCurrentUserId();
            
            // Check if user has access to this chat
            var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
            if (chat == null)
            {
                return NotFound("Chat not found");
            }
            
            // Get messages created or updated after 'since' timestamp
            var messages = await _unitOfWork.Messages.GetMessagesAfterTimestampAsync(chatId, since, take);
            
            _logger.LogInformation(
                "Incremental sync for chat {ChatId}: found {Count} messages since {Since}", 
                chatId, 
                messages.Count(), 
                since);
            
            // Mark messages as delivered when retrieved
            foreach (var message in messages)
            {
                if (message.SenderId != userId && message.Status == MessageStatus.Sent)
                {
                    message.Status = MessageStatus.Delivered;
                    message.DeliveredAt = DateTime.UtcNow;
                    await _unitOfWork.Messages.UpdateAsync(message);
                }
            }
            
            await _unitOfWork.SaveChangesAsync();
            
            return Ok(messages.Select(m => new MessageDto
            {
                Id = m.Id,
                ChatId = m.ChatId,
                SenderId = m.SenderId,
                SenderName = m.Sender?.DisplayName ?? "Unknown",
                Type = m.Type,
                Content = m.Content,
                FilePath = m.FilePath,
                Status = m.Status,
                CreatedAt = m.CreatedAt
            }));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during incremental sync for chat {ChatId}", chatId);
            return StatusCode(500, "Error fetching message updates");
        }
    }
    
    /// <summary>
    /// Получить сообщения чата с курсорной пагинацией (более эффективно, чем offset-based)
    /// </summary>
    [HttpGet("{chatId}/cursor")]
    public async Task<ActionResult<IEnumerable<MessageDto>>> GetMessagesWithCursor(
        Guid chatId, 
        [FromQuery] Guid? cursor = null, 
        [FromQuery] int take = 50)
    {
        try
        {
            var userId = GetCurrentUserId();
            
            // Check if user has access to this chat
            var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
            if (chat == null)
            {
                return NotFound("Chat not found");
            }
            
            // Get messages with cursor pagination
            var messages = await _unitOfWork.Messages.GetChatMessagesWithCursorAsync(chatId, cursor, take);
            
            _logger.LogInformation(
                "Cursor pagination for chat {ChatId}: cursor={Cursor}, returned {Count} messages", 
                chatId, 
                cursor?.ToString() ?? "null", 
                messages.Count());
            
            // Mark messages as delivered when retrieved
            foreach (var message in messages)
            {
                if (message.SenderId != userId && message.Status == MessageStatus.Sent)
                {
                    message.Status = MessageStatus.Delivered;
                    message.DeliveredAt = DateTime.UtcNow;
                    await _unitOfWork.Messages.UpdateAsync(message);
                }
            }
            
            await _unitOfWork.SaveChangesAsync();
            
            return Ok(messages.Select(m => new MessageDto
            {
                Id = m.Id,
                ChatId = m.ChatId,
                SenderId = m.SenderId,
                SenderName = m.Sender?.DisplayName ?? "Unknown",
                Type = m.Type,
                Content = m.Content,
                FilePath = m.FilePath,
                Status = m.Status,
                CreatedAt = m.CreatedAt
            }));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during cursor pagination for chat {ChatId}", chatId);
            return StatusCode(500, "Error fetching messages");
        }
    }
    
    [HttpGet("{chatId}/old")]
    public async Task<ActionResult<IEnumerable<MessageDto>>> GetOldMessages(Guid chatId, [FromQuery] int skip = 0, [FromQuery] int take = 50)
    {
        var userId = GetCurrentUserId();
        var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chatId, skip, take);
        
        // Mark messages as delivered when retrieved (automatic delivery tracking)
        var undeliveredMessages = messages.Where(m => 
            m.SenderId != userId && 
            m.Status == MessageStatus.Sent
        ).ToList();
        
        if (undeliveredMessages.Any())
        {
            _logger.LogInformation($"Auto-marking {undeliveredMessages.Count} messages as delivered for user {userId}");
            
            foreach (var message in undeliveredMessages)
            {
                // Create or update delivery receipt
                var receipt = await _unitOfWork.DeliveryReceipts.GetByMessageAndUserAsync(message.Id, userId);
                if (receipt == null)
                {
                    receipt = new DeliveryReceipt
                    {
                        MessageId = message.Id,
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
                
                // Update message status to delivered
                if (message.Status == MessageStatus.Sent)
                {
                    message.Status = MessageStatus.Delivered;
                    message.DeliveredAt = DateTime.UtcNow;
                    await _unitOfWork.Messages.UpdateAsync(message);
                    
                    // Notify via SignalR
                    await _hubContext.Clients.Group(chatId.ToString())
                        .SendAsync("MessageStatusUpdated", message.Id, (int)MessageStatus.Delivered);
                }
            }
            
            await _unitOfWork.SaveChangesAsync();
        }
        
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
    
    /// <summary>
    /// Get status updates for messages in a chat (for polling fallback)
    /// </summary>
    [HttpGet("{chatId}/status-updates")]
    public async Task<ActionResult<IEnumerable<object>>> GetStatusUpdates(Guid chatId, [FromQuery] DateTime? since = null)
    {
        var sinceTime = since ?? DateTime.UtcNow.AddHours(-1);
        var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chatId, 0, 100);
        
        // Filter messages that have status updates after 'since' time
        var updates = messages
            .Where(m => m.DeliveredAt > sinceTime || m.ReadAt > sinceTime)
            .Select(m => new
            {
                messageId = m.Id,
                status = (int)m.Status,
                deliveredAt = m.DeliveredAt,
                readAt = m.ReadAt,
                updatedAt = m.ReadAt ?? m.DeliveredAt ?? m.CreatedAt
            })
            .OrderBy(u => u.updatedAt)
            .ToList();
        
        _logger.LogInformation($"Returning {updates.Count} status updates for chat {chatId} since {sinceTime}");
        return Ok(updates);
    }
    
    [HttpPost]
    public async Task<ActionResult<MessageDto>> SendMessage([FromBody] SendMessageDto dto)
    {
        var userId = GetCurrentUserId();
        
        // Idempotency check: if clientMessageId is provided, check if message already exists
        if (!string.IsNullOrEmpty(dto.ClientMessageId))
        {
            var existingMessage = await _unitOfWork.Messages.GetByClientMessageIdAsync(dto.ClientMessageId);
            if (existingMessage != null)
            {
                _logger.LogInformation($"Message with ClientMessageId {dto.ClientMessageId} already exists, returning existing message {existingMessage.Id}");
                
                var existingMessageDto = new MessageDto
                {
                    Id = existingMessage.Id,
                    ChatId = existingMessage.ChatId,
                    SenderId = existingMessage.SenderId,
                    SenderName = existingMessage.Sender?.DisplayName ?? "Unknown",
                    Type = existingMessage.Type,
                    Content = existingMessage.Content,
                    FilePath = existingMessage.FilePath,
                    Status = existingMessage.Status,
                    CreatedAt = existingMessage.CreatedAt
                };
                
                return Ok(existingMessageDto);
            }
        }
        
        // Create new message
        var message = new Message
        {
            ChatId = dto.ChatId,
            SenderId = userId,
            Type = dto.Type,
            Content = dto.Content,
            ClientMessageId = dto.ClientMessageId,
            Status = MessageStatus.Sent
        };
        
        await _unitOfWork.Messages.AddAsync(message);
        await _unitOfWork.SaveChangesAsync();
        
        var sender = await _unitOfWork.Users.GetByIdAsync(userId);
        if (sender == null)
        {
            _logger.LogError($"User {userId} not found after sending message");
            return StatusCode(500, "Internal server error: User not found");
        }
        
        var messageDto = new MessageDto
        {
            Id = message.Id,
            ChatId = message.ChatId,
            SenderId = message.SenderId,
            SenderName = sender.DisplayName,
            Type = message.Type,
            Content = message.Content,
            FilePath = message.FilePath,
            Status = message.Status,
            CreatedAt = message.CreatedAt
        };
        
        // Send SignalR notification ONLY to group (not to individual users to avoid duplicates)
        var chat = await _unitOfWork.Chats.GetByIdAsync(dto.ChatId);
        if (chat != null)
        {
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
        if (sender == null)
        {
            _logger.LogError($"User {userId} not found after sending audio message");
            return StatusCode(500, "Internal server error: User not found");
        }
        
        var messageDto = new MessageDto
        {
            Id = message.Id,
            ChatId = message.ChatId,
            SenderId = message.SenderId,
            SenderName = sender.DisplayName,
            Type = message.Type,
            Content = message.Content,
            FilePath = message.FilePath,
            Status = message.Status,
            CreatedAt = message.CreatedAt
        };
        
        // Send SignalR notification ONLY to group (not to individual users to avoid duplicates)
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        if (chat != null)
        {
            await _hubContext.Clients.Group(chatId.ToString()).SendAsync("ReceiveMessage", messageDto);
            
            // Send push notifications to offline users
            await SendPushNotificationsAsync(chat, sender, messageDto);
        }
        
        return Ok(messageDto);
    }
    
    [HttpPost("image")]
    public async Task<ActionResult<MessageDto>> SendImageMessage([FromForm] Guid chatId, IFormFile imageFile)
    {
        var userId = GetCurrentUserId();
        
        if (imageFile == null || imageFile.Length == 0)
            return BadRequest("No image file provided");
        
        // Validate image type
        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
        var extension = Path.GetExtension(imageFile.FileName).ToLowerInvariant();
        if (!allowedExtensions.Contains(extension))
            return BadRequest("Invalid image format. Allowed: jpg, jpeg, png, gif, webp");
        
        // Validate image size (10MB max)
        if (imageFile.Length > 10 * 1024 * 1024)
            return BadRequest("Image size must be less than 10MB");
        
        // Save image file
        var uploadsFolder = Path.Combine(_environment.WebRootPath, "images");
        Directory.CreateDirectory(uploadsFolder);
        
        var fileName = $"{Guid.NewGuid()}{extension}";
        var filePath = Path.Combine(uploadsFolder, fileName);
        
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await imageFile.CopyToAsync(stream);
        }
        
        var message = new Message
        {
            ChatId = chatId,
            SenderId = userId,
            Type = MessageType.Image,
            FilePath = $"/images/{fileName}",
            Status = MessageStatus.Sent
        };
        
        await _unitOfWork.Messages.AddAsync(message);
        await _unitOfWork.SaveChangesAsync();
        
        var sender = await _unitOfWork.Users.GetByIdAsync(userId);
        if (sender == null)
        {
            _logger.LogError($"User {userId} not found after sending image message");
            return StatusCode(500, "Internal server error: User not found");
        }
        
        var messageDto = new MessageDto
        {
            Id = message.Id,
            ChatId = message.ChatId,
            SenderId = message.SenderId,
            SenderName = sender.DisplayName,
            Type = message.Type,
            Content = message.Content,
            FilePath = message.FilePath,
            Status = message.Status,
            CreatedAt = message.CreatedAt
        };
        
        // Send SignalR notification ONLY to group
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        if (chat != null)
        {
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
            var body = message.Type switch
            {
                MessageType.Text => message.Content?.Length > 100 ? message.Content.Substring(0, 100) + "..." : message.Content,
                MessageType.Audio => "🎤 Аудио сообщение",
                MessageType.Image => "📷 Изображение",
                _ => "Новое сообщение"
            };

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
                        
                        int successCount = 0;
                        foreach (var token in tokens)
                        {
                            var (success, shouldDeactivate) = await _firebaseService.SendNotificationAsync(
                                token.Token, 
                                title, 
                                body ?? "", 
                                data);
                            
                            if (success)
                            {
                                successCount++;
                                // Update last used timestamp
                                token.LastUsedAt = DateTime.UtcNow;
                            }
                            else if (shouldDeactivate)
                            {
                                // Deactivate invalid token
                                _logger.LogWarning($"Deactivating invalid FCM token for user {participant.UserId}");
                                await _unitOfWork.FcmTokens.DeactivateTokenAsync(token.Token);
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
    
    /// <summary>
    /// Batch mark messages as read
    /// </summary>
    [HttpPost("mark-read")]
    public async Task<IActionResult> BatchMarkAsRead([FromBody] List<Guid> messageIds)
    {
        var userId = GetCurrentUserId();
        _logger.LogInformation($"Batch marking {messageIds.Count} messages as read for user {userId}");
        
        foreach (var messageId in messageIds)
        {
            var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
            if (message == null) continue;
            
            // Don't mark own messages as read
            if (message.SenderId == userId) continue;
            
            var chat = await _unitOfWork.Chats.GetByIdAsync(message.ChatId);
            if (chat == null) continue;
            
            // Create or update delivery receipt
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
            
            // For private chats, mark as read immediately
            if (chat.Type == ChatType.Private && message.Status != MessageStatus.Read)
            {
                message.Status = MessageStatus.Read;
                message.ReadAt = DateTime.UtcNow;
                await _unitOfWork.Messages.UpdateAsync(message);
                
                await _hubContext.Clients.Group(message.ChatId.ToString())
                    .SendAsync("MessageStatusUpdated", messageId, (int)MessageStatus.Read);
            }
            // For group chats, check if all participants have read it
            else if (chat.Type == ChatType.Group)
            {
                var participantsCount = chat.Participants.Count;
                var readCount = await _unitOfWork.DeliveryReceipts.GetReadCountAsync(messageId);
                
                if (readCount >= participantsCount - 1 && message.Status != MessageStatus.Read)
                {
                    message.Status = MessageStatus.Read;
                    message.ReadAt = DateTime.UtcNow;
                    await _unitOfWork.Messages.UpdateAsync(message);
                    
                    await _hubContext.Clients.Group(message.ChatId.ToString())
                        .SendAsync("MessageStatusUpdated", messageId, (int)MessageStatus.Read);
                }
            }
        }
        
        await _unitOfWork.SaveChangesAsync();
        return Ok(new { message = $"Marked {messageIds.Count} messages as read" });
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


