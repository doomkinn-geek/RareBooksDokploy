using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using RareBooksService.Common.Models.Settings;
using System.IO;

namespace RareBooksService.WebApi.Services
{
    /// <summary>
    /// Периодически чистит локальный кэш (image_cache) от устаревших файлов
    /// и ограничивает общий размер кэша.
    /// </summary>
    public class CacheCleanupService : IHostedService, IDisposable
    {
        private readonly ILogger<CacheCleanupService> _logger;
        private readonly string _cacheRoot;
        private readonly TimeSpan _cacheLifetime; // DaysToKeep
        private readonly long _maxCacheSizeBytes;

        private Timer? _timer;

        // Например, запускаем каждые 24 часа
        private static readonly TimeSpan _period = TimeSpan.FromDays(1);

        public CacheCleanupService(
            ILogger<CacheCleanupService> logger,
            IOptions<CacheSettings> cacheOptions)
        {
            _logger = logger;

            var opts = cacheOptions.Value;
            if (opts.LocalCachePath != null)
            {
                if (opts?.LocalCachePath != "")
                    _cacheRoot = Path.GetFullPath(opts?.LocalCachePath, AppContext.BaseDirectory);
                else
                    _cacheRoot = Path.GetFullPath("image_cache", AppContext.BaseDirectory);
            }
            else
                _cacheRoot = Path.GetFullPath("image_cache", AppContext.BaseDirectory);
            Directory.CreateDirectory(_cacheRoot);

            _cacheLifetime = TimeSpan.FromDays(opts.DaysToKeep);
            _maxCacheSizeBytes = (long)opts.MaxCacheSizeMB * 1024 * 1024;

            _logger.LogInformation("CacheCleanupService configured: Path={cacheRoot}, Lifetime={cacheLifetime} days, MaxSize={maxSize} bytes",
                _cacheRoot, _cacheLifetime.TotalDays, _maxCacheSizeBytes);
        }

        public Task StartAsync(CancellationToken cancellationToken)
        {
            // Запускаем сразу (через 0) и потом каждые сутки
            _timer = new Timer(DoCleanup, null, TimeSpan.Zero, _period);
            return Task.CompletedTask;
        }

        public Task StopAsync(CancellationToken cancellationToken)
        {
            _timer?.Change(Timeout.Infinite, 0);
            return Task.CompletedTask;
        }

        private void DoCleanup(object? state)
        {
            try
            {
                _logger.LogInformation("Starting cache cleanup... Path={cacheRoot}", _cacheRoot);
                if (!Directory.Exists(_cacheRoot))
                {
                    _logger.LogWarning("Cache directory not found: {cacheRoot}", _cacheRoot);
                    return;
                }

                // 1) Удаляем файлы старше _cacheLifetime
                var now = DateTime.UtcNow;
                var allFiles = Directory.GetFiles(_cacheRoot, "*.*", SearchOption.AllDirectories);

                foreach (var file in allFiles)
                {
                    try
                    {
                        var fi = new FileInfo(file);
                        var age = now - fi.LastWriteTimeUtc;
                        if (age > _cacheLifetime)
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

                // 2) Проверяем общий размер. Если > _maxCacheSizeBytes, удаляем самые старые.
                if (_maxCacheSizeBytes > 0)
                {
                    var filesAgain = Directory.GetFiles(_cacheRoot, "*.*", SearchOption.AllDirectories)
                        .Select(f => new FileInfo(f))
                        .Where(f => f.Exists)
                        .OrderBy(f => f.LastWriteTimeUtc)
                        .ToList();

                    long totalSize = filesAgain.Sum(f => f.Length);
                    if (totalSize > _maxCacheSizeBytes)
                    {
                        _logger.LogInformation("Cache size {size} exceeds max {max}. Removing oldest files...", totalSize, _maxCacheSizeBytes);

                        foreach (var fi in filesAgain)
                        {
                            if (totalSize <= _maxCacheSizeBytes)
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

                _logger.LogInformation("Cache cleanup completed.");
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
