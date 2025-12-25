using Microsoft.AspNetCore.Mvc;
using MayMessenger.Application.DTOs;
using MayMessenger.Application.Interfaces;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly IUnitOfWork _unitOfWork;
    
    public AuthController(IAuthService authService, IUnitOfWork unitOfWork)
    {
        _authService = authService;
        _unitOfWork = unitOfWork;
    }
    
    [HttpPost("register")]
    public async Task<ActionResult<AuthResponseDto>> Register([FromBody] RegisterRequestDto request)
    {
        var (success, token, message) = await _authService.RegisterAsync(
            request.PhoneNumber,
            request.DisplayName,
            request.Password,
            request.InviteCode);
        
        var response = new AuthResponseDto
        {
            Success = success,
            Token = token,
            Message = message
        };
        
        return success ? Ok(response) : BadRequest(response);
    }
    
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponseDto>> Login([FromBody] LoginRequestDto request)
    {
        var (success, token, message) = await _authService.LoginAsync(
            request.PhoneNumber,
            request.Password);
        
        var response = new AuthResponseDto
        {
            Success = success,
            Token = token,
            Message = message
        };
        
        return success ? Ok(response) : BadRequest(response);
    }
    
    /// <summary>
    /// Validate an invite code before registration
    /// </summary>
    [HttpGet("validate-invite/{code}")]
    public async Task<ActionResult<ValidateInviteCodeResponse>> ValidateInviteCode(string code)
    {
        if (string.IsNullOrWhiteSpace(code))
        {
            return Ok(new ValidateInviteCodeResponse
            {
                IsValid = false,
                Message = "Введите код приглашения"
            });
        }
        
        var invite = await _unitOfWork.InviteLinks.GetByCodeAsync(code);
        
        if (invite == null)
        {
            return Ok(new ValidateInviteCodeResponse
            {
                IsValid = false,
                Message = "Код приглашения не найден"
            });
        }
        
        // Get creator name
        var creator = await _unitOfWork.Users.GetByIdAsync(invite.CreatedBy);
        var creatorName = creator?.DisplayName ?? "Неизвестный пользователь";
        
        if (!invite.IsActive)
        {
            return Ok(new ValidateInviteCodeResponse
            {
                IsValid = false,
                Message = "Код приглашения деактивирован",
                CreatorName = creatorName
            });
        }
        
        if (invite.ExpiresAt.HasValue && invite.ExpiresAt.Value < DateTime.UtcNow)
        {
            return Ok(new ValidateInviteCodeResponse
            {
                IsValid = false,
                Message = "Срок действия кода истёк",
                CreatorName = creatorName,
                ExpiresAt = invite.ExpiresAt
            });
        }
        
        if (invite.UsesLeft.HasValue && invite.UsesLeft.Value <= 0)
        {
            return Ok(new ValidateInviteCodeResponse
            {
                IsValid = false,
                Message = "Код приглашения уже использован",
                CreatorName = creatorName,
                UsesLeft = 0
            });
        }
        
        return Ok(new ValidateInviteCodeResponse
        {
            IsValid = true,
            Message = $"Код действителен. Вас приглашает {creatorName}",
            CreatorName = creatorName,
            UsesLeft = invite.UsesLeft,
            ExpiresAt = invite.ExpiresAt
        });
    }
}


