using Microsoft.AspNetCore.Mvc;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DiagnosticsController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<DiagnosticsController> _logger;
    private static readonly List<string> _recentLogs = new();
    private static readonly object _logLock = new();

    public DiagnosticsController(IUnitOfWork unitOfWork, ILogger<DiagnosticsController> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public static void AddLog(string log)
    {
        lock (_logLock)
        {
            _recentLogs.Add($"[{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss.fff}] {log}");
            if (_recentLogs.Count > 100)
            {
                _recentLogs.RemoveAt(0);
            }
        }
    }

    [HttpGet("logs")]
    public ActionResult<IEnumerable<string>> GetLogs()
    {
        lock (_logLock)
        {
            return Ok(_recentLogs.ToList());
        }
    }

    [HttpDelete("logs")]
    public ActionResult ClearLogs()
    {
        lock (_logLock)
        {
            _recentLogs.Clear();
        }
        return Ok(new { message = "Logs cleared" });
    }

    [HttpGet("health")]
    public async Task<ActionResult> GetHealth()
    {
        try
        {
            var usersCount = (await _unitOfWork.Users.GetAllAsync()).Count();
            var chatsCount = (await _unitOfWork.Chats.GetAllAsync()).Count();

            return Ok(new
            {
                status = "Healthy",
                timestamp = DateTime.UtcNow,
                database = new
                {
                    connected = true,
                    usersCount,
                    chatsCount
                }
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new
            {
                status = "Unhealthy",
                error = ex.Message
            });
        }
    }
}

