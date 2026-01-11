using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class DeliveryReceiptRepository : Repository<DeliveryReceipt>, IDeliveryReceiptRepository
{
    public DeliveryReceiptRepository(AppDbContext context) : base(context)
    {
    }

    public async Task<DeliveryReceipt?> GetByMessageAndUserAsync(Guid messageId, Guid userId, CancellationToken cancellationToken = default)
    {
        return await _context.DeliveryReceipts
            .FirstOrDefaultAsync(r => r.MessageId == messageId && r.UserId == userId, cancellationToken);
    }

    public async Task<int> GetReadCountAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return await _context.DeliveryReceipts
            .Where(r => r.MessageId == messageId && r.ReadAt != null)
            .CountAsync(cancellationToken);
    }

    public async Task<int> GetDeliveredCountAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return await _context.DeliveryReceipts
            .Where(r => r.MessageId == messageId && r.DeliveredAt != null)
            .CountAsync(cancellationToken);
    }

    public async Task<List<DeliveryReceipt>> GetByMessageIdAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return await _context.DeliveryReceipts
            .Where(r => r.MessageId == messageId)
            .Include(r => r.User)
            .ToListAsync(cancellationToken);
    }
    
    public async Task<List<DeliveryReceipt>> GetReceiptsForMessageAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return await _context.DeliveryReceipts
            .Where(r => r.MessageId == messageId)
            .Include(r => r.User)
            .OrderByDescending(r => r.ReadAt ?? r.DeliveredAt ?? DateTime.MinValue)
            .ToListAsync(cancellationToken);
    }
}
