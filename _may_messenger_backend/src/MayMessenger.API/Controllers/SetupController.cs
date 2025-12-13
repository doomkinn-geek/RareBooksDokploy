using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/messenger/[controller]")]
public class SetupController : ControllerBase
{
    private readonly IWebHostEnvironment _env;
    private readonly IConfiguration _config;
    private readonly ILogger<SetupController> _logger;

    public SetupController(
        IWebHostEnvironment env,
        IConfiguration config,
        ILogger<SetupController> logger)
    {
        _env = env;
        _config = config;
        _logger = logger;
    }

    public class FirebaseSetupDto
    {
        public string ServiceAccountJson { get; set; } = "";
    }

    /// <summary>Проверка состояния инициализации Firebase.</summary>
    [HttpGet("status")]
    public IActionResult GetSetupStatus()
    {
        var configPath = GetFirebaseConfigPath();
        var isSetupNeeded = !System.IO.File.Exists(configPath);
        
        return Ok(new
        {
            isSetupNeeded,
            message = isSetupNeeded ? "Firebase setup is required" : "Firebase is already configured",
            configPath
        });
    }

    /// <summary>Отдаёт страницу инициализации Firebase.</summary>
    [HttpGet("")]
    [HttpGet("index")]
    public IActionResult GetSetupPage()
    {
        var configPath = GetFirebaseConfigPath();
        if (System.IO.File.Exists(configPath))
        {
            return StatusCode(StatusCodes.Status403Forbidden,
                new { success = false, message = "Firebase is already configured." });
        }

        var filePath = Path.Combine(_env.ContentRootPath, "FirebaseSetup", "index.html");
        if (System.IO.File.Exists(filePath))
        {
            return PhysicalFile(filePath, "text/html; charset=utf-8");
        }
        return NotFound("Firebase setup page not found. Please contact admin.");
    }

    /// <summary>Основной метод инициализации Firebase.</summary>
    [HttpPost("initialize")]
    public async Task<IActionResult> Initialize([FromBody] FirebaseSetupDto dto)
    {
        try
        {
            var configPath = GetFirebaseConfigPath();
            
            // Если уже настроено
            if (System.IO.File.Exists(configPath))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    success = false,
                    message = "Firebase is already configured. Re-initialization is not allowed."
                });
            }

            // 1. Валидация JSON
            if (string.IsNullOrWhiteSpace(dto.ServiceAccountJson))
            {
                return BadRequest(new { success = false, message = "Service Account JSON is required" });
            }

            JsonDocument? parsedJson = null;
            try
            {
                parsedJson = JsonDocument.Parse(dto.ServiceAccountJson);
            }
            catch (JsonException ex)
            {
                return BadRequest(new { success = false, message = $"Invalid JSON: {ex.Message}" });
            }

            // 2. Проверка обязательных полей
            var root = parsedJson.RootElement;
            var requiredFields = new[] { "type", "project_id", "private_key", "client_email" };
            var missingFields = requiredFields.Where(field => !root.TryGetProperty(field, out _)).ToList();

            if (missingFields.Any())
            {
                return BadRequest(new
                {
                    success = false,
                    message = $"Missing required fields: {string.Join(", ", missingFields)}"
                });
            }

            if (root.GetProperty("type").GetString() != "service_account")
            {
                return BadRequest(new
                {
                    success = false,
                    message = "Invalid service account type. Expected 'service_account'"
                });
            }

            // 3. Сохранение конфигурации
            var configDir = Path.GetDirectoryName(configPath);
            if (!string.IsNullOrEmpty(configDir) && !Directory.Exists(configDir))
            {
                Directory.CreateDirectory(configDir);
            }

            await System.IO.File.WriteAllTextAsync(configPath, dto.ServiceAccountJson);
            _logger.LogInformation($"Firebase config saved to {configPath}");

            // 4. Попытка инициализации Firebase (будет выполнена при следующем запуске приложения)
            var projectId = root.GetProperty("project_id").GetString();
            var clientEmail = root.GetProperty("client_email").GetString();

            _logger.LogInformation($"Firebase initialized for project: {projectId}");

            return Ok(new
            {
                success = true,
                message = "Firebase configuration saved successfully. Restart the application to activate.",
                projectId,
                clientEmail
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during Firebase initialization");
            return StatusCode(500, new
            {
                success = false,
                message = $"Unexpected error during initialization: {ex.Message}",
                details = ex.StackTrace
            });
        }
    }

    private string GetFirebaseConfigPath()
    {
        // Prefer configuration from appsettings
        var configPath = _config["Firebase:ConfigPath"];
        
        if (string.IsNullOrEmpty(configPath))
        {
            // Default fallback
            configPath = Path.Combine(_env.ContentRootPath, "firebase_config.json");
        }

        return configPath;
    }
}
