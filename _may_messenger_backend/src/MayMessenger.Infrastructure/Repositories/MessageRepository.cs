using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class MessageRepository : Repository<Message>, IMessageRepository
{
    public MessageRepository(AppDbContext context) : base(context)
    {
    }
    
    public async Task<IEnumerable<Message>> GetChatMessagesAsync(Guid chatId, int skip, int take, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Include(m => m.Sender)
            .Where(m => m.ChatId == chatId)
            .OrderByDescending(m => m.CreatedAt)
            .Skip(skip)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
    
    public async Task<Message?> GetLastMessageAsync(Guid chatId, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(m => m.ChatId == chatId)
            .OrderByDescending(m => m.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }
    
    public async Task<int> GetUnreadCountAsync(Guid chatId, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(m => m.ChatId == chatId && 
                       m.SenderId != userId && 
                       m.Status != MessageStatus.Read)
            .CountAsync(cancellationToken);
    }
    
    public async Task<IEnumerable<Message>> GetOldAudioMessagesAsync(DateTime cutoffDate, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(m => m.Type == MessageType.Audio && 
                       m.CreatedAt < cutoffDate && 
                       !string.IsNullOrEmpty(m.FilePath))
            .ToListAsync(cancellationToken);
    }
}


