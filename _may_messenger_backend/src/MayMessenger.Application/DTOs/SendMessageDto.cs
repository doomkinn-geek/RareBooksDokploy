using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

public class SendMessageDto
{
    public Guid ChatId { get; set; }
    public MessageType Type { get; set; }
    public string? Content { get; set; }
    public string? ClientMessageId { get; set; }
    public Guid? ReplyToMessageId { get; set; }
    
    // End-to-end encryption - indicates if Content is encrypted
    public bool IsEncrypted { get; set; } = false;
}


