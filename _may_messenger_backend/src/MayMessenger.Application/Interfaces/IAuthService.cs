namespace MayMessenger.Application.Interfaces;

public interface IAuthService
{
    Task<(bool Success, string Token, string Message)> RegisterAsync(string phoneNumber, string displayName, string password, string inviteCode, CancellationToken cancellationToken = default);
    Task<(bool Success, string Token, string Message)> LoginAsync(string phoneNumber, string password, CancellationToken cancellationToken = default);
}


