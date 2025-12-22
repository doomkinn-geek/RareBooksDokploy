using System.Data;
using Microsoft.EntityFrameworkCore.Storage;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class UnitOfWork : IUnitOfWork
{
    private readonly AppDbContext _context;
    
    public IUserRepository Users { get; }
    public IChatRepository Chats { get; }
    public IMessageRepository Messages { get; }
    public IMessageStatusEventRepository MessageStatusEvents { get; }
    public IInviteLinkRepository InviteLinks { get; }
    public IFcmTokenRepository FcmTokens { get; }
    public IContactRepository Contacts { get; }
    public IDeliveryReceiptRepository DeliveryReceipts { get; }
    public IPendingAckRepository PendingAcks { get; }
    
    public UnitOfWork(
        AppDbContext context,
        IUserRepository userRepository,
        IChatRepository chatRepository,
        IMessageRepository messageRepository,
        IMessageStatusEventRepository messageStatusEventRepository,
        IInviteLinkRepository inviteLinkRepository,
        IFcmTokenRepository fcmTokenRepository,
        IContactRepository contactRepository,
        IDeliveryReceiptRepository deliveryReceiptRepository,
        IPendingAckRepository pendingAckRepository)
    {
        _context = context;
        Users = userRepository;
        Chats = chatRepository;
        Messages = messageRepository;
        MessageStatusEvents = messageStatusEventRepository;
        InviteLinks = inviteLinkRepository;
        FcmTokens = fcmTokenRepository;
        Contacts = contactRepository;
        DeliveryReceipts = deliveryReceiptRepository;
        PendingAcks = pendingAckRepository;
    }
    
    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
    
    public async Task<ITransaction> BeginTransactionAsync(IsolationLevel isolationLevel = IsolationLevel.ReadCommitted, CancellationToken cancellationToken = default)
    {
        var efTransaction = await _context.Database.BeginTransactionAsync(cancellationToken);
        // Note: EF Core's BeginTransactionAsync doesn't directly support IsolationLevel parameter
        // The isolation level should be set via connection string or database configuration
        return new TransactionWrapper(efTransaction);
    }
    
    public void Dispose()
    {
        _context.Dispose();
    }
}

/// <summary>
/// Wrapper for EF Core transaction to implement domain interface
/// </summary>
internal class TransactionWrapper : ITransaction
{
    private readonly IDbContextTransaction _efTransaction;

    public TransactionWrapper(IDbContextTransaction efTransaction)
    {
        _efTransaction = efTransaction;
    }

    public async Task CommitAsync(CancellationToken cancellationToken = default)
    {
        await _efTransaction.CommitAsync(cancellationToken);
    }

    public async Task RollbackAsync(CancellationToken cancellationToken = default)
    {
        await _efTransaction.RollbackAsync(cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        await _efTransaction.DisposeAsync();
    }
}


