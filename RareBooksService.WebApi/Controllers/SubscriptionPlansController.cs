using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(Policy = "RequireAdministratorRole")]
    public class SubscriptionPlansController : ControllerBase
    {
        private readonly RegularBaseBooksContext _db;

        public SubscriptionPlansController(RegularBaseBooksContext db)
        {
            _db = db;
        }

        [HttpGet]
        public async Task<IActionResult> GetAll()
        {
            return Ok(await _db.SubscriptionPlans.ToListAsync());
        }

        [HttpPost]
        public async Task<IActionResult> Create([FromBody] SubscriptionPlan plan)
        {
            // Можно добавить проверки
            _db.SubscriptionPlans.Add(plan);
            await _db.SaveChangesAsync();
            return Ok(plan);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(int id, [FromBody] SubscriptionPlan plan)
        {
            var existing = await _db.SubscriptionPlans.FindAsync(id);
            if (existing == null) return NotFound();

            existing.Name = plan.Name;
            existing.Price = plan.Price;
            existing.MonthlyRequestLimit = plan.MonthlyRequestLimit;
            existing.IsActive = plan.IsActive;

            await _db.SaveChangesAsync();
            return Ok(existing);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(int id)
        {
            var plan = await _db.SubscriptionPlans.FindAsync(id);
            if (plan == null) return NotFound();

            _db.SubscriptionPlans.Remove(plan);
            await _db.SaveChangesAsync();
            return Ok();
        }
    }
}
