using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Infrastructure.Data;
using AppDbContext = MayMessenger.Infrastructure.Data.AppDbContext;
using MayMessenger.API.Hubs;
using System.Security.Claims;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PollsController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IHubContext<ChatHub> _hubContext;
    private readonly ILogger<PollsController> _logger;

    public PollsController(
        AppDbContext context,
        IHubContext<ChatHub> hubContext,
        ILogger<PollsController> logger)
    {
        _context = context;
        _hubContext = hubContext;
        _logger = logger;
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// <summary>
    /// Create a new poll in a group chat
    /// </summary>
    [HttpPost]
    public async Task<ActionResult<MessageDto>> CreatePoll([FromBody] CreatePollDto dto)
    {
        var userId = GetUserId();

        // Verify user is a member of the chat
        var chat = await _context.Chats
            .Include(c => c.Participants)
            .FirstOrDefaultAsync(c => c.Id == dto.ChatId);

        if (chat == null)
            return NotFound("Chat not found");

        if (chat.Type != ChatType.Group)
            return BadRequest("Polls can only be created in group chats");

        if (!chat.Participants.Any(p => p.UserId == userId))
            return Forbid("You are not a member of this chat");

        if (string.IsNullOrWhiteSpace(dto.Question))
            return BadRequest("Question is required");

        if (dto.Options.Count < 2)
            return BadRequest("At least 2 options are required");

        if (dto.Options.Count > 10)
            return BadRequest("Maximum 10 options allowed");

        var user = await _context.Users.FindAsync(userId);
        if (user == null)
            return NotFound("User not found");

        // Create poll
        var poll = new Poll
        {
            Id = Guid.NewGuid(),
            Question = dto.Question,
            AllowMultipleAnswers = dto.AllowMultipleAnswers,
            IsAnonymous = dto.IsAnonymous,
            IsClosed = false,
            ClosesAt = dto.ClosesInMinutes.HasValue 
                ? DateTime.UtcNow.AddMinutes(dto.ClosesInMinutes.Value) 
                : null,
            CreatedAt = DateTime.UtcNow,
            Options = dto.Options.Select((text, index) => new PollOption
            {
                Id = Guid.NewGuid(),
                Text = text,
                Order = index,
                VoteCount = 0,
                CreatedAt = DateTime.UtcNow,
            }).ToList()
        };

        // Create message with poll
        var message = new Message
        {
            Id = Guid.NewGuid(),
            ChatId = dto.ChatId,
            SenderId = userId,
            Type = MessageType.Poll,
            Content = dto.Question, // Store question in content for search
            Status = MessageStatus.Sent,
            CreatedAt = DateTime.UtcNow,
            PollId = poll.Id,
            Poll = poll
        };

        poll.MessageId = message.Id;

        _context.Messages.Add(message);
        await _context.SaveChangesAsync();

        // Create response DTO
        var messageDto = await CreateMessageDtoWithPoll(message, poll, userId);

        // Notify all chat participants via SignalR
        await _hubContext.Clients.Group(dto.ChatId.ToString())
            .SendAsync("ReceiveMessage", messageDto);

        _logger.LogInformation("Poll created: {PollId} in chat {ChatId} by user {UserId}", 
            poll.Id, dto.ChatId, userId);

        return Ok(messageDto);
    }

    /// <summary>
    /// Vote on a poll
    /// </summary>
    [HttpPost("vote")]
    public async Task<ActionResult<PollDto>> Vote([FromBody] VotePollDto dto)
    {
        var userId = GetUserId();

        var poll = await _context.Set<Poll>()
            .Include(p => p.Options)
                .ThenInclude(o => o.Votes)
            .Include(p => p.Message)
            .FirstOrDefaultAsync(p => p.Id == dto.PollId);

        if (poll == null)
            return NotFound("Poll not found");

        if (poll.IsClosed)
            return BadRequest("Poll is closed");

        if (poll.ClosesAt.HasValue && poll.ClosesAt < DateTime.UtcNow)
        {
            poll.IsClosed = true;
            await _context.SaveChangesAsync();
            return BadRequest("Poll has expired");
        }

        // Verify user is a member of the chat
        var isMember = await _context.ChatParticipants
            .AnyAsync(cp => cp.ChatId == poll.Message.ChatId && cp.UserId == userId);
        
        if (!isMember)
            return Forbid("You are not a member of this chat");

        // Check if multiple answers are allowed
        if (!poll.AllowMultipleAnswers && dto.OptionIds.Count > 1)
            return BadRequest("Only one answer allowed");

        // Validate all option IDs
        var validOptionIds = poll.Options.Select(o => o.Id).ToHashSet();
        if (!dto.OptionIds.All(id => validOptionIds.Contains(id)))
            return BadRequest("Invalid option ID");

        // Get existing votes
        var existingVotes = poll.Options
            .SelectMany(o => o.Votes)
            .Where(v => v.UserId == userId)
            .ToList();

        // Remove old votes
        foreach (var vote in existingVotes)
        {
            var option = poll.Options.First(o => o.Id == vote.PollOptionId);
            option.VoteCount = Math.Max(0, option.VoteCount - 1);
            _context.Set<PollVote>().Remove(vote);
        }

        // Check if user already voted (for TotalVoters count)
        bool wasVoter = existingVotes.Any();

        // Add new votes
        foreach (var optionId in dto.OptionIds)
        {
            var option = poll.Options.First(o => o.Id == optionId);
            option.VoteCount++;
            
            _context.Set<PollVote>().Add(new PollVote
            {
                Id = Guid.NewGuid(),
                PollOptionId = optionId,
                UserId = userId,
                CreatedAt = DateTime.UtcNow
            });
        }

        // Update total voters
        if (!wasVoter && dto.OptionIds.Any())
        {
            poll.TotalVoters++;
        }
        else if (wasVoter && !dto.OptionIds.Any())
        {
            poll.TotalVoters = Math.Max(0, poll.TotalVoters - 1);
        }

        await _context.SaveChangesAsync();

        // Create updated poll DTO
        var pollDto = CreatePollDto(poll, userId);

        // Notify all chat participants about poll update
        await _hubContext.Clients.Group(poll.Message.ChatId.ToString())
            .SendAsync("PollUpdated", new { 
                MessageId = poll.MessageId, 
                Poll = pollDto 
            });

        _logger.LogInformation("User {UserId} voted on poll {PollId}", userId, dto.PollId);

        return Ok(pollDto);
    }

    /// <summary>
    /// Retract votes from a poll
    /// </summary>
    [HttpPost("retract")]
    public async Task<ActionResult<PollDto>> RetractVote([FromBody] RetractVoteDto dto)
    {
        var userId = GetUserId();

        var poll = await _context.Set<Poll>()
            .Include(p => p.Options)
                .ThenInclude(o => o.Votes)
            .Include(p => p.Message)
            .FirstOrDefaultAsync(p => p.Id == dto.PollId);

        if (poll == null)
            return NotFound("Poll not found");

        if (poll.IsClosed)
            return BadRequest("Poll is closed");

        // Find and remove votes
        var votesToRemove = poll.Options
            .SelectMany(o => o.Votes)
            .Where(v => v.UserId == userId && dto.OptionIds.Contains(v.PollOptionId))
            .ToList();

        foreach (var vote in votesToRemove)
        {
            var option = poll.Options.First(o => o.Id == vote.PollOptionId);
            option.VoteCount = Math.Max(0, option.VoteCount - 1);
            _context.Set<PollVote>().Remove(vote);
        }

        // Check if user still has votes
        var remainingVotes = poll.Options
            .SelectMany(o => o.Votes)
            .Any(v => v.UserId == userId && !dto.OptionIds.Contains(v.PollOptionId));

        if (!remainingVotes && votesToRemove.Any())
        {
            poll.TotalVoters = Math.Max(0, poll.TotalVoters - 1);
        }

        await _context.SaveChangesAsync();

        var pollDto = CreatePollDto(poll, userId);

        await _hubContext.Clients.Group(poll.Message.ChatId.ToString())
            .SendAsync("PollUpdated", new { 
                MessageId = poll.MessageId, 
                Poll = pollDto 
            });

        return Ok(pollDto);
    }

    /// <summary>
    /// Close a poll (creator only)
    /// </summary>
    [HttpPost("{pollId}/close")]
    public async Task<ActionResult<PollDto>> ClosePoll(Guid pollId)
    {
        var userId = GetUserId();

        var poll = await _context.Set<Poll>()
            .Include(p => p.Options)
                .ThenInclude(o => o.Votes)
            .Include(p => p.Message)
            .FirstOrDefaultAsync(p => p.Id == pollId);

        if (poll == null)
            return NotFound("Poll not found");

        if (poll.Message.SenderId != userId)
            return Forbid("Only the poll creator can close it");

        poll.IsClosed = true;
        await _context.SaveChangesAsync();

        var pollDto = CreatePollDto(poll, userId);

        await _hubContext.Clients.Group(poll.Message.ChatId.ToString())
            .SendAsync("PollUpdated", new { 
                MessageId = poll.MessageId, 
                Poll = pollDto 
            });

        _logger.LogInformation("Poll {PollId} closed by user {UserId}", pollId, userId);

        return Ok(pollDto);
    }

    /// <summary>
    /// Get poll results/voters (for non-anonymous polls)
    /// </summary>
    [HttpGet("{pollId}/voters")]
    public async Task<ActionResult<List<PollOptionDto>>> GetVoters(Guid pollId)
    {
        var userId = GetUserId();

        var poll = await _context.Set<Poll>()
            .Include(p => p.Options)
                .ThenInclude(o => o.Votes)
                    .ThenInclude(v => v.User)
            .Include(p => p.Message)
            .FirstOrDefaultAsync(p => p.Id == pollId);

        if (poll == null)
            return NotFound("Poll not found");

        // Verify user is a member of the chat
        var isMember = await _context.ChatParticipants
            .AnyAsync(cp => cp.ChatId == poll.Message.ChatId && cp.UserId == userId);
        
        if (!isMember)
            return Forbid("You are not a member of this chat");

        if (poll.IsAnonymous)
            return BadRequest("This poll is anonymous");

        var options = poll.Options.OrderBy(o => o.Order).Select(o => new PollOptionDto
        {
            Id = o.Id,
            Text = o.Text,
            Order = o.Order,
            VoteCount = o.VoteCount,
            Percentage = poll.TotalVoters > 0 
                ? (int)Math.Round(o.VoteCount * 100.0 / poll.TotalVoters) 
                : 0,
            Voters = o.Votes.Select(v => new VoterDto
            {
                UserId = v.UserId,
                DisplayName = v.User.DisplayName,
                AvatarUrl = v.User.Avatar
            }).ToList()
        }).ToList();

        return Ok(options);
    }

    private PollDto CreatePollDto(Poll poll, Guid currentUserId)
    {
        var myVotes = poll.Options
            .SelectMany(o => o.Votes)
            .Where(v => v.UserId == currentUserId)
            .Select(v => v.PollOptionId)
            .ToList();

        return new PollDto
        {
            Id = poll.Id,
            Question = poll.Question,
            AllowMultipleAnswers = poll.AllowMultipleAnswers,
            IsAnonymous = poll.IsAnonymous,
            IsClosed = poll.IsClosed,
            ClosesAt = poll.ClosesAt,
            TotalVoters = poll.TotalVoters,
            MyVotes = myVotes,
            Options = poll.Options.OrderBy(o => o.Order).Select(o => new PollOptionDto
            {
                Id = o.Id,
                Text = o.Text,
                Order = o.Order,
                VoteCount = o.VoteCount,
                Percentage = poll.TotalVoters > 0 
                    ? (int)Math.Round(o.VoteCount * 100.0 / poll.TotalVoters) 
                    : 0
            }).ToList()
        };
    }

    private async Task<MessageDto> CreateMessageDtoWithPoll(Message message, Poll poll, Guid currentUserId)
    {
        var user = await _context.Users.FindAsync(message.SenderId);
        
        return new MessageDto
        {
            Id = message.Id,
            ChatId = message.ChatId,
            SenderId = message.SenderId,
            SenderName = user?.DisplayName ?? "Unknown",
            Type = message.Type,
            Content = message.Content,
            Status = message.Status,
            CreatedAt = message.CreatedAt,
            Poll = CreatePollDto(poll, currentUserId)
        };
    }
}

