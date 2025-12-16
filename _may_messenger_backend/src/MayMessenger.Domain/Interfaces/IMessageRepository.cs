using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IMessageRepository : IRepository<Message>
{
    Task<IEnumerable<Message>> GetChatMessagesAsync(Guid chatId, int skip, int take, CancellationToken cancellationToken = default);
    Task<Message?> GetLastMessageAsync(Guid chatId, CancellationToken cancellationToken = default);
    Task<int> GetUnreadCountAsync(Guid chatId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<Message>> GetOldAudioMessagesAsync(DateTime cutoffDate, CancellationToken cancellationToken = default);
}


