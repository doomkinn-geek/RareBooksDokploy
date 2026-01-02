using Microsoft.EntityFrameworkCore;
using Npgsql;
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
        // Count messages that are not read or played (played implies read for audio messages)
        return await _dbSet
            .Where(m => m.ChatId == chatId && 
                       m.SenderId != userId && 
                       m.Status != MessageStatus.Read &&
                       m.Status != MessageStatus.Played)
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
    
    public async Task<IEnumerable<Message>> GetOldMediaMessagesAsync(DateTime cutoffDate, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(m => (m.Type == MessageType.Audio || m.Type == MessageType.Image) && 
                       m.CreatedAt < cutoffDate && 
                       !string.IsNullOrEmpty(m.FilePath))
            .ToListAsync(cancellationToken);
    }
    
    public async Task<IEnumerable<Message>> GetMessagesAfterTimestampAsync(Guid chatId, DateTime since, int take, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Include(m => m.Sender)
            .Where(m => m.ChatId == chatId && 
                       (m.CreatedAt > since || m.UpdatedAt > since))
            .OrderBy(m => m.CreatedAt) // Ascending для incremental sync (старые первыми)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
    
    public async Task<IEnumerable<Message>> GetChatMessagesWithCursorAsync(Guid chatId, Guid? cursor, int take, CancellationToken cancellationToken = default)
    {
        var query = _dbSet
            .Include(m => m.Sender)
            .Where(m => m.ChatId == chatId);
        
        // If cursor is provided, get messages older than the cursor message
        if (cursor.HasValue)
        {
            // Find the cursor message to get its creation date
            var cursorMessage = await _dbSet
                .Where(m => m.Id == cursor.Value)
                .Select(m => new { m.CreatedAt })
                .FirstOrDefaultAsync(cancellationToken);
            
            if (cursorMessage != null)
            {
                // Get messages older than cursor (for loading history)
                query = query.Where(m => m.CreatedAt < cursorMessage.CreatedAt);
            }
        }
        
        // Order by descending (newest first) and take N messages
        return await query
            .OrderByDescending(m => m.CreatedAt)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
    
    public async Task<Message?> GetByClientMessageIdAsync(string clientMessageId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrEmpty(clientMessageId))
            return null;
            
        return await _dbSet
            .Include(m => m.Sender)
            .FirstOrDefaultAsync(m => m.ClientMessageId == clientMessageId, cancellationToken);
    }
    
    public async Task<IEnumerable<Message>> SearchMessagesAsync(IEnumerable<Guid> chatIds, string query, int take, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(query) || !chatIds.Any())
        {
            return Enumerable.Empty<Message>();
        }
        
        // Use PostgreSQL full-text search with Russian language support
        // This leverages the GIN index created in migration
        var chatIdsList = chatIds.ToList();
        
        return await _dbSet
            .Include(m => m.Sender)
            .Where(m => chatIdsList.Contains(m.ChatId) && 
                       m.Type == MessageType.Text &&
                       m.Content != null &&
                       EF.Functions.ToTsVector("russian", m.Content).Matches(EF.Functions.PlainToTsQuery("russian", query)))
            .OrderByDescending(m => m.CreatedAt)
            .Take(take)
            .ToListAsync(cancellationToken);
    }
}


