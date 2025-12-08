using Microsoft.AspNetCore.Mvc;
using MayMessenger.Application.DTOs;
using MayMessenger.Application.Interfaces;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    
    public AuthController(IAuthService authService)
    {
        _authService = authService;
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
}


