using Microsoft.Extensions.Diagnostics.HealthChecks;
using MayMessenger.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace MayMessenger.API.HealthChecks;

public class DatabaseHealthCheck : IHealthCheck
{
    private readonly AppDbContext _context;
    private readonly ILogger<DatabaseHealthCheck> _logger;

    public DatabaseHealthCheck(AppDbContext context, ILogger<DatabaseHealthCheck> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Try to connect and execute a simple query
            var canConnect = await _context.Database.CanConnectAsync(cancellationToken);
            
            if (!canConnect)
            {
                return HealthCheckResult.Unhealthy("Cannot connect to database");
            }

            // Check if we can query a table
            var userCount = await _context.Users.CountAsync(cancellationToken);
            
            var data = new Dictionary<string, object>
            {
                { "database", "PostgreSQL" },
                { "status", "Connected" },
                { "userCount", userCount }
            };

            return HealthCheckResult.Healthy("Database is healthy", data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Database health check failed");
            return HealthCheckResult.Unhealthy("Database health check failed", ex);
        }
    }
}

