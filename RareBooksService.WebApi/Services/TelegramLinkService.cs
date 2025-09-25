using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using System.Security.Cryptography;
using System.Text;

namespace RareBooksService.WebApi.Services
{
    public interface ITelegramLinkService
    {
        Task<string> GenerateLinkTokenAsync(string userId, CancellationToken cancellationToken = default);
        Task<TelegramLinkResult> LinkTelegramAccountAsync(string token, string telegramId, string telegramUsername = null, CancellationToken cancellationToken = default);
        Task<TelegramUnlinkResult> UnlinkTelegramAccountAsync(string telegramId, CancellationToken cancellationToken = default);
        Task<bool> IsTokenValidAsync(string token, CancellationToken cancellationToken = default);
        Task CleanupExpiredTokensAsync(CancellationToken cancellationToken = default);
    }

    public class TelegramLinkService : ITelegramLinkService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<TelegramLinkService> _logger;

        public TelegramLinkService(
            IServiceScopeFactory scopeFactory,
            ILogger<TelegramLinkService> logger)
        {
            _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task<string> GenerateLinkTokenAsync(string userId, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            // Проверяем, существует ли пользователь
            var user = await context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new ArgumentException("Пользователь не найден", nameof(userId));
            }

            // Проверяем, нет ли уже связанного Telegram аккаунта
            if (!string.IsNullOrEmpty(user.TelegramId))
            {
                throw new InvalidOperationException("Telegram аккаунт уже привязан к этому пользователю");
            }

            // Деактивируем старые токены для пользователя
            var oldTokens = await context.TelegramLinkTokens
                .Where(t => t.UserId == userId && !t.IsUsed)
                .ToListAsync(cancellationToken);

            foreach (var oldToken in oldTokens)
            {
                oldToken.IsUsed = true;
                oldToken.UsedAt = DateTime.UtcNow;
            }

            // Генерируем новый токен
            var token = GenerateSecureToken();
            
            var linkToken = new TelegramLinkToken
            {
                Token = token,
                UserId = userId,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddHours(24)
            };

            context.TelegramLinkTokens.Add(linkToken);
            await context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Создан токен привязки для пользователя {UserId}", userId);

            return token;
        }

        public async Task<TelegramLinkResult> LinkTelegramAccountAsync(string token, string telegramId, string telegramUsername = null, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var linkToken = await context.TelegramLinkTokens
                .Include(t => t.User)
                .FirstOrDefaultAsync(t => t.Token == token, cancellationToken);

            if (linkToken == null)
            {
                return new TelegramLinkResult { Success = false, ErrorMessage = "Токен не найден" };
            }

            if (linkToken.IsUsed)
            {
                return new TelegramLinkResult { Success = false, ErrorMessage = "Токен уже использован" };
            }

            if (linkToken.ExpiresAt < DateTime.UtcNow)
            {
                return new TelegramLinkResult { Success = false, ErrorMessage = "Токен истек" };
            }

            var user = linkToken.User;
            if (user == null)
            {
                return new TelegramLinkResult { Success = false, ErrorMessage = "Пользователь не найден" };
            }

            // Проверяем, не привязан ли уже этот Telegram ID к другому пользователю
            var existingUser = await context.Users
                .FirstOrDefaultAsync(u => u.TelegramId == telegramId && u.Id != user.Id, cancellationToken);

            if (existingUser != null)
            {
                return new TelegramLinkResult { Success = false, ErrorMessage = "Этот Telegram аккаунт уже привязан к другому пользователю" };
            }

            // Привязываем аккаунт
            user.TelegramId = telegramId;
            user.TelegramUsername = telegramUsername;

            // Отмечаем токен как использованный
            linkToken.IsUsed = true;
            linkToken.UsedAt = DateTime.UtcNow;
            linkToken.UsedByTelegramId = telegramId;
            linkToken.TelegramUsername = telegramUsername;

            await context.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Telegram аккаунт {TelegramId} успешно привязан к пользователю {UserId}", telegramId, user.Id);

            return new TelegramLinkResult 
            { 
                Success = true, 
                User = user,
                LinkedTelegramId = telegramId,
                LinkedTelegramUsername = telegramUsername
            };
        }

        public async Task<TelegramUnlinkResult> UnlinkTelegramAccountAsync(string telegramId, CancellationToken cancellationToken = default)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

                // Ищем пользователя с данным Telegram ID
                var user = await context.Users
                    .FirstOrDefaultAsync(u => u.TelegramId == telegramId, cancellationToken);

                if (user == null)
                {
                    return new TelegramUnlinkResult
                    {
                        Success = false,
                        ErrorMessage = "Пользователь с данным Telegram ID не найден"
                    };
                }

                // Сохраняем данные для результата
                var result = new TelegramUnlinkResult
                {
                    Success = true,
                    User = user,
                    UnlinkedTelegramId = user.TelegramId,
                    UnlinkedTelegramUsername = user.TelegramUsername
                };

                // Отвязываем Telegram аккаунт
                user.TelegramId = null;
                user.TelegramUsername = null;

                await context.SaveChangesAsync(cancellationToken);

                _logger.LogInformation("Telegram аккаунт {TelegramId} успешно отвязан от пользователя {UserId}", 
                    telegramId, user.Id);

                return result;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отвязке Telegram аккаунта {TelegramId}", telegramId);
                return new TelegramUnlinkResult
                {
                    Success = false,
                    ErrorMessage = "Произошла ошибка при отвязке аккаунта"
                };
            }
        }

        public async Task<bool> IsTokenValidAsync(string token, CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var linkToken = await context.TelegramLinkTokens
                .FirstOrDefaultAsync(t => t.Token == token, cancellationToken);

            return linkToken != null && !linkToken.IsUsed && linkToken.ExpiresAt > DateTime.UtcNow;
        }

        public async Task CleanupExpiredTokensAsync(CancellationToken cancellationToken = default)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            var cutoffDate = DateTime.UtcNow.AddDays(-7); // Удаляем токены старше 7 дней
            
            var expiredTokens = await context.TelegramLinkTokens
                .Where(t => t.CreatedAt < cutoffDate)
                .ToListAsync(cancellationToken);

            if (expiredTokens.Any())
            {
                context.TelegramLinkTokens.RemoveRange(expiredTokens);
                await context.SaveChangesAsync(cancellationToken);

                _logger.LogInformation("Удалено {Count} устаревших токенов привязки", expiredTokens.Count);
            }
        }

        private string GenerateSecureToken()
        {
            using var rng = RandomNumberGenerator.Create();
            var tokenBytes = new byte[32];
            rng.GetBytes(tokenBytes);
            
            // Используем Base64 без padding символов для удобства ввода
            return Convert.ToBase64String(tokenBytes)
                .Replace("+", "")
                .Replace("/", "")
                .Replace("=", "")
                .Substring(0, 12) // Берем первые 12 символов для удобства
                .ToUpper();
        }
    }

    public class TelegramLinkResult
    {
        public bool Success { get; set; }
        public string ErrorMessage { get; set; }
        public ApplicationUser User { get; set; }
        public string LinkedTelegramId { get; set; }
        public string LinkedTelegramUsername { get; set; }
    }

    public class TelegramUnlinkResult
    {
        public bool Success { get; set; }
        public string ErrorMessage { get; set; }
        public ApplicationUser User { get; set; }
        public string UnlinkedTelegramId { get; set; }
        public string UnlinkedTelegramUsername { get; set; }
    }
}
