namespace MayMessenger.Domain.Entities;

public class ChatParticipant
{
    public Guid ChatId { get; set; }
    public Guid UserId { get; set; }
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
    public bool IsAdmin { get; set; } = false;
    
    // Navigation properties
    public Chat Chat { get; set; } = null!;
    public User User { get; set; } = null!;
}


