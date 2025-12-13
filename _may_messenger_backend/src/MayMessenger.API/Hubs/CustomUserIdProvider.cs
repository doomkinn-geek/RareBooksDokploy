using System.Security.Claims;
using Microsoft.AspNetCore.SignalR;

namespace MayMessenger.API.Hubs;

public class CustomUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection)
    {
        // Return the user ID from the NameIdentifier claim
        return connection.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    }
}

