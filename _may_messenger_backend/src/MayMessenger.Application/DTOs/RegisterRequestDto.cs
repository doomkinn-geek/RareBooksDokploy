namespace MayMessenger.Application.DTOs;

public class RegisterRequestDto
{
    public string PhoneNumber { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string InviteCode { get; set; } = string.Empty;
}


