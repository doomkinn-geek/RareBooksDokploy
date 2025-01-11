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
        public IActionResult GetStatus()
        {
            return Ok(new
            {
                isPaused = _bookUpdateService.IsPaused,
                isRunningNow = _bookUpdateService.IsRunningNow,
                lastRunTimeUtc = _bookUpdateService.LastRunTimeUtc,
                nextRunTimeUtc = _bookUpdateService.NextRunTimeUtc
            });
        }

        [HttpPost("pause")]
        public IActionResult Pause()
        {
            _bookUpdateService.ForcePause();
            return Ok(new { message = "BookUpdateService paused" });
        }

        [HttpPost("resume")]
        public IActionResult Resume()
        {
            _bookUpdateService.ForceResume();
            return Ok(new { message = "BookUpdateService resumed" });
        }
    }
}
