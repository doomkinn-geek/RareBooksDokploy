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
    [Authorize]
    public class BookUpdateServiceController : ControllerBase
    {
        private readonly IBookUpdateService _bookUpdateService;
        private readonly UserManager<ApplicationUser> _userManager;

        public BookUpdateServiceController(
            IBookUpdateService bookUpdateService,        // <-- Получаем через DI
            UserManager<ApplicationUser> userManager
        )
        {
            _bookUpdateService = bookUpdateService;
            _userManager = userManager;
        }

        [HttpGet("status")]
        public async Task<IActionResult> GetStatus()
        {
            var currentUser = await _userManager.GetUserAsync(User);
            if (currentUser == null || currentUser.Role != "Admin")
                return Forbid();

            return Ok(new
            {
                isPaused = _bookUpdateService.IsPaused,
                isRunningNow = _bookUpdateService.IsRunningNow,
                lastRunTimeUtc = _bookUpdateService.LastRunTimeUtc,
                nextRunTimeUtc = _bookUpdateService.NextRunTimeUtc
            });
        }

        [HttpPost("pause")]
        public async Task<IActionResult> Pause()
        {
            var currentUser = await _userManager.GetUserAsync(User);
            if (currentUser == null || currentUser.Role != "Admin")
                return Forbid();

            _bookUpdateService.ForcePause();
            return Ok(new { message = "BookUpdateService paused" });
        }

        [HttpPost("resume")]
        public async Task<IActionResult> Resume()
        {
            var currentUser = await _userManager.GetUserAsync(User);
            if (currentUser == null || currentUser.Role != "Admin")
                return Forbid();

            _bookUpdateService.ForceResume();
            return Ok(new { message = "BookUpdateService resumed" });
        }
    }
}
