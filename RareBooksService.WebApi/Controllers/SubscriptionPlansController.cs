using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using Microsoft.Extensions.Logging;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SubscriptionPlansController : BaseController
    {
        private readonly UsersDbContext _context; // <-- Вместо BooksDbContext
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ILogger<SubscriptionPlansController> _logger;

        public SubscriptionPlansController(
            UsersDbContext context,
            UserManager<ApplicationUser> userManager,
            ILogger<SubscriptionPlansController> logger
        ) : base(userManager)
        {
            _context = context;
            _userManager = userManager;
            _logger = logger;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            _logger.LogInformation("Запрос на получение всех планов подписки");
            
            // SubscriptionPlans в UsersDbContext
            var plans = await _context.SubscriptionPlans.ToListAsync();
            
            _logger.LogInformation("Возвращаем {Count} планов подписки", plans.Count);
            return Ok(plans);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] SubscriptionPlan plan)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Попытка создания плана подписки неадминистратором: {UserId}", currentUser?.Id);
                return Forbid("Только администратор может управлять планами подписок.");
            }

            // Пример валидации
            if (string.IsNullOrWhiteSpace(plan.Name))
                return BadRequest("Name is required.");
            if (plan.Price < 0)
                return BadRequest("Price must be >= 0.");

            // Логируем данные плана для отладки
            _logger.LogInformation("Создание нового плана подписки: {Name}, Цена: {Price}, Лимит: {Limit}, Описание: {Description}", 
                plan.Name, plan.Price, plan.MonthlyRequestLimit, plan.Description ?? "не указано");

            _context.SubscriptionPlans.Add(plan);
            await _context.SaveChangesAsync();
            
            _logger.LogInformation("План подписки успешно создан с ID: {PlanId}", plan.Id);
            return Ok(plan);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] SubscriptionPlan plan)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Попытка обновления плана подписки неадминистратором: {UserId}", currentUser?.Id);
                return Forbid("Только администратор может управлять планами подписок.");
            }

            var existing = await _context.SubscriptionPlans.FindAsync(id);
            if (existing == null) return NotFound("План не найден.");

            // Логируем изменения для отладки
            _logger.LogInformation(
                "Обновление плана подписки ID {PlanId}. Старые значения: Name={OldName}, Price={OldPrice}, Limit={OldLimit}, Description={OldDescription}",
                id, existing.Name, existing.Price, existing.MonthlyRequestLimit, existing.Description ?? "не указано");
            
            _logger.LogInformation(
                "Новые значения: Name={NewName}, Price={NewPrice}, Limit={NewLimit}, Description={NewDescription}",
                plan.Name, plan.Price, plan.MonthlyRequestLimit, plan.Description ?? "не указано");

            existing.Name = plan.Name;
            existing.Price = plan.Price;
            existing.MonthlyRequestLimit = plan.MonthlyRequestLimit;
            existing.IsActive = plan.IsActive;
            existing.Description = plan.Description;

            await _context.SaveChangesAsync();
            _logger.LogInformation("План подписки ID {PlanId} успешно обновлен", id);
            return Ok(existing);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Попытка удаления плана подписки неадминистратором: {UserId}", currentUser?.Id);
                return Forbid("Только администратор может управлять планами подписок.");
            }

            var plan = await _context.SubscriptionPlans.FindAsync(id);
            if (plan == null) return NotFound("План не найден.");

            _logger.LogInformation(
                "Удаление плана подписки ID {PlanId}: Name={Name}, Price={Price}, Description={Description}",
                id, plan.Name, plan.Price, plan.Description ?? "не указано");

            _context.SubscriptionPlans.Remove(plan);
            await _context.SaveChangesAsync();
            
            _logger.LogInformation("План подписки ID {PlanId} успешно удален", id);
            return Ok();
        }
    }
}
