namespace MayMessenger.Domain.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IUserRepository Users { get; }
    IChatRepository Chats { get; }
    IMessageRepository Messages { get; }
    IInviteLinkRepository InviteLinks { get; }
    IFcmTokenRepository FcmTokens { get; }
    IContactRepository Contacts { get; }
    IDeliveryReceiptRepository DeliveryReceipts { get; }
    
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}


