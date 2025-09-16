using Microsoft.AspNetCore.Mvc;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TestController : ControllerBase
    {
        private readonly ISetupStateService _setupStateService;

        public TestController(ISetupStateService setupStateService)
        {
            _setupStateService = setupStateService;
        }

        [HttpGet("setup-status")]
        public IActionResult GetSetupStatus()
        {
            try
            {
                return Ok(new 
                { 
                    success = true, 
                    message = "Test endpoint working",
                    timestamp = DateTime.UtcNow,
                    isSetupNeeded = _setupStateService.IsInitialSetupNeeded,
                    diagnostics = new
                    {
                        serverStatus = "OK",
                        middlewareBypass = "Working"
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = ex.Message,
                    type = ex.GetType().Name
                });
            }
        }

        [HttpPost("test-initialize")]
        public IActionResult TestInitialize([FromBody] object payload)
        {
            try
            {
                return Ok(new 
                { 
                    success = true, 
                    message = "Test initialization endpoint working",
                    receivedPayload = payload?.ToString() ?? "null"
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = ex.Message,
                    type = ex.GetType().Name
                });
            }
        }
    }
} 