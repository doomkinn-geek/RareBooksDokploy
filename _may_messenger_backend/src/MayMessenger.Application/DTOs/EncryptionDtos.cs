using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

/// <summary>
/// DTO for updating user's public key
/// </summary>
public class UpdatePublicKeyDto
{
    /// <summary>
    /// X25519 public key in Base64 format (32 bytes)
    /// </summary>
    public string PublicKey { get; set; } = string.Empty;
}

/// <summary>
/// DTO for returning user's public key
/// </summary>
public class PublicKeyDto
{
    public Guid UserId { get; set; }
    
    /// <summary>
    /// X25519 public key in Base64 format, null if not set
    /// </summary>
    public string? PublicKey { get; set; }
}

/// <summary>
/// DTO for updating encrypted chat key for a participant
/// </summary>
public class UpdateChatKeyDto
{
    public Guid ChatId { get; set; }
    
    /// <summary>
    /// Encrypted chat key in Base64 format
    /// For private chats: not needed (derived from ECDH)
    /// For group chats: AES key encrypted with user's public key
    /// </summary>
    public string EncryptedChatKey { get; set; } = string.Empty;
}

/// <summary>
/// DTO for distributing encrypted group key to participants
/// </summary>
public class DistributeGroupKeyDto
{
    public Guid ChatId { get; set; }
    
    /// <summary>
    /// List of participant keys - each entry contains userId and their encrypted copy of the group key
    /// </summary>
    public List<ParticipantKeyDto> ParticipantKeys { get; set; } = new();
}

/// <summary>
/// Encrypted key for a specific participant
/// </summary>
public class ParticipantKeyDto
{
    public Guid UserId { get; set; }
    
    /// <summary>
    /// Group AES key encrypted with this user's public key (Base64)
    /// </summary>
    public string EncryptedKey { get; set; } = string.Empty;
}

/// <summary>
/// DTO for returning chat's encryption key info
/// </summary>
public class ChatKeyDto
{
    public Guid ChatId { get; set; }
    
    /// <summary>
    /// Encrypted chat key for the current user (Base64)
    /// null if no key has been distributed yet
    /// </summary>
    public string? EncryptedChatKey { get; set; }
    
    public ChatType ChatType { get; set; }
}

