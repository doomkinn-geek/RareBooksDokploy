namespace MayMessenger.Application.DTOs;

public class InviteLinkDto
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public int? UsesLeft { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    
    // Creator info
    public Guid CreatedById { get; set; }
    public string? CreatedByName { get; set; }
    
    // Status helpers
    public bool IsExpired => ExpiresAt.HasValue && ExpiresAt.Value < DateTime.UtcNow;
    public bool IsUsedUp => UsesLeft.HasValue && UsesLeft.Value <= 0;
    public bool IsValid => IsActive && !IsExpired && !IsUsedUp;
    
    // Status message for UI
    public string StatusMessage
    {
        get
        {
            if (!IsActive) return "Деактивирован";
            if (IsExpired) return "Истёк срок действия";
            if (IsUsedUp) return "Использован";
            return "Активен";
        }
    }
}

/// <summary>
/// Response for invite code validation
/// </summary>
public class ValidateInviteCodeResponse
{
    public bool IsValid { get; set; }
    public string Message { get; set; } = string.Empty;
    public string? CreatorName { get; set; }
    public int? UsesLeft { get; set; }
    public DateTime? ExpiresAt { get; set; }
}


