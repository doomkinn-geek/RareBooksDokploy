using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Interfaces;

public interface IMessageStatusEventRepository : IRepository<MessageStatusEvent>
{
    /// <summary>
    /// Get all status events for a specific message, ordered by timestamp
    /// </summary>
    Task<IEnumerable<MessageStatusEvent>> GetMessageEventsAsync(Guid messageId, CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Get the latest status event for a message
    /// </summary>
    Task<MessageStatusEvent?> GetLatestEventAsync(Guid messageId, CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Get status events for multiple messages (for batch status calculation)
    /// </summary>
    Task<IDictionary<Guid, IEnumerable<MessageStatusEvent>>> GetMessagesEventsAsync(IEnumerable<Guid> messageIds, CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Create a new status event and update the message status accordingly
    /// </summary>
    Task<MessageStatusEvent> CreateEventAsync(Guid messageId, MessageStatus status, Guid? userId, string source, CancellationToken cancellationToken = default);
    
    /// <summary>
    /// Calculate the aggregate status for a message based on all events
    /// For groups: returns the minimum status among all participants
    /// </summary>
    Task<MessageStatus> CalculateAggregateStatusAsync(Guid messageId, CancellationToken cancellationToken = default);
}

