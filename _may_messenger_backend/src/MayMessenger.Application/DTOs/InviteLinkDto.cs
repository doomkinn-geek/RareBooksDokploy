namespace MayMessenger.Application.DTOs;

public class InviteLinkDto
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public int? UsesLeft { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}


