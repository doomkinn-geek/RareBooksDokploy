using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IContactRepository
{
    Task<List<Contact>> GetUserContactsAsync(Guid userId);
    Task<List<User>> FindUsersByPhoneHashesAsync(List<string> phoneHashes);
    Task SyncContactsAsync(Guid userId, List<(string phoneHash, string? displayName)> contacts);
    Task<Contact?> GetByUserAndPhoneHashAsync(Guid userId, string phoneHash);
}
