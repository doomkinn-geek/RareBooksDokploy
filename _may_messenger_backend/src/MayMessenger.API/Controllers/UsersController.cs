using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    
    public UsersController(IUnitOfWork unitOfWork)
    {
        _unitOfWork = unitOfWork;
    }
    
    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }
    
    /// <summary>
    /// Получить профиль текущего пользователя
    /// </summary>
    [HttpGet("me")]
    public async Task<ActionResult<UserDto>> GetMyProfile()
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user == null)
        {
            return NotFound("User not found");
        }
        
        return Ok(new UserDto
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            DisplayName = user.DisplayName,
            Avatar = user.Avatar,
            Role = user.Role
        });
    }
    
    /// <summary>
    /// Создать персональный invite link (1 использование, срок 7 дней)
    /// </summary>
    [HttpPost("invite-link")]
    public async Task<ActionResult<InviteLinkDto>> CreateInviteLink()
    {
        var userId = GetCurrentUserId();
        
        var inviteLink = new InviteLink
        {
            Code = Guid.NewGuid().ToString("N")[..10].ToUpper(),
            CreatedBy = userId,
            UsesLeft = 1, // Одно использование
            ExpiresAt = DateTime.UtcNow.AddDays(7), // Срок 7 дней
            IsActive = true
        };
        
        await _unitOfWork.InviteLinks.AddAsync(inviteLink);
        await _unitOfWork.SaveChangesAsync();
        
        return Ok(new InviteLinkDto
        {
            Id = inviteLink.Id,
            Code = inviteLink.Code,
            UsesLeft = inviteLink.UsesLeft,
            ExpiresAt = inviteLink.ExpiresAt,
            IsActive = inviteLink.IsActive,
            CreatedAt = inviteLink.CreatedAt
        });
    }
    
    /// <summary>
    /// Получить свои активные invite links
    /// </summary>
    [HttpGet("my-invite-links")]
    public async Task<ActionResult<IEnumerable<InviteLinkDto>>> GetMyInviteLinks()
    {
        var userId = GetCurrentUserId();
        var allLinks = await _unitOfWork.InviteLinks.GetAllAsync();
        
        var myLinks = allLinks
            .Where(l => l.CreatedBy == userId && l.IsActive && 
                       (l.ExpiresAt == null || l.ExpiresAt > DateTime.UtcNow) &&
                       (l.UsesLeft == null || l.UsesLeft > 0))
            .OrderByDescending(l => l.CreatedAt)
            .Select(l => new InviteLinkDto
            {
                Id = l.Id,
                Code = l.Code,
                UsesLeft = l.UsesLeft,
                ExpiresAt = l.ExpiresAt,
                IsActive = l.IsActive,
                CreatedAt = l.CreatedAt
            });
        
        return Ok(myLinks);
    }
    
    /// <summary>
    /// Получить список всех пользователей (для создания чатов)
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<UserDto>>> GetUsers()
    {
        var currentUserId = GetCurrentUserId();
        var users = await _unitOfWork.Users.GetAllAsync();
        
        var userDtos = users
            .Where(u => u.Id != currentUserId) // Исключаем текущего пользователя
            .Select(u => new UserDto
            {
                Id = u.Id,
                PhoneNumber = u.PhoneNumber,
                DisplayName = u.DisplayName,
                Avatar = u.Avatar,
                Role = u.Role
            });
        
        return Ok(userDtos);
    }
}

