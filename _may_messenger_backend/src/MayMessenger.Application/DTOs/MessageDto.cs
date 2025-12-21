using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

public class MessageDto
{
    public Guid Id { get; set; }
    public Guid ChatId { get; set; }
    public Guid SenderId { get; set; }
    public string SenderName { get; set; } = string.Empty;
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public string? FilePath { get; set; }
    public MessageStatus Status { get; set; }
    public DateTime CreatedAt { get; set; }
    public string? ClientMessageId { get; set; } // For deduplication on client
}


