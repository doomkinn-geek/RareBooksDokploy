using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

/// <summary>
/// DTO for returning message status information
/// Used by polling fallback when SignalR misses updates
/// </summary>
public class MessageStatusDto
{
    public Guid MessageId { get; set; }
    public MessageStatus Status { get; set; }
    public DateTime? DeliveredAt { get; set; }
    public DateTime? ReadAt { get; set; }
    public DateTime? PlayedAt { get; set; }
}

