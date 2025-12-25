namespace MayMessenger.Domain.Entities;

public class ChatParticipant
{
    public Guid ChatId { get; set; }
    public Guid UserId { get; set; }
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
    
    /// <summary>
    /// Owner (creator) of the group - can add/remove participants, 
    /// delete any message, and promote/demote admins
    /// </summary>
    public bool IsOwner { get; set; } = false;
    
    /// <summary>
    /// Admin can add/remove participants but cannot delete other's messages 
    /// or change admin status
    /// </summary>
    public bool IsAdmin { get; set; } = false;
    
    // Navigation properties
    public Chat Chat { get; set; } = null!;
    public User User { get; set; } = null!;
}


