using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IChatRepository : IRepository<Chat>
{
    Task<IEnumerable<Chat>> GetUserChatsAsync(Guid userId, CancellationToken cancellationToken = default);
    Task<Chat?> GetPrivateChatAsync(Guid user1Id, Guid user2Id, CancellationToken cancellationToken = default);
}


