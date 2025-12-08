using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class UserRepository : Repository<User>, IUserRepository
{
    public UserRepository(AppDbContext context) : base(context)
    {
    }
    
    public async Task<User?> GetByPhoneNumberAsync(string phoneNumber, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .FirstOrDefaultAsync(u => u.PhoneNumber == phoneNumber, cancellationToken);
    }
    
    public async Task<bool> PhoneNumberExistsAsync(string phoneNumber, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .AnyAsync(u => u.PhoneNumber == phoneNumber, cancellationToken);
    }
}


