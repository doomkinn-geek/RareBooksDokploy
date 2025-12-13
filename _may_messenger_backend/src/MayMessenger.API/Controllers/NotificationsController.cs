using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<NotificationsController> _logger;

    public NotificationsController(IUnitOfWork unitOfWork, ILogger<NotificationsController> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    [HttpPost("register-token")]
    public async Task<IActionResult> RegisterToken([FromBody] RegisterTokenRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null || !Guid.TryParse(userId, out var userGuid))
        {
            return Unauthorized();
        }

        try
        {
            await _unitOfWork.FcmTokens.RegisterOrUpdateAsync(userGuid, request.Token, request.DeviceInfo ?? "Unknown");
            _logger.LogInformation($"FCM token registered for user {userGuid}");
            
            return Ok(new { success = true, message = "Token registered successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Failed to register FCM token for user {userGuid}");
            return StatusCode(500, new { success = false, message = "Failed to register token" });
        }
    }

    [HttpPost("deactivate-token")]
    public async Task<IActionResult> DeactivateToken([FromBody] DeactivateTokenRequest request)
    {
        try
        {
            await _unitOfWork.FcmTokens.DeactivateTokenAsync(request.Token);
            return Ok(new { success = true, message = "Token deactivated successfully" });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to deactivate FCM token");
            return StatusCode(500, new { success = false, message = "Failed to deactivate token" });
        }
    }

    [HttpGet("tokens")]
    public async Task<IActionResult> GetRegisteredTokens()
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null || !Guid.TryParse(userId, out var userGuid))
        {
            return Unauthorized();
        }

        try
        {
            var tokens = await _unitOfWork.FcmTokens.GetActiveTokensForUserAsync(userGuid);
            return Ok(new { count = tokens.Count, tokens });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Failed to get tokens for user {userGuid}");
            return StatusCode(500, new { success = false, message = "Failed to get tokens" });
        }
    }
}

public class RegisterTokenRequest
{
    public string Token { get; set; } = "";
    public string? DeviceInfo { get; set; }
}

public class DeactivateTokenRequest
{
    public string Token { get; set; } = "";
}

