using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

public class ChatDto
{
    public Guid Id { get; set; }
    public ChatType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Avatar { get; set; }
    public MessageDto? LastMessage { get; set; }
    public int UnreadCount { get; set; }
    public DateTime CreatedAt { get; set; }
}


