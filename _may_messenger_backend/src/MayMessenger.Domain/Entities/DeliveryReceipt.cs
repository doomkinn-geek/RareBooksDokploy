namespace MayMessenger.Domain.Entities;

public class DeliveryReceipt : BaseEntity
{
    public Guid MessageId { get; set; }
    public Guid UserId { get; set; }
    public DateTime? DeliveredAt { get; set; }
    public DateTime? ReadAt { get; set; }
    public DateTime? PlayedAt { get; set; } // For audio messages
    
    // Navigation properties
    public Message Message { get; set; } = null!;
    public User User { get; set; } = null!;
}
