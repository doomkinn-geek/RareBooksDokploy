using Microsoft.AspNetCore.Mvc;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TestController : ControllerBase
    {
        [HttpGet("setup-status")]
        public IActionResult GetSetupStatus()
        {
            try
            {
                return Ok(new 
                { 
                    success = true, 
                    message = "Test endpoint working",
                    timestamp = DateTime.UtcNow
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