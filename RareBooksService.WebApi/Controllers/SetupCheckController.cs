using Microsoft.AspNetCore.Mvc;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SetupCheckController : ControllerBase
    {
        private readonly ISetupStateService _setupState;

        public SetupCheckController(ISetupStateService setupState)
        {
            _setupState = setupState;
        }

        [HttpGet("need-setup")]
        public IActionResult NeedSetup()
        {
            return Ok(new { NeedSetup = _setupState.IsInitialSetupNeeded });
        }
    }

}
