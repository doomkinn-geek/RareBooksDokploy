using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MayMessenger.Application.DTOs;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Enums;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[Authorize(Roles = "Admin")]
[ApiController]
[Route("api/[controller]")]
public class AdminController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly Application.Interfaces.IPasswordHasher _passwordHasher;
    
    public AdminController(IUnitOfWork unitOfWork, Application.Interfaces.IPasswordHasher passwordHasher)
    {
        _unitOfWork = unitOfWork;
        _passwordHasher = passwordHasher;
    }
    
    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }
    
    [HttpPost("users")]
    public async Task<ActionResult<UserDto>> CreateUser([FromBody] RegisterRequestDto request)
    {
        if (await _unitOfWork.Users.PhoneNumberExistsAsync(request.PhoneNumber))
        {
            return BadRequest("Phone number already exists");
        }
        
        var user = new User
        {
            PhoneNumber = request.PhoneNumber,
            DisplayName = request.DisplayName,
            PasswordHash = _passwordHasher.HashPassword(request.Password),
            Role = UserRole.User
        };
        
        await _unitOfWork.Users.AddAsync(user);
        await _unitOfWork.SaveChangesAsync();
        
        return Ok(new UserDto
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            DisplayName = user.DisplayName,
            Avatar = user.Avatar,
            Role = user.Role
        });
    }
    
    [HttpGet("users")]
    public async Task<ActionResult<IEnumerable<UserDto>>> GetUsers()
    {
        var users = await _unitOfWork.Users.GetAllAsync();
        
        var userDtos = users.Select(u => new UserDto
        {
            Id = u.Id,
            PhoneNumber = u.PhoneNumber,
            DisplayName = u.DisplayName,
            Avatar = u.Avatar,
            Role = u.Role
        });
        
        return Ok(userDtos);
    }
    
    [HttpPost("invite-links")]
    public async Task<ActionResult<InviteLinkDto>> CreateInviteLink([FromBody] CreateInviteLinkDto dto)
    {
        var userId = GetCurrentUserId();
        
        var inviteLink = new InviteLink
        {
            Code = Guid.NewGuid().ToString("N")[..10].ToUpper(),
            CreatedBy = userId,
            UsesLeft = dto.UsesLeft,
            ExpiresAt = dto.ExpiresAt,
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
    
    [HttpGet("invite-links")]
    public async Task<ActionResult<IEnumerable<InviteLinkDto>>> GetInviteLinks()
    {
        var links = await _unitOfWork.InviteLinks.GetAllAsync();
        
        var linkDtos = links.Select(l => new InviteLinkDto
        {
            Id = l.Id,
            Code = l.Code,
            UsesLeft = l.UsesLeft,
            ExpiresAt = l.ExpiresAt,
            IsActive = l.IsActive,
            CreatedAt = l.CreatedAt
        });
        
        return Ok(linkDtos);
    }
}


