using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Entities;

/// <summary>
/// Event sourcing entity for tracking message status changes
/// Provides complete audit trail and guarantees status consistency
/// </summary>
public class MessageStatusEvent : BaseEntity
{
    public Guid MessageId { get; set; }
    public MessageStatus Status { get; set; }
    
    /// <summary>
    /// User who triggered this status change (for delivered/read in groups)
    /// Null for status changes initiated by sender (e.g., sent)
    /// </summary>
    public Guid? UserId { get; set; }
    
    /// <summary>
    /// Source of the status change: "REST", "SignalR", "Background", "Migration"
    /// </summary>
    public string Source { get; set; } = "Unknown";
    
    /// <summary>
    /// Timestamp when this status event occurred
    /// Using separate field from BaseEntity.CreatedAt for precision
    /// </summary>
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    
    // Navigation properties
    public Message Message { get; set; } = null!;
    public User? User { get; set; }
}

