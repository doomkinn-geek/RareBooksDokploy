using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.Application.Services;

/// <summary>
/// Background service для очистки неактивных FCM токенов старше 30 дней
/// </summary>
public class CleanupInvalidTokensService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<CleanupInvalidTokensService> _logger;
    private readonly TimeSpan _cleanupInterval = TimeSpan.FromHours(24); // Run once per day
    private readonly int _tokenExpirationDays = 30;

    public CleanupInvalidTokensService(
        IServiceProvider serviceProvider,
        ILogger<CleanupInvalidTokensService> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("CleanupInvalidTokensService started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CleanupOldTokensAsync(stoppingToken);
                await Task.Delay(_cleanupInterval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                // Service is stopping
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in CleanupInvalidTokensService");
                // Wait a bit before retrying
                await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
            }
        }

        _logger.LogInformation("CleanupInvalidTokensService stopped");
    }

    private async Task CleanupOldTokensAsync(CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

        try
        {
            var cutoffDate = DateTime.UtcNow.AddDays(-_tokenExpirationDays);
            
            _logger.LogInformation($"Starting FCM token cleanup. Cutoff date: {cutoffDate}");

            // Get all tokens that haven't been used for 30+ days
            var tokens = await unitOfWork.FcmTokens.GetTokensOlderThanAsync(cutoffDate);

            if (tokens.Any())
            {
                _logger.LogInformation($"Found {tokens.Count} tokens to deactivate (not used since {cutoffDate})");

                foreach (var token in tokens)
                {
                    if (cancellationToken.IsCancellationRequested)
                        break;

                    await unitOfWork.FcmTokens.DeactivateTokenAsync(token.Token);
                }

                await unitOfWork.SaveChangesAsync();
                _logger.LogInformation($"Successfully deactivated {tokens.Count} old FCM tokens");
            }
            else
            {
                _logger.LogInformation("No old tokens found to cleanup");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to cleanup old FCM tokens");
            throw;
        }
    }
}

