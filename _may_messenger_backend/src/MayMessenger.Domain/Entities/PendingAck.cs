using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Entities;

/// <summary>
/// Represents a pending acknowledgment that needs to be confirmed by the client.
/// Used for reliable message delivery via SignalR.
/// </summary>
public class PendingAck
{
    public Guid Id { get; set; }
    public Guid MessageId { get; set; }
    public Guid RecipientUserId { get; set; }
    public AckType Type { get; set; }
    public int RetryCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? LastRetryAt { get; set; }
    
    // Navigation properties
    public Message Message { get; set; } = null!;
    public User RecipientUser { get; set; } = null!;
}

