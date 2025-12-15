using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IUserRepository : IRepository<User>
{
    Task<User?> GetByPhoneNumberAsync(string phoneNumber, CancellationToken cancellationToken = default);
    Task<bool> PhoneNumberExistsAsync(string phoneNumber, CancellationToken cancellationToken = default);
    Task<int> UpdatePhoneNumberHashesAsync(CancellationToken cancellationToken = default);
}


