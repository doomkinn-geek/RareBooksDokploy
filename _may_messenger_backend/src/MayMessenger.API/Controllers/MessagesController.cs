using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class MessagesController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IWebHostEnvironment _environment;
    
    public MessagesController(IUnitOfWork unitOfWork, IWebHostEnvironment environment)
    {
        _unitOfWork = unitOfWork;
        _environment = environment;
    }
    
    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }
    
    [HttpGet("{chatId}")]
    public async Task<ActionResult<IEnumerable<MessageDto>>> GetMessages(Guid chatId, [FromQuery] int skip = 0, [FromQuery] int take = 50)
    {
        var messages = await _unitOfWork.Messages.GetChatMessagesAsync(chatId, skip, take);
        
        var messageDtos = messages.Select(m => new MessageDto
        {
            Id = m.Id,
            ChatId = m.ChatId,
            SenderId = m.SenderId,
            SenderName = m.Sender.DisplayName,
            Type = m.Type,
            Content = m.Content,
            FilePath = m.FilePath,
            Status = m.Status,
            CreatedAt = m.CreatedAt
        });
        
        return Ok(messageDtos);
    }
    
    [HttpPost]
    public async Task<ActionResult<MessageDto>> SendMessage([FromBody] SendMessageDto dto)
    {
        var userId = GetCurrentUserId();
        
        var message = new Message
        {
            ChatId = dto.ChatId,
            SenderId = userId,
            Type = dto.Type,
            Content = dto.Content,
            Status = MessageStatus.Sent
        };
        
        await _unitOfWork.Messages.AddAsync(message);
        await _unitOfWork.SaveChangesAsync();
        
        var sender = await _unitOfWork.Users.GetByIdAsync(userId);
        
        return Ok(new MessageDto
        {
            Id = message.Id,
            ChatId = message.ChatId,
            SenderId = message.SenderId,
            SenderName = sender?.DisplayName ?? "Unknown",
            Type = message.Type,
            Content = message.Content,
            FilePath = message.FilePath,
            Status = message.Status,
            CreatedAt = message.CreatedAt
        });
    }
    
    [HttpPost("audio")]
    public async Task<ActionResult<MessageDto>> SendAudioMessage([FromForm] Guid chatId, IFormFile audioFile)
    {
        var userId = GetCurrentUserId();
        
        if (audioFile == null || audioFile.Length == 0)
            return BadRequest("No audio file provided");
        
        // Save audio file
        var uploadsFolder = Path.Combine(_environment.ContentRootPath, "uploads", "audio");
        Directory.CreateDirectory(uploadsFolder);
        
        var fileName = $"{Guid.NewGuid()}{Path.GetExtension(audioFile.FileName)}";
        var filePath = Path.Combine(uploadsFolder, fileName);
        
        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await audioFile.CopyToAsync(stream);
        }
        
        var message = new Message
        {
            ChatId = chatId,
            SenderId = userId,
            Type = MessageType.Audio,
            FilePath = $"/uploads/audio/{fileName}",
            Status = MessageStatus.Sent
        };
        
        await _unitOfWork.Messages.AddAsync(message);
        await _unitOfWork.SaveChangesAsync();
        
        var sender = await _unitOfWork.Users.GetByIdAsync(userId);
        
        return Ok(new MessageDto
        {
            Id = message.Id,
            ChatId = message.ChatId,
            SenderId = message.SenderId,
            SenderName = sender?.DisplayName ?? "Unknown",
            Type = message.Type,
            Content = message.Content,
            FilePath = message.FilePath,
            Status = message.Status,
            CreatedAt = message.CreatedAt
        });
    }
}


