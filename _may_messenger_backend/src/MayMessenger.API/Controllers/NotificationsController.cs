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
        // #region agent log - Hypothesis A: Check FCM token registration
        _logger.LogInformation($"[DEBUG_FCM_A] RegisterToken called with token: {request.Token?.Substring(0, Math.Min(20, request.Token?.Length ?? 0))}..., deviceInfo: {request.DeviceInfo}");
        // #endregion
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null || !Guid.TryParse(userId, out var userGuid))
        {
            // #region agent log - Hypothesis A
            _logger.LogWarning($"[DEBUG_FCM_B] Unauthorized token registration attempt");
            // #endregion
            return Unauthorized();
        }

        // #region agent log - Hypothesis A
        _logger.LogInformation($"[DEBUG_FCM_C] Registering FCM token for user {userGuid}");
        // #endregion
        try
        {
            await _unitOfWork.FcmTokens.RegisterOrUpdateAsync(userGuid, request.Token, request.DeviceInfo ?? "Unknown");
            // #region agent log - Hypothesis A
            _logger.LogInformation($"[DEBUG_FCM_D] FCM token successfully registered for user {userGuid}");
            // #endregion
            
            return Ok(new { success = true, message = "Token registered successfully" });
        }
        catch (Exception ex)
        {
            // #region agent log - Hypothesis A
            _logger.LogError(ex, $"[DEBUG_FCM_ERROR] Failed to register FCM token for user {userGuid}");
            // #endregion
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

