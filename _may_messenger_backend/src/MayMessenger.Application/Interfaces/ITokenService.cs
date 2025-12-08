using MayMessenger.Domain.Entities;

namespace MayMessenger.Application.Interfaces;

public interface ITokenService
{
    string GenerateAccessToken(User user);
    string GenerateRefreshToken();
}


