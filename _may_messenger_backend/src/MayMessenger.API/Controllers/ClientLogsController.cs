using Microsoft.AspNetCore.Mvc;

namespace MayMessenger.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClientLogsController : ControllerBase
{
    private static readonly List<ClientLogEntry> _logs = new();
    private static readonly object _lockObject = new();
    private const int MaxLogEntries = 500;

    [HttpPost]
    public IActionResult PostLog([FromBody] ClientLogEntry log)
    {
        try
        {
            lock (_lockObject)
            {
                _logs.Add(log);
                
                // Keep only last MaxLogEntries
                if (_logs.Count > MaxLogEntries)
                {
                    _logs.RemoveRange(0, _logs.Count - MaxLogEntries);
                }
            }
            
            return Ok(new { success = true });
        }
        catch (Exception ex)
        {
            return BadRequest(new { error = ex.Message });
        }
    }

    [HttpGet]
    public ActionResult<IEnumerable<ClientLogEntry>> GetLogs([FromQuery] int? limit = 100)
    {
        lock (_lockObject)
        {
            var count = Math.Min(limit ?? 100, _logs.Count);
            return Ok(_logs.TakeLast(count).OrderBy(l => l.Timestamp));
        }
    }

    [HttpDelete]
    public IActionResult ClearLogs()
    {
        lock (_lockObject)
        {
            _logs.Clear();
        }
        
        return Ok(new { success = true, message = "Logs cleared" });
    }
}

public class ClientLogEntry
{
    public DateTime Timestamp { get; set; }
    public string Level { get; set; } = "INFO";
    public string Location { get; set; } = "";
    public string Message { get; set; } = "";
    public Dictionary<string, string>? Data { get; set; }
}

