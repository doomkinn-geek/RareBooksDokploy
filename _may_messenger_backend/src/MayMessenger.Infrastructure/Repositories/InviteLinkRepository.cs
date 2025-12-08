using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class InviteLinkRepository : Repository<InviteLink>, IInviteLinkRepository
{
    public InviteLinkRepository(AppDbContext context) : base(context)
    {
    }
    
    public async Task<InviteLink?> GetByCodeAsync(string code, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .FirstOrDefaultAsync(i => i.Code == code, cancellationToken);
    }
    
    public async Task<bool> ValidateInviteCodeAsync(string code, CancellationToken cancellationToken = default)
    {
        var invite = await GetByCodeAsync(code, cancellationToken);
        
        if (invite == null || !invite.IsActive)
            return false;
            
        if (invite.ExpiresAt.HasValue && invite.ExpiresAt.Value < DateTime.UtcNow)
            return false;
            
        if (invite.UsesLeft.HasValue && invite.UsesLeft.Value <= 0)
            return false;
            
        return true;
    }
}


