using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class ChatRepository : Repository<Chat>, IChatRepository
{
    public ChatRepository(AppDbContext context) : base(context)
    {
    }
    
    // Override GetByIdAsync to include Participants
    public override async Task<Chat?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Include(c => c.Participants)
                .ThenInclude(p => p.User)
            .FirstOrDefaultAsync(c => c.Id == id, cancellationToken);
    }
    
    public async Task<IEnumerable<Chat>> GetUserChatsAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Include(c => c.Participants)
                .ThenInclude(p => p.User)
            .Include(c => c.Messages.OrderByDescending(m => m.CreatedAt).Take(1))
            .Where(c => c.Participants.Any(p => p.UserId == userId))
            .OrderByDescending(c => c.Messages.Max(m => (DateTime?)m.CreatedAt) ?? c.CreatedAt)
            .ToListAsync(cancellationToken);
    }
    
    public async Task<Chat?> GetPrivateChatAsync(Guid user1Id, Guid user2Id, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Include(c => c.Participants)
            .Where(c => c.Type == ChatType.Private &&
                       c.Participants.Any(p => p.UserId == user1Id) &&
                       c.Participants.Any(p => p.UserId == user2Id))
            .FirstOrDefaultAsync(cancellationToken);
    }
}


