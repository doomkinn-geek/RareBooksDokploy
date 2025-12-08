namespace MayMessenger.Domain.Entities;

public class InviteLink : BaseEntity
{
    public string Code { get; set; } = string.Empty;
    public Guid CreatedBy { get; set; }
    public int? UsesLeft { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool IsActive { get; set; } = true;
    
    // Navigation properties
    public User Creator { get; set; } = null!;
}


