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
            return Ok(new
            {
                success = true,
                message = _setupStateService.IsInitialSetupNeeded ? "Setup is required" : "System is already configured",
                isInitialSetupNeeded = _setupStateService.IsInitialSetupNeeded
            });
        }

        [HttpGet("ping")]
        public IActionResult Ping()
        {
            return Ok(new
            {
                success = true,
                message = "Pong! API is working."
            });
        }

        [HttpGet("cors-test")]
        public IActionResult CorsTest()
        {
            Response.Headers.Add("Access-Control-Allow-Origin", "*");
            Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
            Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Accept");
            
            return Ok(new
            {
                success = true,
                message = "CORS test successful",
                headers = Request.Headers.ToDictionary(h => h.Key, h => h.Value.ToString())
            });
        }

        [HttpOptions("cors-test")]
        public IActionResult CorsTestOptions()
        {
            Response.Headers.Add("Access-Control-Allow-Origin", "*");
            Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
            Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type, Accept");
            
            return Ok();
        }
    }
}