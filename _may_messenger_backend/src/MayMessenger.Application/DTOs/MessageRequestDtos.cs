namespace MayMessenger.Application.DTOs;

/// <summary>
/// Request DTO for editing a message
/// </summary>
public class EditMessageRequest
{
    public string Content { get; set; } = string.Empty;
}

/// <summary>
/// Request DTO for forwarding a message
/// </summary>
public class ForwardMessageRequest
{
    public Guid OriginalMessageId { get; set; }
    public Guid TargetChatId { get; set; }
}

/// <summary>
/// Request DTO for sending a message with reply
/// </summary>
public class SendMessageWithReplyRequest
{
    public Guid ChatId { get; set; }
    public string Content { get; set; } = string.Empty;
    public Guid? ReplyToMessageId { get; set; }
    public string? ClientMessageId { get; set; }
}

