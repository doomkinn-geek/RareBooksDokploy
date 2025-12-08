namespace MayMessenger.Application.DTOs;

public class CreateChatDto
{
    public string Title { get; set; } = string.Empty;
    public List<Guid> ParticipantIds { get; set; } = new();
}


