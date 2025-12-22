using System.Data;

namespace MayMessenger.Domain.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IUserRepository Users { get; }
    IChatRepository Chats { get; }
    IMessageRepository Messages { get; }
    IMessageStatusEventRepository MessageStatusEvents { get; }
    IInviteLinkRepository InviteLinks { get; }
    IFcmTokenRepository FcmTokens { get; }
    IContactRepository Contacts { get; }
    IDeliveryReceiptRepository DeliveryReceipts { get; }
    IPendingAckRepository PendingAcks { get; }
    
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Begin a database transaction with specified isolation level
    /// Returns IDisposable transaction that must be committed or rolled back
    /// </summary>
    Task<ITransaction> BeginTransactionAsync(IsolationLevel isolationLevel = IsolationLevel.ReadCommitted, CancellationToken cancellationToken = default);
}

/// <summary>
/// Abstraction for database transaction to avoid EF Core dependency in Domain layer
/// </summary>
public interface ITransaction : IAsyncDisposable
{
    Task CommitAsync(CancellationToken cancellationToken = default);
    Task RollbackAsync(CancellationToken cancellationToken = default);
}


