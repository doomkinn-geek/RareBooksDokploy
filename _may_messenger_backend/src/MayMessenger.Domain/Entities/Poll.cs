namespace MayMessenger.Domain.Entities;

/// <summary>
/// Represents a poll/vote in a group chat
/// </summary>
public class Poll : BaseEntity
{
    public Guid MessageId { get; set; }
    public string Question { get; set; } = string.Empty;
    
    /// <summary>
    /// If true, users can select multiple options
    /// </summary>
    public bool AllowMultipleAnswers { get; set; } = false;
    
    /// <summary>
    /// If true, results are hidden until poll is closed
    /// </summary>
    public bool IsAnonymous { get; set; } = false;
    
    /// <summary>
    /// If true, poll is closed and no more votes are accepted
    /// </summary>
    public bool IsClosed { get; set; } = false;
    
    /// <summary>
    /// Optional: Poll closes automatically after this time
    /// </summary>
    public DateTime? ClosesAt { get; set; }
    
    /// <summary>
    /// Total number of voters (users who voted at least once)
    /// </summary>
    public int TotalVoters { get; set; } = 0;
    
    // Navigation properties
    public Message Message { get; set; } = null!;
    public ICollection<PollOption> Options { get; set; } = new List<PollOption>();
}

/// <summary>
/// Represents an option/answer in a poll
/// </summary>
public class PollOption : BaseEntity
{
    public Guid PollId { get; set; }
    public string Text { get; set; } = string.Empty;
    
    /// <summary>
    /// Order of the option in the poll
    /// </summary>
    public int Order { get; set; }
    
    /// <summary>
    /// Number of votes for this option
    /// </summary>
    public int VoteCount { get; set; } = 0;
    
    // Navigation properties
    public Poll Poll { get; set; } = null!;
    public ICollection<PollVote> Votes { get; set; } = new List<PollVote>();
}

/// <summary>
/// Represents a vote by a user on a poll option
/// </summary>
public class PollVote : BaseEntity
{
    public Guid PollOptionId { get; set; }
    public Guid UserId { get; set; }
    
    // Navigation properties
    public PollOption PollOption { get; set; } = null!;
    public User User { get; set; } = null!;
}

