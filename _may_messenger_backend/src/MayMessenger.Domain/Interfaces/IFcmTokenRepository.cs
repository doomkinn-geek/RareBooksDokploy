using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IFcmTokenRepository
{
    Task<FcmToken?> GetByTokenAsync(string token);
    Task<List<FcmToken>> GetActiveTokensForUserAsync(Guid userId);
    Task<List<FcmToken>> GetTokensOlderThanAsync(DateTime cutoffDate);
    Task RegisterOrUpdateAsync(Guid userId, string token, string deviceInfo);
    Task DeactivateTokenAsync(string token);
    Task DeactivateUserTokensAsync(Guid userId);
}
