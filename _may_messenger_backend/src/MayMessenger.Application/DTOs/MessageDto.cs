using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

public class MessageDto
{
    public Guid Id { get; set; }
    public Guid ChatId { get; set; }
    public Guid SenderId { get; set; }
    public string SenderName { get; set; } = string.Empty;
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public string? FilePath { get; set; }
    public MessageStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? ClientMessageId { get; set; } // For deduplication on client
    
    // For file messages
    public string? OriginalFileName { get; set; }
    public long? FileSize { get; set; }
    
    // Reply functionality
    public Guid? ReplyToMessageId { get; set; }
    public ReplyMessageDto? ReplyToMessage { get; set; }
    
    // Forward functionality
    public Guid? ForwardedFromMessageId { get; set; }
    public Guid? ForwardedFromUserId { get; set; }
    public string? ForwardedFromUserName { get; set; }
    
    // Edit functionality
    public bool IsEdited { get; set; }
    public DateTime? EditedAt { get; set; }
    
    // Deletion
    public bool IsDeleted { get; set; }
    
    // End-to-end encryption
    public bool IsEncrypted { get; set; }
}

/// <summary>
/// Simplified DTO for replied message to avoid circular references
/// </summary>
public class ReplyMessageDto
{
    public Guid Id { get; set; }
    public Guid SenderId { get; set; }
    public string SenderName { get; set; } = string.Empty;
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public string? OriginalFileName { get; set; }
}


