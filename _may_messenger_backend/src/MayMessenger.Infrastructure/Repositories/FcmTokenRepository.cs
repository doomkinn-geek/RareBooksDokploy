using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class FcmTokenRepository : IFcmTokenRepository
{
    private readonly AppDbContext _context;

    public FcmTokenRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<FcmToken?> GetByTokenAsync(string token)
    {
        return await _context.FcmTokens
            .FirstOrDefaultAsync(t => t.Token == token && t.IsActive);
    }

    public async Task<List<FcmToken>> GetActiveTokensForUserAsync(Guid userId)
    {
        return await _context.FcmTokens
            .Where(t => t.UserId == userId && t.IsActive)
            .ToListAsync();
    }

    public async Task RegisterOrUpdateAsync(Guid userId, string token, string deviceInfo)
    {
        var existingToken = await _context.FcmTokens
            .FirstOrDefaultAsync(t => t.UserId == userId && t.Token == token);

        if (existingToken != null)
        {
            existingToken.DeviceInfo = deviceInfo;
            existingToken.LastUsedAt = DateTime.UtcNow;
            existingToken.IsActive = true;
            _context.FcmTokens.Update(existingToken);
        }
        else
        {
            var newToken = new FcmToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                DeviceInfo = deviceInfo,
                RegisteredAt = DateTime.UtcNow,
                LastUsedAt = DateTime.UtcNow,
                IsActive = true
            };
            await _context.FcmTokens.AddAsync(newToken);
        }

        await _context.SaveChangesAsync();
    }

    public async Task DeactivateTokenAsync(string token)
    {
        var fcmToken = await _context.FcmTokens
            .FirstOrDefaultAsync(t => t.Token == token);

        if (fcmToken != null)
        {
            fcmToken.IsActive = false;
            _context.FcmTokens.Update(fcmToken);
            await _context.SaveChangesAsync();
        }
    }

    public async Task DeactivateUserTokensAsync(Guid userId)
    {
        var tokens = await _context.FcmTokens
            .Where(t => t.UserId == userId && t.IsActive)
            .ToListAsync();

        foreach (var token in tokens)
        {
            token.IsActive = false;
        }

        _context.FcmTokens.UpdateRange(tokens);
        await _context.SaveChangesAsync();
    }
}
