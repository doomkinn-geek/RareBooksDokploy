using Microsoft.EntityFrameworkCore;
using MayMessenger.Infrastructure.Data;

namespace MayMessenger.API.Services;

/// <summary>
/// Сервис для управления миграциями базы данных
/// </summary>
public class MigrationService
{
    private readonly AppDbContext _context;
    private readonly ILogger<MigrationService> _logger;
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _environment;

    public MigrationService(
        AppDbContext context,
        ILogger<MigrationService> logger,
        IConfiguration configuration,
        IWebHostEnvironment environment)
    {
        _context = context;
        _logger = logger;
        _configuration = configuration;
        _environment = environment;
    }

    /// <summary>
    /// Проверить и применить pending миграции
    /// </summary>
    public async Task<bool> ApplyPendingMigrationsAsync()
    {
        try
        {
            _logger.LogInformation("Checking for pending database migrations...");

            // Проверяем соединение с БД
            var canConnect = await _context.Database.CanConnectAsync();
            if (!canConnect)
            {
                _logger.LogError("Cannot connect to database");
                return false;
            }

            // Получаем pending миграции
            var pendingMigrations = await _context.Database.GetPendingMigrationsAsync();
            var pendingMigrationsList = pendingMigrations.ToList();

            if (!pendingMigrationsList.Any())
            {
                _logger.LogInformation("Database is up to date. No pending migrations.");
                return true;
            }

            _logger.LogInformation($"Found {pendingMigrationsList.Count} pending migrations:");
            foreach (var migration in pendingMigrationsList)
            {
                _logger.LogInformation($"  - {migration}");
            }

            // Применяем миграции
            _logger.LogInformation("Applying migrations...");
            await _context.Database.MigrateAsync();
            _logger.LogInformation("Database migrations applied successfully");

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error applying database migrations");
            return false;
        }
    }

    /// <summary>
    /// Получить информацию о состоянии миграций
    /// </summary>
    public async Task<MigrationInfo> GetMigrationInfoAsync()
    {
        try
        {
            var appliedMigrations = await _context.Database.GetAppliedMigrationsAsync();
            var pendingMigrations = await _context.Database.GetPendingMigrationsAsync();

            return new MigrationInfo
            {
                IsConnected = await _context.Database.CanConnectAsync(),
                AppliedMigrations = appliedMigrations.ToList(),
                PendingMigrations = pendingMigrations.ToList(),
                DatabaseProvider = _context.Database.ProviderName ?? "Unknown"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting migration info");
            return new MigrationInfo
            {
                IsConnected = false,
                AppliedMigrations = new List<string>(),
                PendingMigrations = new List<string>(),
                DatabaseProvider = "Unknown",
                Error = ex.Message
            };
        }
    }
}

/// <summary>
/// Информация о состоянии миграций
/// </summary>
public class MigrationInfo
{
    public bool IsConnected { get; set; }
    public List<string> AppliedMigrations { get; set; } = new();
    public List<string> PendingMigrations { get; set; } = new();
    public string DatabaseProvider { get; set; } = string.Empty;
    public string? Error { get; set; }
}

