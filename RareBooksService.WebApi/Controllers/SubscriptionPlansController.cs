using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class SubscriptionPlansController : BaseController
    {
        private readonly UsersDbContext _context; // <-- Вместо BooksDbContext
        private readonly UserManager<ApplicationUser> _userManager;

        public SubscriptionPlansController(
            UsersDbContext context,
            UserManager<ApplicationUser> userManager
        ) : base(userManager)
        {
            _context = context;
            _userManager = userManager;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            // SubscriptionPlans в UsersDbContext
            var plans = await _context.SubscriptionPlans.ToListAsync();
            return Ok(plans);
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] SubscriptionPlan plan)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Только администратор может управлять планами подписок.");
            }

            // Пример валидации
            if (string.IsNullOrWhiteSpace(plan.Name))
                return BadRequest("Name is required.");
            if (plan.Price < 0)
                return BadRequest("Price must be >= 0.");

            _context.SubscriptionPlans.Add(plan);
            await _context.SaveChangesAsync();
            return Ok(plan);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] SubscriptionPlan plan)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Только администратор может управлять планами подписок.");
            }

            var existing = await _context.SubscriptionPlans.FindAsync(id);
            if (existing == null) return NotFound("План не найден.");

            existing.Name = plan.Name;
            existing.Price = plan.Price;
            existing.MonthlyRequestLimit = plan.MonthlyRequestLimit;
            existing.IsActive = plan.IsActive;

            await _context.SaveChangesAsync();
            return Ok(existing);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Только администратор может управлять планами подписок.");
            }

            var plan = await _context.SubscriptionPlans.FindAsync(id);
            if (plan == null) return NotFound("План не найден.");

            _context.SubscriptionPlans.Remove(plan);
            await _context.SaveChangesAsync();
            return Ok();
        }
    }
}
