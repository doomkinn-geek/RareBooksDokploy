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
}


