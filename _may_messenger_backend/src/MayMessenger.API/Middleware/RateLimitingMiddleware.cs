using Microsoft.Extensions.Caching.Memory;
using System.Collections.Concurrent;

namespace MayMessenger.API.Middleware;

public class RateLimitingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IMemoryCache _cache;
    private readonly ILogger<RateLimitingMiddleware> _logger;

    // Rate limiting configuration
    private static readonly ConcurrentDictionary<string, RateLimitRule> _rules = new()
    {
        // Messages endpoint: 20 requests per second, 200 per minute
        ["POST:/api/messages"] = new RateLimitRule(20, TimeSpan.FromSeconds(1)),
        ["POST:/api/messages:minute"] = new RateLimitRule(200, TimeSpan.FromMinutes(1)),
        
        // Audio messages: 5 requests per second
        ["POST:/api/messages/audio"] = new RateLimitRule(5, TimeSpan.FromSeconds(1)),
        
        // Auth endpoints: stricter limits
        ["POST:/api/auth/login"] = new RateLimitRule(5, TimeSpan.FromMinutes(5)),
        ["POST:/api/auth/register"] = new RateLimitRule(3, TimeSpan.FromHours(1)),
        
        // Default: 20 requests per second
        ["*"] = new RateLimitRule(20, TimeSpan.FromSeconds(1)),
    };

    public RateLimitingMiddleware(RequestDelegate next, IMemoryCache cache, ILogger<RateLimitingMiddleware> logger)
    {
        _next = next;
        _cache = cache;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Skip rate limiting for health checks and swagger
        var path = context.Request.Path.Value?.ToLower();
        if (path?.StartsWith("/health") == true || 
            path?.StartsWith("/swagger") == true ||
            path?.StartsWith("/hubs") == true)  // Skip SignalR hubs
        {
            await _next(context);
            return;
        }

        var endpoint = $"{context.Request.Method}:{context.Request.Path}";
        var clientId = GetClientId(context);

        // Check rate limits
        if (!CheckRateLimit(clientId, endpoint))
        {
            context.Response.StatusCode = 429; // Too Many Requests
            context.Response.Headers["Retry-After"] = "60";
            await context.Response.WriteAsJsonAsync(new
            {
                error = "Rate limit exceeded. Please try again later.",
                retryAfter = 60
            });

            _logger.LogWarning("Rate limit exceeded for client {ClientId} on endpoint {Endpoint}", clientId, endpoint);
            return;
        }

        await _next(context);
    }

    private bool CheckRateLimit(string clientId, string endpoint)
    {
        // Find matching rule
        RateLimitRule? rule = null;
        if (_rules.TryGetValue(endpoint, out var specificRule))
        {
            rule = specificRule;
        }
        else if (_rules.TryGetValue($"{endpoint}:minute", out var minuteRule))
        {
            rule = minuteRule;
        }
        else if (_rules.TryGetValue("*", out var defaultRule))
        {
            rule = defaultRule;
        }

        if (rule == null)
            return true;

        var key = $"ratelimit:{clientId}:{endpoint}:{rule.Period.TotalSeconds}";
        
        var requestCount = _cache.GetOrCreate(key, entry =>
        {
            entry.AbsoluteExpirationRelativeToNow = rule.Period;
            return new RequestCounter { Count = 0, ExpiresAt = DateTime.UtcNow.Add(rule.Period) };
        });

        if (requestCount == null)
        {
            return true;
        }

        if (requestCount.Count >= rule.Limit)
        {
            return false;
        }

        // Increment counter
        requestCount.Count++;
        _cache.Set(key, requestCount, rule.Period);

        return true;
    }

    private string GetClientId(HttpContext context)
    {
        // Try to get user ID from claims
        var userId = context.User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(userId))
        {
            return $"user:{userId}";
        }

        // Fallback to IP address
        var ipAddress = context.Connection.RemoteIpAddress?.ToString();
        var forwardedFor = context.Request.Headers["X-Forwarded-For"].FirstOrDefault();
        var realIp = context.Request.Headers["X-Real-IP"].FirstOrDefault();

        return $"ip:{realIp ?? forwardedFor ?? ipAddress ?? "unknown"}";
    }
}

public class RateLimitRule
{
    public int Limit { get; set; }
    public TimeSpan Period { get; set; }

    public RateLimitRule(int limit, TimeSpan period)
    {
        Limit = limit;
        Period = period;
    }
}

public class RequestCounter
{
    public int Count { get; set; }
    public DateTime ExpiresAt { get; set; }
}

