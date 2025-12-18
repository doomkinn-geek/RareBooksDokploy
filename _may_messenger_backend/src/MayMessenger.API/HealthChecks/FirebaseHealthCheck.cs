using Microsoft.Extensions.Diagnostics.HealthChecks;
using MayMessenger.Application.Services;

namespace MayMessenger.API.HealthChecks;

public class FirebaseHealthCheck : IHealthCheck
{
    private readonly IFirebaseService _firebaseService;
    private readonly ILogger<FirebaseHealthCheck> _logger;

    public FirebaseHealthCheck(IFirebaseService firebaseService, ILogger<FirebaseHealthCheck> logger)
    {
        _firebaseService = firebaseService;
        _logger = logger;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var isInitialized = _firebaseService.IsInitialized;
            
            var data = new Dictionary<string, object>
            {
                { "service", "Firebase Admin SDK" },
                { "initialized", isInitialized }
            };

            if (isInitialized)
            {
                return Task.FromResult(
                    HealthCheckResult.Healthy("Firebase is initialized and ready", data)
                );
            }
            else
            {
                return Task.FromResult(
                    HealthCheckResult.Degraded("Firebase is not initialized. Push notifications unavailable.", null, data)
                );
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Firebase health check failed");
            return Task.FromResult(
                HealthCheckResult.Unhealthy("Firebase health check failed", ex)
            );
        }
    }
}

