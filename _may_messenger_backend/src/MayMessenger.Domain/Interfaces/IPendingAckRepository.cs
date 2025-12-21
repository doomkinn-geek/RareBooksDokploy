using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Interfaces;

public interface IPendingAckRepository
{
    Task<PendingAck?> GetByIdAsync(Guid id);
    Task<IEnumerable<PendingAck>> GetAllAsync();
    Task<IEnumerable<PendingAck>> GetPendingAcksAsync(DateTime olderThan, int maxRetries = 3);
    Task<PendingAck?> GetPendingAckAsync(Guid messageId, Guid recipientUserId, AckType type);
    Task AddAsync(PendingAck pendingAck);
    Task UpdateAsync(PendingAck pendingAck);
    Task DeleteAsync(Guid id);
    Task DeleteByMessageAndRecipientAsync(Guid messageId, Guid recipientUserId, AckType type);
    Task CleanupOldAcksAsync(DateTime olderThan);
}

