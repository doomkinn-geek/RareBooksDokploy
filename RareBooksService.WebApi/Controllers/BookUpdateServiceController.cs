using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class BookUpdateServiceController : ControllerBase
    {
        private readonly IBookUpdateService _bookUpdateService;
        private readonly UserManager<ApplicationUser> _userManager;

        public BookUpdateServiceController(
            IBookUpdateService bookUpdateService,
            UserManager<ApplicationUser> userManager
        )
        {
            _bookUpdateService = bookUpdateService;
            _userManager = userManager;
        }

        [HttpGet("status")]
        public IActionResult GetStatus()
        {
            // Чтобы показать доп. поля, приводим к BookUpdateService только для чтения расширенных свойств
            var bus = _bookUpdateService as BookUpdateService;
            if (bus == null) return Ok(new { message = "No data" });

            return Ok(new
            {
                isPaused = _bookUpdateService.IsPaused,
                isRunningNow = _bookUpdateService.IsRunningNow,
                lastRunTimeUtc = _bookUpdateService.LastRunTimeUtc,
                nextRunTimeUtc = _bookUpdateService.NextRunTimeUtc,

                currentOperationName = bus?.CurrentOperationName,
                processedCount = bus?.ProcessedCount,
                lastProcessedLotId = bus?.LastProcessedLotId,
                lastProcessedLotTitle = bus?.LastProcessedLotTitle,

                logs = bus.GetLogEntriesSnapshot()
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

        [HttpPost("runNow")]
        public IActionResult RunNow()
        {
            var service = _bookUpdateService as BookUpdateService;
            if (service == null)
            {
                return BadRequest("Сервис не найден или не является BookUpdateService.");
            }

            service.ForceRunNow();
            return Ok(new { message = "BookUpdateService runNow called" });
        }

        [HttpPost("runCategoryCheck")]
        public IActionResult RunCategoryCheck()
        {
            var service = _bookUpdateService as BookUpdateService;
            if (service == null)
            {
                return BadRequest("Сервис не найден или не является BookUpdateService.");
            }

            // Запускаем только операцию VerifyLotCategoriesAsync
            service._currentStepIndex = 0; // Установка индекса на первую операцию (VerifyLotCategoriesAsync)
            service.ForceRunNow();
            return Ok(new { message = "Category verification started" });
        }
    }
}
