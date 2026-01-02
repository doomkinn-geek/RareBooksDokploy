using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

public class UserDto
{
    public Guid Id { get; set; }
    public string PhoneNumber { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? Avatar { get; set; }
    public UserRole Role { get; set; }
    
    // Online status
    public bool IsOnline { get; set; }
    public DateTime? LastSeenAt { get; set; }
    
    // Profile fields
    public string? Bio { get; set; }
    public string? Status { get; set; }
    
    // Invitation info (for admin)
    public Guid? InvitedByUserId { get; set; }
    public string? InvitedByUserName { get; set; }
    public DateTime CreatedAt { get; set; }
    
    // End-to-end encryption - X25519 public key (Base64)
    public string? PublicKey { get; set; }
}


