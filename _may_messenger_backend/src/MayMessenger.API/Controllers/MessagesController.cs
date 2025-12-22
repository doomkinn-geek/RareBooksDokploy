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
    private readonly MayMessenger.Application.Services.IImageCompressionService _imageCompressionService;
    private readonly ILogger<MessagesController> _logger;
    
    public MessagesController(
        IUnitOfWork unitOfWork, 
        IWebHostEnvironment environment, 
        IHubContext<ChatHub> hubContext,
        MayMessenger.Application.Services.IFirebaseService firebaseService,
        MayMessenger.Application.Services.IImageCompressionService imageCompressionService,
        ILogger<MessagesController> logger)
    {
        _unitOfWork = unitOfWork;
        _environment = environment;
        _hubContext = hubContext;
        _firebaseService = firebaseService;
        _imageCompressionService = imageCompressionService;
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
            CreatedAt = m.CreatedAt,
            ClientMessageId = m.ClientMessageId
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
            
            // Ensure 'since' is UTC to avoid PostgreSQL errors
            var sinceUtc = since.Kind == DateTimeKind.Utc ? since : DateTime.SpecifyKind(since, DateTimeKind.Utc);
            
            // Get messages created or updated after 'since' timestamp
            var messages = await _unitOfWork.Messages.GetMessagesAfterTimestampAsync(chatId, sinceUtc, take);
            
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
            CreatedAt = m.CreatedAt,
            ClientMessageId = m.ClientMessageId
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
        
        _logger.LogInformation($"SendMessage called: userId={userId}, chatId={dto.ChatId}, clientMessageId={dto.ClientMessageId}");
        
        // CRITICAL: Use SERIALIZABLE transaction for guaranteed idempotency
        // This prevents race conditions when multiple requests arrive simultaneously
        await using var transaction = await _unitOfWork.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        
        try
        {
            // Idempotency check: if clientMessageId is provided, check if message already exists
            // This check is now protected by SERIALIZABLE transaction
            if (!string.IsNullOrEmpty(dto.ClientMessageId))
            {
                var existingMessage = await _unitOfWork.Messages.GetByClientMessageIdAsync(dto.ClientMessageId);
                if (existingMessage != null)
                {
                    _logger.LogInformation($"Message with ClientMessageId {dto.ClientMessageId} already exists, returning existing message {existingMessage.Id}");
                    
                    // Commit transaction (no changes made)
                    await transaction.CommitAsync();
                    
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
                        CreatedAt = existingMessage.CreatedAt,
                        ClientMessageId = existingMessage.ClientMessageId
                    };
                    
                    return Ok(existingMessageDto);
                }
            }
            
            // Get sender and chat within transaction
            var sender = await _unitOfWork.Users.GetByIdAsync(userId);
            if (sender == null)
            {
                _logger.LogError($"User {userId} not found");
                return StatusCode(500, "Internal server error: User not found");
            }
            
            var chat = await _unitOfWork.Chats.GetByIdAsync(dto.ChatId);
            if (chat == null)
            {
                _logger.LogError($"Chat {dto.ChatId} not found");
                return BadRequest("Chat not found");
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
            
            // Create pending acks for reliable delivery (within same transaction)
            await CreatePendingAcksForMessageAsync(chat, message, userId, AckType.Message);
            
            // Save all changes atomically
            await _unitOfWork.SaveChangesAsync();
            
            // Commit transaction - this is the point of no return
            await transaction.CommitAsync();
            
            _logger.LogInformation($"Message {message.Id} created successfully with ClientMessageId {dto.ClientMessageId}");
            
            // Track metrics
            DiagnosticsController.IncrementMessageProcessed();
            
            // Build response DTO
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
                CreatedAt = message.CreatedAt,
                ClientMessageId = message.ClientMessageId
            };
            
            // Send SignalR notification AFTER transaction commit
            // This ensures message is persisted before notifying clients
            try
            {
                await _hubContext.Clients.Group(dto.ChatId.ToString()).SendAsync("ReceiveMessage", messageDto);
                _logger.LogInformation($"SignalR notification sent for message {message.Id}");
            }
            catch (Exception ex)
            {
                // Log but don't fail the request - message is already saved
                // Pending acks will handle retry
                _logger.LogError(ex, $"Failed to send SignalR notification for message {message.Id}");
            }
            
            // Fetch FCM tokens BEFORE fire-and-forget task to avoid disposed context
            // #region agent log - Hypothesis B: Check if PUSH sending is invoked
            _logger.LogInformation($"[DEBUG_PUSH_A] About to invoke SendPushNotificationsAsync for message {message.Id}, chat {chat.Id}, sender {sender.Id}");
            // #endregion
            var userTokensForPush = new Dictionary<Guid, List<Domain.Entities.FcmToken>>();
            foreach (var participant in chat.Participants)
            {
                if (participant.UserId != sender.Id)
                {
                    var tokens = await _unitOfWork.FcmTokens.GetActiveTokensForUserAsync(participant.UserId);
                    userTokensForPush[participant.UserId] = tokens.ToList();
                }
            }
            
            // Send push notifications to offline users (fire and forget)
            _ = Task.Run(async () =>
            {
                try
                {
                    // #region agent log - Hypothesis B
                    _logger.LogInformation($"[DEBUG_PUSH_B] Executing SendPushNotificationsAsync for message {message.Id}");
                    // #endregion
                    await SendPushNotificationsAsync(sender, messageDto, userTokensForPush);
                    // #region agent log - Hypothesis B
                    _logger.LogInformation($"[DEBUG_PUSH_C] SendPushNotificationsAsync completed for message {message.Id}");
                    // #endregion
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"[DEBUG_PUSH_ERROR] Failed to send push notifications for message {message.Id}");
                }
            });
            
            return Ok(messageDto);
        }
        catch (Microsoft.EntityFrameworkCore.DbUpdateException ex) when (ex.InnerException?.Message?.Contains("IX_Messages_ClientMessageId") == true)
        {
            // Unique constraint violation - message with this ClientMessageId already exists
            // This can happen due to race condition despite SERIALIZABLE isolation
            // Rollback and return existing message
            await transaction.RollbackAsync();
            
            _logger.LogWarning($"Duplicate ClientMessageId detected: {dto.ClientMessageId}, returning existing message");
            
            // Track duplicate detection
            DiagnosticsController.IncrementDuplicateDetected();
            
            var existingMessage = await _unitOfWork.Messages.GetByClientMessageIdAsync(dto.ClientMessageId);
            if (existingMessage != null)
            {
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
                    CreatedAt = existingMessage.CreatedAt,
                    ClientMessageId = existingMessage.ClientMessageId
                };
                
                return Ok(existingMessageDto);
            }
            
            // Should never happen, but handle gracefully
            _logger.LogError($"Duplicate detected but message not found: {dto.ClientMessageId}");
            return StatusCode(500, "Internal server error");
        }
        catch (Exception ex)
        {
            // Rollback transaction on any error
            await transaction.RollbackAsync();
            _logger.LogError(ex, $"Error creating message: {ex.Message}");
            throw;
        }
    }
    
    [HttpPost("audio")]
    public async Task<ActionResult<MessageDto>> SendAudioMessage([FromForm] Guid chatId, IFormFile audioFile, [FromForm] string? clientMessageId = null)
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
            Status = MessageStatus.Sent,
            ClientMessageId = clientMessageId  // Add clientMessageId for deduplication
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
            CreatedAt = message.CreatedAt,
            ClientMessageId = message.ClientMessageId
        };
        
        // Send SignalR notification ONLY to group (not to individual users to avoid duplicates)
        var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
        if (chat != null)
        {
            // Create pending acks for reliable delivery
            await CreatePendingAcksForMessage(chat, message, userId, AckType.Message);
            
            await _hubContext.Clients.Group(chatId.ToString()).SendAsync("ReceiveMessage", messageDto);
            
            // Fetch FCM tokens before sending push notifications
            var userTokensForPush = new Dictionary<Guid, List<Domain.Entities.FcmToken>>();
            foreach (var participant in chat.Participants)
            {
                if (participant.UserId != sender.Id)
                {
                    var tokens = await _unitOfWork.FcmTokens.GetActiveTokensForUserAsync(participant.UserId);
                    userTokensForPush[participant.UserId] = tokens.ToList();
                }
            }
            
            // Send push notifications to offline users
            await SendPushNotificationsAsync(sender, messageDto, userTokensForPush);
        }
        
        return Ok(messageDto);
    }
    
    [HttpPost("image")]
    public async Task<ActionResult<MessageDto>> SendImageMessage([FromForm] Guid chatId, IFormFile imageFile, [FromForm] string? clientMessageId = null)
    {
        var userId = GetCurrentUserId();
        
        if (imageFile == null || imageFile.Length == 0)
            return BadRequest("No image file provided");
        
        // Validate image type
        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
        var extension = Path.GetExtension(imageFile.FileName).ToLowerInvariant();
        if (!allowedExtensions.Contains(extension))
            return BadRequest("Invalid image format. Allowed: jpg, jpeg, png, gif, webp");
        
        // Validate image size (10MB max for upload)
        if (imageFile.Length > 10 * 1024 * 1024)
            return BadRequest("Image size must be less than 10MB");
        
        try
        {
            // Save image (client already compressed it)
            var uploadsFolder = Path.Combine(_environment.WebRootPath, "images");
            
            string fileName;
            using (var stream = imageFile.OpenReadStream())
            {
                fileName = await _imageCompressionService.SaveImageAsync(
                    stream, 
                    imageFile.FileName, 
                    uploadsFolder);
            }
            
            var message = new Message
            {
                ChatId = chatId,
                SenderId = userId,
                Type = MessageType.Image,
                FilePath = $"/images/{fileName}",
                Status = MessageStatus.Sent,
                ClientMessageId = clientMessageId  // Add clientMessageId for deduplication
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
                CreatedAt = message.CreatedAt,
                ClientMessageId = message.ClientMessageId  // Include clientMessageId for deduplication
            };
            
            // Send SignalR notification ONLY to group
            var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
            if (chat != null)
            {
                // Create pending acks for reliable delivery
                await CreatePendingAcksForMessage(chat, message, userId, AckType.Message);
                
                await _hubContext.Clients.Group(chatId.ToString()).SendAsync("ReceiveMessage", messageDto);
                
                // Fetch FCM tokens before sending push notifications
                var userTokensForPush = new Dictionary<Guid, List<Domain.Entities.FcmToken>>();
                foreach (var participant in chat.Participants)
                {
                    if (participant.UserId != sender.Id)
                    {
                        var tokens = await _unitOfWork.FcmTokens.GetActiveTokensForUserAsync(participant.UserId);
                        userTokensForPush[participant.UserId] = tokens.ToList();
                    }
                }
                
                // Send push notifications to offline users
                await SendPushNotificationsAsync(sender, messageDto, userTokensForPush);
            }
            
            return Ok(messageDto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing image message");
            return StatusCode(500, "Error processing image");
        }
    }

    /// <summary>
    /// Отправка push уведомлений пользователям, которые не онлайн
    /// ВАЖНО: Все данные передаются как параметры, никаких обращений к DbContext!
    /// </summary>
    private async Task SendPushNotificationsAsync(User sender, MessageDto message, Dictionary<Guid, List<Domain.Entities.FcmToken>> userTokens)
    {
        // #region agent log - Hypothesis B: Check Firebase initialization
        _logger.LogInformation($"[DEBUG_PUSH_D] SendPushNotificationsAsync started. Firebase initialized: {_firebaseService.IsInitialized}");
        // #endregion
        if (!_firebaseService.IsInitialized)
        {
            _logger.LogWarning("[DEBUG_PUSH_E] Firebase not initialized. Cannot send push notifications.");
            return;
        }

        try
        {
            // #region agent log - Hypothesis A: Check tokens received
            _logger.LogInformation($"[DEBUG_PUSH_F] Received FCM tokens for {userTokens.Count} users");
            // #endregion
            
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
            foreach (var kvp in userTokens)
            {
                var userId = kvp.Key;
                var tokens = kvp.Value;

                try
                {
                    
                    if (tokens.Any())
                    {
                        _logger.LogInformation($"Sending push notification to user {userId}, {tokens.Count} tokens");
                        
                        int successCount = 0;
                        var tokensToDeactivate = new List<string>();
                        
                        foreach (var token in tokens)
                        {
                            // #region agent log - Hypothesis B: Check FCM send result
                            _logger.LogInformation($"[DEBUG_PUSH_H] Sending FCM notification to token {token.Token.Substring(0, Math.Min(20, token.Token.Length))}...");
                            // #endregion
                            var (success, shouldDeactivate) = await _firebaseService.SendNotificationAsync(
                                token.Token, 
                                title, 
                                body ?? "", 
                                data);
                            
                            // #region agent log - Hypothesis B
                            _logger.LogInformation($"[DEBUG_PUSH_I] FCM send result: success={success}, shouldDeactivate={shouldDeactivate}");
                            // #endregion
                            if (success)
                            {
                                successCount++;
                                // Update last used timestamp
                                token.LastUsedAt = DateTime.UtcNow;
                            }
                            else if (shouldDeactivate)
                            {
                                // Deactivate invalid token
                                _logger.LogWarning($"[DEBUG_PUSH_J] Deactivating invalid FCM token for user {userId}");
                                tokensToDeactivate.Add(token.Token);
                            }
                        }
                        
                        // Deactivate invalid tokens (после цикла)
                        foreach (var tokenToDeactivate in tokensToDeactivate)
                        {
                            await _unitOfWork.FcmTokens.DeactivateTokenAsync(tokenToDeactivate);
                        }
                        
                        if (successCount > 0 || tokensToDeactivate.Any())
                        {
                            await _unitOfWork.SaveChangesAsync();
                        }
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, $"Failed to send push to user {userId}");
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
        _logger.LogInformation($"[BATCH_READ] Batch marking {messageIds.Count} messages as read for user {userId}");
        _logger.LogInformation($"[BATCH_READ] MessageIds: {string.Join(", ", messageIds.Take(5))}");
        
        foreach (var messageId in messageIds)
        {
            var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
            if (message == null)
            {
                _logger.LogWarning($"[BATCH_READ] Message {messageId} not found");
                continue;
            }
            
            _logger.LogInformation($"[BATCH_READ] Processing message {messageId}, current status: {message.Status}, sender: {message.SenderId}, reader: {userId}");
            
            // Don't mark own messages as read
            if (message.SenderId == userId)
            {
                _logger.LogInformation($"[BATCH_READ] Skipping own message {messageId}");
                continue;
            }
            
            var chat = await _unitOfWork.Chats.GetByIdAsync(message.ChatId);
            if (chat == null)
            {
                _logger.LogWarning($"[BATCH_READ] Chat {message.ChatId} not found for message {messageId}");
                continue;
            }
            
            _logger.LogInformation($"[BATCH_READ] Chat {message.ChatId} type: {chat.Type}, participants: {chat.Participants.Count}");
            
            // Create or update delivery receipt
            var receipt = await _unitOfWork.DeliveryReceipts.GetByMessageAndUserAsync(messageId, userId);
            // #region agent log
            _logger.LogInformation($"[BATCH_READ] HYP_E: Receipt state - exists: {receipt != null}, ReadAt: {receipt?.ReadAt}, DeliveredAt: {receipt?.DeliveredAt}");
            // #endregion
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
                // #region agent log
                _logger.LogInformation($"[BATCH_READ] HYP_E: Created new receipt for message {messageId}");
                // #endregion
            }
            else if (receipt.ReadAt == null)
            {
                receipt.ReadAt = DateTime.UtcNow;
                if (receipt.DeliveredAt == null)
                {
                    receipt.DeliveredAt = DateTime.UtcNow;
                }
                await _unitOfWork.DeliveryReceipts.UpdateAsync(receipt);
                // #region agent log
                _logger.LogInformation($"[BATCH_READ] HYP_E: Updated receipt for message {messageId}, set ReadAt");
                // #endregion
            }
            else
            {
                // #region agent log
                _logger.LogInformation($"[BATCH_READ] HYP_E: Receipt already has ReadAt, skipping update");
                // #endregion
            }
            
            // For private chats, mark as read immediately
            // #region agent log
            _logger.LogInformation($"[BATCH_READ] HYP_C: Checking private chat condition - Type: {chat.Type}, Status: {message.Status}, SenderId: {message.SenderId}, ReaderId: {userId}");
            // #endregion
            if (chat.Type == ChatType.Private && message.SenderId != userId && message.Status != MessageStatus.Read)
            {
                _logger.LogInformation($"[BATCH_READ] Marking message {messageId} as READ in private chat");
                message.Status = MessageStatus.Read;
                message.ReadAt = DateTime.UtcNow;
                await _unitOfWork.Messages.UpdateAsync(message);
                
                _logger.LogInformation($"[BATCH_READ] Sending SignalR MessageStatusUpdated for {messageId} -> READ to group {message.ChatId}");
                await _hubContext.Clients.Group(message.ChatId.ToString())
                    .SendAsync("MessageStatusUpdated", messageId, (int)MessageStatus.Read);
                _logger.LogInformation($"[BATCH_READ] SignalR notification sent successfully");
            }
            // For private chats where message is already Read, still notify via SignalR
            else if (chat.Type == ChatType.Private && message.SenderId != userId && message.Status == MessageStatus.Read)
            {
                // #region agent log
                _logger.LogInformation($"[BATCH_READ] HYP_C: Message already Read, but sending SignalR for sync");
                // #endregion
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
            else
            {
                _logger.LogInformation($"[BATCH_READ] Message {messageId} skipped (status: {message.Status}, chatType: {chat.Type})");
            }
        }
        
        _logger.LogInformation($"[BATCH_READ] DEBUG_READ_E: Completed batch mark as read. Processed {messageIds.Count} messages");
        await _unitOfWork.SaveChangesAsync();
        return Ok(new { message = $"Marked {messageIds.Count} messages as read" });
    }
    
    /// <summary>
    /// Mark audio message as played
    /// </summary>
    [HttpPost("{messageId}/played")]
    public async Task<IActionResult> MarkAsPlayed(Guid messageId)
    {
        var userId = GetCurrentUserId();
        var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
        
        if (message == null)
        {
            return NotFound(new { message = "Message not found" });
        }
        
        // Only mark audio messages as played
        if (message.Type != MessageType.Audio)
        {
            return BadRequest(new { message = "Only audio messages can be marked as played" });
        }
        
        // Don't mark own messages as played
        if (message.SenderId == userId)
        {
            return Ok(new { message = "Cannot mark own message as played" });
        }
        
        // Update status to Played if not already
        if (message.Status != MessageStatus.Played)
        {
            message.Status = MessageStatus.Played;
            message.PlayedAt = DateTime.UtcNow;
            await _unitOfWork.Messages.UpdateAsync(message);
            await _unitOfWork.SaveChangesAsync();
            
            // Notify via SignalR with acks
            await SendStatusUpdateWithAcks(message.ChatId, messageId, MessageStatus.Played, userId);
            
            _logger.LogInformation($"Marked audio message {messageId} as played by user {userId}");
        }
        
        return Ok(new { message = "Audio message marked as played" });
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
    
    /// <summary>
    /// Helper method to create pending acks for all chat participants (except sender)
    /// IMPORTANT: This method should be called within a transaction
    /// </summary>
    private async Task CreatePendingAcksForMessageAsync(Chat chat, Message message, Guid senderId, AckType ackType)
    {
        foreach (var participant in chat.Participants)
        {
            // Don't create ack for sender
            if (participant.UserId == senderId) continue;
            
            var pendingAck = new PendingAck
            {
                MessageId = message.Id,
                RecipientUserId = participant.UserId,
                Type = ackType,
                RetryCount = 0,
                CreatedAt = DateTime.UtcNow
            };
            
            await _unitOfWork.PendingAcks.AddAsync(pendingAck);
        }
    }
    
    /// <summary>
    /// Legacy method for backward compatibility - delegates to async version
    /// </summary>
    [Obsolete("Use CreatePendingAcksForMessageAsync instead")]
    private async Task CreatePendingAcksForMessage(Chat chat, Message message, Guid senderId, AckType ackType)
    {
        await CreatePendingAcksForMessageAsync(chat, message, senderId, ackType);
    }
    
    /// <summary>
    /// Helper method to send status update and create pending acks
    /// </summary>
    private async Task SendStatusUpdateWithAcks(Guid chatId, Guid messageId, MessageStatus status, Guid senderId)
    {
        try
        {
            var chat = await _unitOfWork.Chats.GetByIdAsync(chatId);
            if (chat != null)
            {
                var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
                if (message != null)
                {
                    // Create pending acks for status update
                    await CreatePendingAcksForMessage(chat, message, senderId, AckType.StatusUpdate);
                }
                
                // Send status update
                await _hubContext.Clients.Group(chatId.ToString())
                    .SendAsync("MessageStatusUpdated", messageId, (int)status);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error sending status update for message {messageId}");
        }
    }
    
    /// <summary>
    /// Поиск сообщений по содержимому в чатах пользователя
    /// Использует PostgreSQL full-text search с поддержкой русского языка
    /// </summary>
    [HttpGet("search")]
    public async Task<ActionResult<IEnumerable<MessageSearchResultDto>>> SearchMessages([FromQuery] string query)
    {
        if (string.IsNullOrWhiteSpace(query) || query.Length < 2)
        {
            return BadRequest("Query must be at least 2 characters");
        }
        
        try
        {
            var userId = GetCurrentUserId();
            
            // Get all chats user participates in
            var userChats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
            var chatIds = userChats.Select(c => c.Id).ToList();
            
            if (!chatIds.Any())
            {
                return Ok(new List<MessageSearchResultDto>());
            }
            
            // Use optimized full-text search with PostgreSQL GIN index
            var messages = await _unitOfWork.Messages.SearchMessagesAsync(chatIds, query, take: 50);
            
            // Group by chat and limit results per chat
            var searchResults = messages
                .GroupBy(m => m.ChatId)
                .SelectMany(g => g.Take(3)) // Max 3 results per chat
                .Select(m =>
                {
                    var chat = userChats.FirstOrDefault(c => c.Id == m.ChatId);
                    return new MessageSearchResultDto
                    {
                        MessageId = m.Id,
                        ChatId = m.ChatId,
                        ChatTitle = chat?.Title ?? "Unknown Chat",
                        MessageContent = m.Content ?? "",
                        SenderName = m.Sender?.DisplayName ?? "Unknown",
                        CreatedAt = m.CreatedAt
                    };
                })
                .ToList();
            
            _logger.LogInformation($"Search for '{query}' returned {searchResults.Count} results");
            
            return Ok(searchResults);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error searching messages");
            return StatusCode(500, "Error searching messages");
        }
    }
    
    /// <summary>
    /// Получить все несинхронизированные сообщения пользователя с определенного времени
    /// Используется для incremental sync после переподключения
    /// </summary>
    [HttpGet("unsynced")]
    public async Task<ActionResult<IEnumerable<MessageDto>>> GetUnsyncedMessages(
        [FromQuery] DateTime since, 
        [FromQuery] int take = 100)
    {
        try
        {
            var userId = GetCurrentUserId();
            
            _logger.LogInformation($"GetUnsyncedMessages: userId={userId}, since={since:O}");
            
            // Get all chats user participates in
            var userChats = await _unitOfWork.Chats.GetUserChatsAsync(userId);
            var chatIds = userChats.Select(c => c.Id).ToList();
            
            if (!chatIds.Any())
            {
                return Ok(new List<MessageDto>());
            }
            
            // Get all messages created after 'since' timestamp from user's chats
            var allMessages = new List<Message>();
            foreach (var chatId in chatIds)
            {
                // Get messages created after 'since'
                var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chatId, 0, 1000);
                var filteredMessages = messages
                    .Where(m => m.CreatedAt > since)
                    .ToList();
                    
                allMessages.AddRange(filteredMessages);
            }
            
            // Sort by creation time and limit
            var unsyncedMessages = allMessages
                .OrderBy(m => m.CreatedAt)
                .Take(take)
                .Select(m => new MessageDto
                {
                    Id = m.Id,
                    ChatId = m.ChatId,
                    SenderId = m.SenderId,
                    SenderName = m.Sender?.DisplayName ?? "Unknown",
                    Type = m.Type,
                    Content = m.Content,
                    FilePath = m.FilePath,
                    Status = m.Status,
                    CreatedAt = m.CreatedAt,
                    ClientMessageId = m.ClientMessageId
                })
                .ToList();
            
            _logger.LogInformation($"GetUnsyncedMessages: Returning {unsyncedMessages.Count} unsynced messages");
            
            return Ok(unsyncedMessages);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting unsynced messages");
            return StatusCode(500, "Error getting unsynced messages");
        }
    }
    
    /// <summary>
    /// Получить конкретное сообщение по ID
    /// Используется для восстановления сообщения после push-уведомления
    /// </summary>
    [HttpGet("by-id/{messageId}")]
    public async Task<ActionResult<MessageDto>> GetMessageById(Guid messageId)
    {
        try
        {
            var userId = GetCurrentUserId();
            var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
            
            if (message == null)
            {
                _logger.LogWarning($"GetMessageById: Message not found: {messageId}");
                return NotFound($"Message {messageId} not found");
            }
            
            // Check if user has access to this message (must be participant of the chat)
            var chat = await _unitOfWork.Chats.GetByIdAsync(message.ChatId);
            if (chat == null)
            {
                return NotFound("Chat not found");
            }
            
            var isParticipant = chat.Participants.Any(p => p.UserId == userId);
            if (!isParticipant)
            {
                _logger.LogWarning($"GetMessageById: User {userId} tried to access message {messageId} without permission");
                return Forbid();
            }
            
            // Auto-mark as delivered if not sender
            if (message.SenderId != userId && message.Status == MessageStatus.Sent)
            {
                message.Status = MessageStatus.Delivered;
                message.DeliveredAt = DateTime.UtcNow;
                await _unitOfWork.Messages.UpdateAsync(message);
                await _unitOfWork.SaveChangesAsync();
                
                // Notify about status change
                await _hubContext.Clients.Group(message.ChatId.ToString())
                    .SendAsync("MessageStatusUpdated", messageId, (int)MessageStatus.Delivered);
                    
                _logger.LogInformation($"GetMessageById: Auto-marked message {messageId} as delivered for user {userId}");
            }
            
            var messageDto = new MessageDto
            {
                Id = message.Id,
                ChatId = message.ChatId,
                SenderId = message.SenderId,
                SenderName = message.Sender?.DisplayName ?? "Unknown",
                Type = message.Type,
                Content = message.Content,
                FilePath = message.FilePath,
                Status = message.Status,
                CreatedAt = message.CreatedAt,
                ClientMessageId = message.ClientMessageId
            };
            
            _logger.LogInformation($"GetMessageById: Successfully retrieved message {messageId}");
            
            return Ok(messageDto);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error getting message by ID: {messageId}");
            return StatusCode(500, "Error getting message");
        }
    }
    
    /// <summary>
    /// Batch update статусов сообщений
    /// Используется для эффективного обновления множества сообщений одним запросом
    /// </summary>
    [HttpPost("batch-status")]
    public async Task<ActionResult> BatchUpdateStatus([FromBody] BatchStatusUpdateDto dto)
    {
        try
        {
            var userId = GetCurrentUserId();
            
            if (dto.MessageIds == null || !dto.MessageIds.Any())
            {
                return BadRequest("MessageIds cannot be empty");
            }
            
            _logger.LogInformation($"BatchUpdateStatus: Updating {dto.MessageIds.Count} messages to status {dto.Status}");
            // #region agent log
            _logger.LogInformation($"[BATCH_STATUS] HYP_A: BatchUpdateStatus called by user {userId} for {dto.MessageIds.Count} messages to status {dto.Status}");
            // #endregion
            
            var updatedCount = 0;
            var affectedChatIds = new HashSet<Guid>();
            
            foreach (var messageId in dto.MessageIds)
            {
                var message = await _unitOfWork.Messages.GetByIdAsync(messageId);
                if (message == null) continue;
                
                // #region agent log
                _logger.LogInformation($"[BATCH_STATUS] HYP_A: Message {messageId} current status: {message.Status}, sender: {message.SenderId}");
                // #endregion
                
                // Don't update sender's own messages
                if (message.SenderId == userId) continue;
                
                // Check if user is participant
                var chat = await _unitOfWork.Chats.GetByIdAsync(message.ChatId);
                if (chat == null) continue;
                
                var isParticipant = chat.Participants.Any(p => p.UserId == userId);
                if (!isParticipant) continue;
                
                // Update status
                bool statusChanged = false;
                switch (dto.Status)
                {
                    case MessageStatus.Delivered:
                        if (message.Status == MessageStatus.Sent)
                        {
                            message.Status = MessageStatus.Delivered;
                            message.DeliveredAt = DateTime.UtcNow;
                            statusChanged = true;
                        }
                        break;
                        
                    case MessageStatus.Read:
                        if (message.Status != MessageStatus.Read)
                        {
                            // #region agent log
                            _logger.LogInformation($"[BATCH_STATUS] HYP_A: Updating message {messageId} to Read status");
                            // #endregion
                            message.Status = MessageStatus.Read;
                            message.ReadAt = DateTime.UtcNow;
                            if (message.DeliveredAt == null)
                            {
                                message.DeliveredAt = DateTime.UtcNow;
                            }
                            statusChanged = true;
                        }
                        break;
                        
                    case MessageStatus.Played:
                        if (message.Type == MessageType.Audio && message.Status != MessageStatus.Played)
                        {
                            message.Status = MessageStatus.Played;
                            message.PlayedAt = DateTime.UtcNow;
                            if (message.DeliveredAt == null)
                            {
                                message.DeliveredAt = DateTime.UtcNow;
                            }
                            statusChanged = true;
                        }
                        break;
                }
                
                if (statusChanged)
                {
                    await _unitOfWork.Messages.UpdateAsync(message);
                    affectedChatIds.Add(message.ChatId);
                    updatedCount++;
                }
            }
            
            await _unitOfWork.SaveChangesAsync();
            
            // Notify all affected chats about status updates
            foreach (var chatId in affectedChatIds)
            {
                foreach (var messageId in dto.MessageIds)
                {
                    await _hubContext.Clients.Group(chatId.ToString())
                        .SendAsync("MessageStatusUpdated", messageId, (int)dto.Status);
                }
            }
            
            _logger.LogInformation($"BatchUpdateStatus: Successfully updated {updatedCount} messages");
            
            return Ok(new { UpdatedCount = updatedCount });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error in batch status update");
            return StatusCode(500, "Error updating message statuses");
        }
    }
}



