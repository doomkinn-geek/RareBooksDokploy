using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class UnitOfWork : IUnitOfWork
{
    private readonly AppDbContext _context;
    
    public IUserRepository Users { get; }
    public IChatRepository Chats { get; }
    public IMessageRepository Messages { get; }
    public IInviteLinkRepository InviteLinks { get; }
    public IFcmTokenRepository FcmTokens { get; }
    
    public UnitOfWork(
        AppDbContext context,
        IUserRepository userRepository,
        IChatRepository chatRepository,
        IMessageRepository messageRepository,
        IInviteLinkRepository inviteLinkRepository,
        IFcmTokenRepository fcmTokenRepository)
    {
        _context = context;
        Users = userRepository;
        Chats = chatRepository;
        Messages = messageRepository;
        InviteLinks = inviteLinkRepository;
        FcmTokens = fcmTokenRepository;
    }
    
    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
    
    public void Dispose()
    {
        _context.Dispose();
    }
}


