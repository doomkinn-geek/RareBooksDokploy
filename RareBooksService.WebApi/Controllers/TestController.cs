using Microsoft.AspNetCore.Mvc;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TestController : ControllerBase
    {
        private readonly ISetupStateService _setupStateService;
        private readonly ILogger<TestController> _logger;

        public TestController(ISetupStateService setupStateService, ILogger<TestController> logger)
        {
            _setupStateService = setupStateService;
            _logger = logger;
        }

        [HttpGet("setup-status")]
        public IActionResult GetSetupStatus()
        {
            var timestamp = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff");
            
            Console.WriteLine($"[{timestamp}] [TestController] ======== GetSetupStatus CALLED ========");
            Console.WriteLine($"[{timestamp}] [TestController] Method: {Request.Method}");
            Console.WriteLine($"[{timestamp}] [TestController] Path: {Request.Path}");
            Console.WriteLine($"[{timestamp}] [TestController] Headers:");
            foreach (var header in Request.Headers.Take(5))
            {
                Console.WriteLine($"[{timestamp}] [TestController]   {header.Key}: {string.Join(", ", header.Value)}");
            }
            
            _logger.LogInformation("TestController.GetSetupStatus called at {Timestamp}", timestamp);
            
            try
            {
                var result = new 
                { 
                    success = true, 
                    message = "Test endpoint working - ASP.NET Core app is running",
                    timestamp = DateTime.UtcNow,
                    isSetupNeeded = _setupStateService.IsInitialSetupNeeded,
                    controllerExecuted = true,
                    requestInfo = new
                    {
                        method = Request.Method,
                        path = Request.Path.ToString(),
                        host = Request.Host.ToString(),
                        scheme = Request.Scheme,
                        contentType = Request.ContentType
                    },
                    diagnostics = new
                    {
                        serverStatus = "OK",
                        middlewareBypass = "Working",
                        aspNetCoreRunning = true
                    }
                };
                
                Console.WriteLine($"[{timestamp}] [TestController] Returning successful response");
                return Ok(result);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[{timestamp}] [TestController] Exception: {ex.Message}");
                _logger.LogError(ex, "Error in GetSetupStatus");
                
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = ex.Message,
                    type = ex.GetType().Name,
                    timestamp = timestamp
                });
            }
        }

        [HttpPost("test-initialize")]
        public IActionResult TestInitialize([FromBody] object payload)
        {
            var timestamp = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff");
            
            Console.WriteLine($"[{timestamp}] [TestController] ======== TestInitialize CALLED ========");
            Console.WriteLine($"[{timestamp}] [TestController] Method: {Request.Method}");
            Console.WriteLine($"[{timestamp}] [TestController] Path: {Request.Path}");
            Console.WriteLine($"[{timestamp}] [TestController] ContentType: {Request.ContentType}");
            
            _logger.LogInformation("TestController.TestInitialize called at {Timestamp}", timestamp);
            
            try
            {
                var result = new 
                { 
                    success = true, 
                    message = "POST request to /api/test/test-initialize working - ASP.NET Core app processing POST",
                    timestamp = DateTime.UtcNow,
                    receivedPayload = payload?.ToString() ?? "null",
                    controllerExecuted = true,
                    methodType = "POST",
                    note = "This proves POST requests reach the application when nginx allows them"
                };
                
                Console.WriteLine($"[{timestamp}] [TestController] POST test successful, returning response");
                return Ok(result);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[{timestamp}] [TestController] POST test exception: {ex.Message}");
                _logger.LogError(ex, "Error in TestInitialize");
                
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = ex.Message,
                    type = ex.GetType().Name,
                    timestamp = timestamp
                });
            }
        }

        /// <summary>Простой GET endpoint для диагностики маршрутизации</summary>
        [HttpGet("ping")]
        public IActionResult Ping()
        {
            var timestamp = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff");
            
            Console.WriteLine($"[{timestamp}] [TestController] ======== PING CALLED ========");
            _logger.LogInformation("TestController.Ping called");
            
            return Ok(new 
            { 
                success = true, 
                message = "PONG - ASP.NET Core is alive",
                timestamp = DateTime.UtcNow,
                controllerReached = true
            });
        }

        /// <summary>Простой POST endpoint для диагностики</summary>
        [HttpPost("ping")]
        public IActionResult PingPost([FromBody] object data)
        {
            var timestamp = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff");
            
            Console.WriteLine($"[{timestamp}] [TestController] ======== PING POST CALLED ========");
            _logger.LogInformation("TestController.PingPost called");
            
            return Ok(new 
            { 
                success = true, 
                message = "PONG POST - ASP.NET Core received POST request",
                timestamp = DateTime.UtcNow,
                controllerReached = true,
                data = data?.ToString() ?? "null"
            });
        }
    }
} 