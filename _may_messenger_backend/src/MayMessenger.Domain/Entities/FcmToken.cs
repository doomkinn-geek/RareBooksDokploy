namespace MayMessenger.Domain.Entities;

public class FcmToken
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string Token { get; set; } = string.Empty;
    public string DeviceInfo { get; set; } = string.Empty;
    public DateTime RegisteredAt { get; set; }
    public DateTime? LastUsedAt { get; set; }
    public bool IsActive { get; set; } = true;

    // Navigation property
    public User User { get; set; } = null!;
}
