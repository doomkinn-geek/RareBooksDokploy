using System.Security.Cryptography;
using System.Text;
using MayMessenger.Application.Interfaces;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Utils;

namespace MayMessenger.Infrastructure.Services;

public class AuthService : IAuthService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ITokenService _tokenService;
    
    public AuthService(
        IUnitOfWork unitOfWork,
        IPasswordHasher passwordHasher,
        ITokenService tokenService)
    {
        _unitOfWork = unitOfWork;
        _passwordHasher = passwordHasher;
        _tokenService = tokenService;
    }
    
    private string ComputePhoneNumberHash(string phoneNumber)
    {
        // Normalize phone number before hashing
        var normalized = PhoneNumberHelper.Normalize(phoneNumber);
        using var sha256 = SHA256.Create();
        var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(normalized));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
    
    public async Task<(bool Success, string Token, string Message)> RegisterAsync(
        string phoneNumber,
        string displayName,
        string password,
        string inviteCode,
        CancellationToken cancellationToken = default)
    {
        // Проверка существования пользователя
        if (await _unitOfWork.Users.PhoneNumberExistsAsync(phoneNumber, cancellationToken))
        {
            return (false, string.Empty, "Phone number already registered");
        }
        
        // Проверка инвайт-кода
        var isValidInvite = await _unitOfWork.InviteLinks.ValidateInviteCodeAsync(inviteCode, cancellationToken);
        if (!isValidInvite)
        {
            return (false, string.Empty, "Invalid or expired invite code");
        }
        
        var invite = await _unitOfWork.InviteLinks.GetByCodeAsync(inviteCode, cancellationToken);
        
        // Создание пользователя
        var user = new User
        {
            PhoneNumber = phoneNumber,
            PhoneNumberHash = ComputePhoneNumberHash(phoneNumber),
            DisplayName = displayName,
            PasswordHash = _passwordHasher.HashPassword(password),
            Role = UserRole.User,
            InvitedBy = invite?.CreatedBy
        };
        
        await _unitOfWork.Users.AddAsync(user, cancellationToken);
        
        // Обновление инвайт-кода
        if (invite != null && invite.UsesLeft.HasValue)
        {
            invite.UsesLeft--;
            if (invite.UsesLeft <= 0)
            {
                invite.IsActive = false;
            }
            await _unitOfWork.InviteLinks.UpdateAsync(invite, cancellationToken);
        }
        
        await _unitOfWork.SaveChangesAsync(cancellationToken);
        
        var token = _tokenService.GenerateAccessToken(user);
        return (true, token, "Registration successful");
    }
    
    public async Task<(bool Success, string Token, string Message)> LoginAsync(
        string phoneNumber,
        string password,
        CancellationToken cancellationToken = default)
    {
        var user = await _unitOfWork.Users.GetByPhoneNumberAsync(phoneNumber, cancellationToken);
        
        if (user == null)
        {
            return (false, string.Empty, "Invalid phone number or password");
        }
        
        if (!_passwordHasher.VerifyPassword(password, user.PasswordHash))
        {
            return (false, string.Empty, "Invalid phone number or password");
        }
        
        var token = _tokenService.GenerateAccessToken(user);
        return (true, token, "Login successful");
    }
}


