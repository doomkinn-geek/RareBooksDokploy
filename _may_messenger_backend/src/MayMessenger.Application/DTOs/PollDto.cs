namespace MayMessenger.Application.DTOs;

/// <summary>
/// DTO for displaying poll data
/// </summary>
public class PollDto
{
    public Guid Id { get; set; }
    public string Question { get; set; } = string.Empty;
    public bool AllowMultipleAnswers { get; set; }
    public bool IsAnonymous { get; set; }
    public bool IsClosed { get; set; }
    public DateTime? ClosesAt { get; set; }
    public int TotalVoters { get; set; }
    public List<PollOptionDto> Options { get; set; } = new();
    
    /// <summary>
    /// IDs of options that current user voted for
    /// </summary>
    public List<Guid> MyVotes { get; set; } = new();
}

/// <summary>
/// DTO for poll option
/// </summary>
public class PollOptionDto
{
    public Guid Id { get; set; }
    public string Text { get; set; } = string.Empty;
    public int Order { get; set; }
    public int VoteCount { get; set; }
    
    /// <summary>
    /// Percentage of total voters (0-100)
    /// </summary>
    public int Percentage { get; set; }
    
    /// <summary>
    /// Users who voted for this option (only if not anonymous)
    /// </summary>
    public List<VoterDto>? Voters { get; set; }
}

/// <summary>
/// DTO for voter info
/// </summary>
public class VoterDto
{
    public Guid UserId { get; set; }
    public string DisplayName { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
}

/// <summary>
/// DTO for creating a new poll
/// </summary>
public class CreatePollDto
{
    public Guid ChatId { get; set; }
    public string Question { get; set; } = string.Empty;
    public List<string> Options { get; set; } = new();
    public bool AllowMultipleAnswers { get; set; } = false;
    public bool IsAnonymous { get; set; } = false;
    
    /// <summary>
    /// Optional: Minutes until poll automatically closes
    /// </summary>
    public int? ClosesInMinutes { get; set; }
}

/// <summary>
/// DTO for voting on a poll
/// </summary>
public class VotePollDto
{
    public Guid PollId { get; set; }
    
    /// <summary>
    /// IDs of options to vote for (can be multiple if AllowMultipleAnswers)
    /// </summary>
    public List<Guid> OptionIds { get; set; } = new();
}

/// <summary>
/// DTO for retracting a vote
/// </summary>
public class RetractVoteDto
{
    public Guid PollId { get; set; }
    public List<Guid> OptionIds { get; set; } = new();
}

