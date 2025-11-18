using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Data;
using System.Security.Claims;

namespace RareBooksService.WebApi.Helpers
{
    /// <summary>
    /// Атрибут для проверки доступа к функционалу коллекции
    /// </summary>
    public class RequiresCollectionAccessAttribute : TypeFilterAttribute
    {
        public RequiresCollectionAccessAttribute() : base(typeof(CollectionAccessFilter))
        {
        }
    }

    public class CollectionAccessFilter : IAsyncActionFilter
    {
        private readonly UsersDbContext _context;
        private readonly ILogger<CollectionAccessFilter> _logger;

        public CollectionAccessFilter(UsersDbContext context, ILogger<CollectionAccessFilter> logger)
        {
            _context = context;
            _logger = logger;
        }

        public async Task OnActionExecutionAsync(ActionExecutingContext context, ActionExecutionDelegate next)
        {
            var userId = context.HttpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

            if (string.IsNullOrEmpty(userId))
            {
                context.Result = new UnauthorizedObjectResult(new { error = "Пользователь не авторизован" });
                return;
            }

            // Проверяем активную подписку
            var user = await _context.Users
                .Include(u => u.Subscriptions)
                    .ThenInclude(s => s.SubscriptionPlan)
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null)
            {
                context.Result = new UnauthorizedObjectResult(new { error = "Пользователь не найден" });
                return;
            }

            var activeSubscription = user.Subscriptions
                .FirstOrDefault(s => s.IsActive && s.EndDate > DateTime.UtcNow);

            if (activeSubscription == null)
            {
                _logger.LogWarning("Пользователь {UserId} попытался получить доступ к коллекции без активной подписки", userId);
                context.Result = new ForbidResult();
                return;
            }

            if (!activeSubscription.SubscriptionPlan.HasCollectionAccess)
            {
                _logger.LogWarning("Пользователь {UserId} попытался получить доступ к коллекции без соответствующей опции в подписке", userId);
                context.Result = new ObjectResult(new 
                { 
                    error = "Доступ к коллекции недоступен в вашем тарифном плане" 
                })
                {
                    StatusCode = 403
                };
                return;
            }

            await next();
        }
    }
}

