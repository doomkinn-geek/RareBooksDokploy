// BookUpdateServiceController.cs

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize] // Только админ может видеть и управлять
    public class BookUpdateServiceController : BaseController
    {
        public BookUpdateServiceController(
            UserManager<ApplicationUser> userManager)
            : base(userManager)
        { }

        [HttpGet("status")]
        public IActionResult GetStatus()
        {
            return Ok(new
            {
                isPaused = BookUpdateService.IsPaused,
                isRunningNow = BookUpdateService.IsRunningNow,
                lastRunTimeUtc = BookUpdateService.LastRunTimeUtc,
                nextRunTimeUtc = BookUpdateService.NextRunTimeUtc
            });
        }

        [HttpPost("pause")]
        public async Task<IActionResult> Pause()
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {                
                return Forbid("Просматривать список пользователей может только администратор");
            }
            BookUpdateService.IsPaused = true;
            return Ok(new { message = "BookUpdateService paused" });
        }

        [HttpPost("resume")]
        public async Task<IActionResult> Resume()
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Просматривать список пользователей может только администратор");
            }
            BookUpdateService.IsPaused = false;
            return Ok(new { message = "BookUpdateService resumed" });
        }
    }
}
