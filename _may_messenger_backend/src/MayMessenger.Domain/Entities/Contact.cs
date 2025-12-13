namespace MayMessenger.Domain.Entities;

public class Contact : BaseEntity
{
    public Guid UserId { get; set; }
    public string PhoneNumberHash { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
    public DateTime SyncedAt { get; set; }
    
    // Navigation property
    public User User { get; set; } = null!;
}
