using MayMessenger.Domain.Entities;

namespace MayMessenger.Domain.Interfaces;

public interface IMessageRepository : IRepository<Message>
{
    Task<IEnumerable<Message>> GetChatMessagesAsync(Guid chatId, int skip, int take, CancellationToken cancellationToken = default);
    Task<Message?> GetLastMessageAsync(Guid chatId, CancellationToken cancellationToken = default);
    Task<int> GetUnreadCountAsync(Guid chatId, Guid userId, CancellationToken cancellationToken = default);
    Task<IEnumerable<Message>> GetOldAudioMessagesAsync(DateTime cutoffDate, CancellationToken cancellationToken = default);
    Task<IEnumerable<Message>> GetOldMediaMessagesAsync(DateTime cutoffDate, CancellationToken cancellationToken = default);
    Task<IEnumerable<Message>> GetMessagesAfterTimestampAsync(Guid chatId, DateTime since, int take, CancellationToken cancellationToken = default);
    Task<IEnumerable<Message>> GetChatMessagesWithCursorAsync(Guid chatId, Guid? cursor, int take, CancellationToken cancellationToken = default);
    Task<Message?> GetByClientMessageIdAsync(string clientMessageId, CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Full-text search messages in specified chats using PostgreSQL tsvector
    /// </summary>
    Task<IEnumerable<Message>> SearchMessagesAsync(IEnumerable<Guid> chatIds, string query, int take, CancellationToken cancellationToken = default);
}


