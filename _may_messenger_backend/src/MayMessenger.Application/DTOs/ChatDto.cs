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
    
    // For private chats: userId of the other participant
    // Used by mobile app to map to local contact name
    public Guid? OtherParticipantId { get; set; }
    
    // Online status for private chats (other participant)
    public bool? OtherParticipantIsOnline { get; set; }
    public DateTime? OtherParticipantLastSeenAt { get; set; }
}


