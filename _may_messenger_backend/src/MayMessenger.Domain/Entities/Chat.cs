using MayMessenger.Domain.Enums;

namespace MayMessenger.Domain.Entities;

public class Chat : BaseEntity
{
    public ChatType Type { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Avatar { get; set; }
    
    // End-to-end encryption - Encrypted group key (for group chats)
    // This is the AES-256 key encrypted with creator's public key
    public string? EncryptedGroupKey { get; set; }
    
    // Navigation properties
    public ICollection<ChatParticipant> Participants { get; set; } = new List<ChatParticipant>();
    public ICollection<Message> Messages { get; set; } = new List<Message>();
}


