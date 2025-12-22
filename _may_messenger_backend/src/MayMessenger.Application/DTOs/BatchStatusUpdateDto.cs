using MayMessenger.Domain.Enums;

namespace MayMessenger.Application.DTOs;

/// <summary>
/// DTO для batch обновления статусов сообщений
/// </summary>
public class BatchStatusUpdateDto
{
    /// <summary>
    /// Список ID сообщений для обновления
    /// </summary>
    public List<Guid> MessageIds { get; set; } = new();
    
    /// <summary>
    /// Новый статус для всех сообщений
    /// </summary>
    public MessageStatus Status { get; set; }
}

