using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class PendingAckRepository : IPendingAckRepository
{
    private readonly AppDbContext _context;

    public PendingAckRepository(AppDbContext context)
    {
        _context = context;
    }

    public async Task<PendingAck?> GetByIdAsync(Guid id)
    {
        return await _context.PendingAcks
            .Include(pa => pa.Message)
            .Include(pa => pa.RecipientUser)
            .FirstOrDefaultAsync(pa => pa.Id == id);
    }

    public async Task<IEnumerable<PendingAck>> GetAllAsync()
    {
        return await _context.PendingAcks
            .Include(pa => pa.Message)
            .Include(pa => pa.RecipientUser)
            .ToListAsync();
    }

    /// <summary>
    /// Get pending acks that need to be retried (created before olderThan and have retries left)
    /// </summary>
    public async Task<IEnumerable<PendingAck>> GetPendingAcksAsync(DateTime olderThan, int maxRetries = 3)
    {
        return await _context.PendingAcks
            .Include(pa => pa.Message)
            .Include(pa => pa.RecipientUser)
            .Where(pa => pa.CreatedAt < olderThan && pa.RetryCount < maxRetries)
            .OrderBy(pa => pa.CreatedAt)
            .Take(100) // Limit batch size
            .ToListAsync();
    }
    
    /// <summary>
    /// Get all pending acks for a specific user (for delivery when user reconnects)
    /// </summary>
    public async Task<IEnumerable<PendingAck>> GetPendingForUserAsync(Guid userId, int maxRetries = 5)
    {
        return await _context.PendingAcks
            .Include(pa => pa.Message)
                .ThenInclude(m => m.Sender)
            .Include(pa => pa.Message)
                .ThenInclude(m => m.ReplyToMessage)
                    .ThenInclude(r => r != null ? r.Sender : null)
            .Where(pa => pa.RecipientUserId == userId && pa.RetryCount < maxRetries)
            .OrderBy(pa => pa.CreatedAt)
            .Take(100) // Limit batch size for performance
            .ToListAsync();
    }

    public async Task<PendingAck?> GetPendingAckAsync(Guid messageId, Guid recipientUserId, AckType type)
    {
        return await _context.PendingAcks
            .FirstOrDefaultAsync(pa => 
                pa.MessageId == messageId && 
                pa.RecipientUserId == recipientUserId && 
                pa.Type == type);
    }

    public async Task AddAsync(PendingAck pendingAck)
    {
        await _context.PendingAcks.AddAsync(pendingAck);
        await _context.SaveChangesAsync();
    }

    public async Task UpdateAsync(PendingAck pendingAck)
    {
        _context.PendingAcks.Update(pendingAck);
        await _context.SaveChangesAsync();
    }

    public async Task DeleteAsync(Guid id)
    {
        var pendingAck = await _context.PendingAcks.FindAsync(id);
        if (pendingAck != null)
        {
            _context.PendingAcks.Remove(pendingAck);
            await _context.SaveChangesAsync();
        }
    }

    public async Task DeleteByMessageAndRecipientAsync(Guid messageId, Guid recipientUserId, AckType type)
    {
        var pendingAck = await GetPendingAckAsync(messageId, recipientUserId, type);
        if (pendingAck != null)
        {
            _context.PendingAcks.Remove(pendingAck);
            await _context.SaveChangesAsync();
        }
    }

    /// <summary>
    /// Clean up old pending acks that have exceeded max retries or are too old
    /// </summary>
    public async Task CleanupOldAcksAsync(DateTime olderThan)
    {
        var oldAcks = await _context.PendingAcks
            .Where(pa => pa.CreatedAt < olderThan)
            .ToListAsync();

        if (oldAcks.Any())
        {
            _context.PendingAcks.RemoveRange(oldAcks);
            await _context.SaveChangesAsync();
        }
    }
}

