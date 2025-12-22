using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Entities;

public class User : BaseEntity
{
    public string PhoneNumber { get; set; } = string.Empty;
    public string PhoneNumberHash { get; set; } = string.Empty; // SHA256 hash for contact sync
    public string DisplayName { get; set; } = string.Empty;
    public string? Avatar { get; set; }
    public UserRole Role { get; set; } = UserRole.User;
    public Guid? InvitedBy { get; set; }
    public string PasswordHash { get; set; } = string.Empty;
    
    // Online status tracking
    public bool IsOnline { get; set; } = false;
    public DateTime? LastSeenAt { get; set; }
    
    // Navigation properties
    public User? InvitedByUser { get; set; }
    public ICollection<ChatParticipant> ChatParticipants { get; set; } = new List<ChatParticipant>();
    public ICollection<Message> Messages { get; set; } = new List<Message>();
    public ICollection<InviteLink> CreatedInviteLinks { get; set; } = new List<InviteLink>();
}


