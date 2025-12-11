using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private static readonly Dictionary<Guid, string> _userTokens = new();
    private static readonly object _lockObject = new();

    [HttpPost("register-token")]
    public IActionResult RegisterToken([FromBody] RegisterTokenRequest request)
    {
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (userId == null || !Guid.TryParse(userId, out var userGuid))
        {
            return Unauthorized();
        }

        lock (_lockObject)
        {
            _userTokens[userGuid] = request.Token;
        }

        return Ok(new { success = true, message = "Token registered successfully" });
    }

    [HttpPost("send")]
    public async Task<IActionResult> SendNotification([FromBody] SendNotificationRequest request)
    {
        // This endpoint would integrate with Firebase Admin SDK
        // For now, it's a placeholder for future FCM integration
        
        string? token;
        lock (_lockObject)
        {
            _userTokens.TryGetValue(request.UserId, out token);
        }

        if (token == null)
        {
            return NotFound(new { error = "User token not found" });
        }

        // TODO: Integrate with Firebase Admin SDK to send push notification
        // Example:
        // var message = new Message
        // {
        //     Token = token,
        //     Notification = new Notification
        //     {
        //         Title = request.Title,
        //         Body = request.Body,
        //     },
        //     Data = new Dictionary<string, string>
        //     {
        //         { "chatId", request.ChatId.ToString() }
        //     }
        // };
        // await FirebaseMessaging.DefaultInstance.SendAsync(message);

        return Ok(new { success = true, message = "Notification sent (placeholder)" });
    }

    [HttpGet("tokens")]
    public IActionResult GetRegisteredTokens()
    {
        lock (_lockObject)
        {
            return Ok(new { count = _userTokens.Count, tokens = _userTokens });
        }
    }
}

public class RegisterTokenRequest
{
    public string Token { get; set; } = "";
}

public class SendNotificationRequest
{
    public Guid UserId { get; set; }
    public string Title { get; set; } = "";
    public string Body { get; set; } = "";
    public Guid ChatId { get; set; }
}

