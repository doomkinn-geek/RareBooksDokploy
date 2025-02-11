using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models.Settings;
using System.IO;

namespace RareBooksService.WebApi.Services
{
    /// <summary>
    /// Периодически чистит локальный кэш от устаревших файлов.
    /// Если секции "CacheSettings" нет — просто пропускает очистку.
    /// </summary>
    public class CacheCleanupService : IHostedService, IDisposable
    {
        private readonly ILogger<CacheCleanupService> _logger;
        private readonly string? _cacheRoot;
        private readonly TimeSpan? _cacheLifetime;
        private readonly long? _maxCacheSizeBytes;

        private Timer? _timer;
        private static readonly TimeSpan _period = TimeSpan.FromDays(1);

        private readonly bool _settingsAvailable = false;

        public CacheCleanupService(
            ILogger<CacheCleanupService> logger,
            IConfiguration configuration)
        {
            _logger = logger;

            var cacheSection = configuration.GetSection("CacheSettings");
            if (cacheSection.Exists())
            {
                var c = cacheSection.Get<CacheSettings>();
                if (c != null)
                {
                    _cacheRoot = Path.GetFullPath(
                        c.LocalCachePath ?? "image_cache",
                        AppContext.BaseDirectory
                    );
                    _cacheLifetime = TimeSpan.FromDays(c.DaysToKeep);
                    _maxCacheSizeBytes = (long)c.MaxCacheSizeMB * 1024 * 1024;
                    Directory.CreateDirectory(_cacheRoot);

                    _settingsAvailable = true;

                    _logger.LogInformation(
                        "CacheCleanupService: настроен. Папка={_cacheRoot}, LifeTime={_cacheLifetime}, MaxSize={_maxCacheSizeBytes}",
                        _cacheRoot, _cacheLifetime, _maxCacheSizeBytes
                    );
                }
            }

            if (!_settingsAvailable)
            {
                _logger.LogWarning("CacheCleanupService: секция CacheSettings не найдена. Очистка кэша не будет выполняться.");
            }
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            if (_settingsAvailable)
            {
                // Запускаем сразу и каждые сутки
                _timer = new Timer(DoCleanup, null, TimeSpan.Zero, _period);
            }
            return Task.CompletedTask;
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _timer?.Change(Timeout.Infinite, 0);
            return Task.CompletedTask;
        }

        private void DoCleanup(object? state)
        {
            if (!_settingsAvailable) return;

            if (_cacheRoot == null || !Directory.Exists(_cacheRoot))
            {
                _logger.LogWarning("Cache directory '{0}' не существует. Пропускаем очистку.", _cacheRoot);
                return;
            }

            try
            {
                _logger.LogInformation("CacheCleanupService: начинаем очистку кэша в {0}", _cacheRoot);

                var now = DateTime.UtcNow;
                var allFiles = Directory.GetFiles(_cacheRoot, "*.*", SearchOption.AllDirectories);

                // 1) Удаляем файлы старше _cacheLifetime
                if (_cacheLifetime.HasValue)
                {
                    foreach (var file in allFiles)
                    {
                        try
                        {
                            var fi = new FileInfo(file);
                            var age = now - fi.LastWriteTimeUtc;
                            if (age > _cacheLifetime.Value)
                            {
                                fi.Delete();
                                _logger.LogDebug("Removed old file: {file}", file);
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning("Error removing file {file}: {ex}", file, ex.Message);
                        }
                    }
                }

                // 2) Проверяем общий размер. Если > _maxCacheSizeBytes, удаляем самые старые
                if (_maxCacheSizeBytes.HasValue && _maxCacheSizeBytes.Value > 0)
                {
                    var filesAgain = Directory.GetFiles(_cacheRoot, "*.*", SearchOption.AllDirectories)
                        .Select(f => new FileInfo(f))
                        .Where(f => f.Exists)
                        .OrderBy(f => f.LastWriteTimeUtc)
                        .ToList();

                    long totalSize = filesAgain.Sum(f => f.Length);
                    if (totalSize > _maxCacheSizeBytes.Value)
                    {
                        _logger.LogInformation(
                            "Cache size {size} exceeds max {max}. Removing oldest files...",
                            totalSize, _maxCacheSizeBytes.Value
                        );

                        foreach (var fi in filesAgain)
                        {
                            if (totalSize <= _maxCacheSizeBytes.Value)
                                break;

                            try
                            {
                                var len = fi.Length;
                                fi.Delete();
                                totalSize -= len;
                                _logger.LogDebug("Removed oldest file: {file}", fi.FullName);
                            }
                            catch (Exception ex)
                            {
                                _logger.LogWarning("Error removing file {file}: {ex}", fi.FullName, ex.Message);
                            }
                        }
                    }
                }

                _logger.LogInformation("CacheCleanupService: очистка кэша завершена.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in cache cleanup");
            }
        }

        public void Dispose()
        {
            _timer?.Dispose();
        }
    }
}
