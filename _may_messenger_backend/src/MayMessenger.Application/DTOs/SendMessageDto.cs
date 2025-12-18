using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

public class SendMessageDto
{
    public Guid ChatId { get; set; }
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public string? ClientMessageId { get; set; }
}


