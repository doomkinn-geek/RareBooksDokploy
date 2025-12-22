namespace MayMessenger.Application.DTOs;

/// <summary>
/// DTO для статуса пользователя (онлайн/офлайн)
/// </summary>
public class UserStatusDto
{
    /// <summary>
    /// ID пользователя
    /// </summary>
    public Guid UserId { get; set; }
    
    /// <summary>
    /// Пользователь онлайн
    /// </summary>
    public bool IsOnline { get; set; }
    
    /// <summary>
    /// Время последнего онлайна
    /// </summary>
    public DateTime? LastSeenAt { get; set; }
}

