using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

public class MessageSearchResultDto
{
    public Guid MessageId { get; set; }
    public Guid ChatId { get; set; }
    public string ChatTitle { get; set; } = string.Empty;
    public string MessageContent { get; set; } = string.Empty;
    public string SenderName { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

