using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IDeliveryReceiptRepository : IRepository<DeliveryReceipt>
{
    Task<DeliveryReceipt?> GetByMessageAndUserAsync(Guid messageId, Guid userId, CancellationToken cancellationToken = default);
    Task<int> GetReadCountAsync(Guid messageId, CancellationToken cancellationToken = default);
    Task<int> GetDeliveredCountAsync(Guid messageId, CancellationToken cancellationToken = default);
    Task<List<DeliveryReceipt>> GetByMessageIdAsync(Guid messageId, CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Get all delivery receipts for a message with user info loaded
    /// </summary>
    Task<List<DeliveryReceipt>> GetReceiptsForMessageAsync(Guid messageId, CancellationToken cancellationToken = default);
}
