using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;
using MayMessenger.Infrastructure.Utils;

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
    
    public async Task<int> UpdatePhoneNumberHashesAsync(CancellationToken cancellationToken = default)
    {
        var users = await _dbSet.ToListAsync(cancellationToken);
        var updatedCount = 0;
        
        foreach (var user in users)
        {
            var normalized = PhoneNumberHelper.Normalize(user.PhoneNumber);
            using var sha256 = SHA256.Create();
            var bytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(normalized));
            var newHash = Convert.ToHexString(bytes).ToLowerInvariant();
            
            if (user.PhoneNumberHash != newHash)
            {
                user.PhoneNumberHash = newHash;
                updatedCount++;
            }
        }
        
        if (updatedCount > 0)
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        
        return updatedCount;
    }
    
    public async Task<IEnumerable<User>> GetOnlineUsersAsync(CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(u => u.IsOnline)
            .ToListAsync(cancellationToken);
    }
    
    public async Task<List<User>> GetStaleOnlineUsersAsync(DateTime cutoffTime, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(u => u.IsOnline && u.LastHeartbeatAt != null && u.LastHeartbeatAt < cutoffTime)
            .ToListAsync(cancellationToken);
    }
}


