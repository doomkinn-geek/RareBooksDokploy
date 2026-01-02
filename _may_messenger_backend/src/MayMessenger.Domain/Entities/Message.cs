using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Entities;

public class Message : BaseEntity
{
    public Guid ChatId { get; set; }
    public Guid SenderId { get; set; }
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public string? FilePath { get; set; }
    public MessageStatus Status { get; set; } = MessageStatus.Sending;
    public DateTime? DeliveredAt { get; set; }
    public DateTime? ReadAt { get; set; }
    public DateTime? PlayedAt { get; set; }  // For audio messages
    
    // For file messages: original file name and size
    public string? OriginalFileName { get; set; }
    public long? FileSize { get; set; }
    
    // Client-side generated ID for idempotency
    public string? ClientMessageId { get; set; }
    
    // Reply functionality
    public Guid? ReplyToMessageId { get; set; }
    public Message? ReplyToMessage { get; set; }
    
    // Forward functionality
    public Guid? ForwardedFromMessageId { get; set; }
    public Guid? ForwardedFromUserId { get; set; }
    public string? ForwardedFromUserName { get; set; }
    
    // Edit functionality
    public bool IsEdited { get; set; } = false;
    public DateTime? EditedAt { get; set; }
    
    // Deletion
    public bool IsDeleted { get; set; } = false;
    public DateTime? DeletedAt { get; set; }
    
    // End-to-end encryption
    public bool IsEncrypted { get; set; } = false;
    
    // Navigation properties
    public Chat Chat { get; set; } = null!;
    public User Sender { get; set; } = null!;
}


