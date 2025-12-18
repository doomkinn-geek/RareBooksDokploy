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
    
    // Client-side generated ID for idempotency
    public string? ClientMessageId { get; set; }
    
    // Navigation properties
    public Chat Chat { get; set; } = null!;
    public User Sender { get; set; } = null!;
}


