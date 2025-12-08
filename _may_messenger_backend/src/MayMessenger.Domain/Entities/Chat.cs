using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Entities;

public class Chat : BaseEntity
{
    public ChatType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Avatar { get; set; }
    
    // Navigation properties
    public ICollection<ChatParticipant> Participants { get; set; } = new List<ChatParticipant>();
    public ICollection<Message> Messages { get; set; } = new List<Message>();
}


