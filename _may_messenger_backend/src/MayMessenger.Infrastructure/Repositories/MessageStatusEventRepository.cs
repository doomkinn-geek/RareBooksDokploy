using Microsoft.EntityFrameworkCore;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.Infrastructure.Repositories;

public class MessageStatusEventRepository : Repository<MessageStatusEvent>, IMessageStatusEventRepository
{
    public MessageStatusEventRepository(AppDbContext context) : base(context)
    {
    }
    
    public async Task<IEnumerable<MessageStatusEvent>> GetMessageEventsAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(e => e.MessageId == messageId)
            .OrderBy(e => e.Timestamp)
            .ToListAsync(cancellationToken);
    }
    
    public async Task<MessageStatusEvent?> GetLatestEventAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        return await _dbSet
            .Where(e => e.MessageId == messageId)
            .OrderByDescending(e => e.Timestamp)
            .FirstOrDefaultAsync(cancellationToken);
    }
    
    public async Task<IDictionary<Guid, IEnumerable<MessageStatusEvent>>> GetMessagesEventsAsync(IEnumerable<Guid> messageIds, CancellationToken cancellationToken = default)
    {
        var events = await _dbSet
            .Where(e => messageIds.Contains(e.MessageId))
            .OrderBy(e => e.Timestamp)
            .ToListAsync(cancellationToken);
            
        return events
            .GroupBy(e => e.MessageId)
            .ToDictionary(g => g.Key, g => g.AsEnumerable());
    }
    
    public async Task<MessageStatusEvent> CreateEventAsync(Guid messageId, MessageStatus status, Guid? userId, string source, CancellationToken cancellationToken = default)
    {
        var statusEvent = new MessageStatusEvent
        {
            MessageId = messageId,
            Status = status,
            UserId = userId,
            Source = source,
            Timestamp = DateTime.UtcNow
        };
        
        await _dbSet.AddAsync(statusEvent, cancellationToken);
        return statusEvent;
    }
    
    public async Task<MessageStatus> CalculateAggregateStatusAsync(Guid messageId, CancellationToken cancellationToken = default)
    {
        // Get the message with its chat participants
        var message = await _context.Messages
            .Include(m => m.Chat)
            .ThenInclude(c => c.Participants)
            .FirstOrDefaultAsync(m => m.Id == messageId, cancellationToken);
            
        if (message == null)
        {
            throw new InvalidOperationException($"Message {messageId} not found");
        }
        
        // Get all status events for this message
        var events = await GetMessageEventsAsync(messageId, cancellationToken);
        
        if (!events.Any())
        {
            // No events yet, return default status
            return MessageStatus.Sending;
        }
        
        // For private chats (2 participants) or messages from sender only
        if (message.Chat.Type == ChatType.Private)
        {
            // Return the latest status
            var latestEvent = events.OrderByDescending(e => e.Timestamp).First();
            return latestEvent.Status;
        }
        
        // For group chats, calculate minimum status among all participants (except sender)
        var participantIds = message.Chat.Participants
            .Where(p => p.UserId != message.SenderId)
            .Select(p => p.UserId)
            .ToList();
            
        if (!participantIds.Any())
        {
            // No other participants, return latest status
            var latestEvent = events.OrderByDescending(e => e.Timestamp).First();
            return latestEvent.Status;
        }
        
        // Get latest status for each participant
        var participantStatuses = new Dictionary<Guid, MessageStatus>();
        
        foreach (var participantId in participantIds)
        {
            var participantEvents = events
                .Where(e => e.UserId == participantId)
                .OrderByDescending(e => e.Timestamp);
                
            if (participantEvents.Any())
            {
                participantStatuses[participantId] = participantEvents.First().Status;
            }
            else
            {
                // Participant hasn't received the message yet
                participantStatuses[participantId] = MessageStatus.Sent;
            }
        }
        
        // Return minimum status (Sent < Delivered < Read < Played)
        return participantStatuses.Values.Min();
    }
}

