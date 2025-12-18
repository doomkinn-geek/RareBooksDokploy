# Serilog Structured Logging Setup

## Overview

This guide explains how to set up Serilog for structured logging in May Messenger backend.

## Why Serilog?

- **Structured Logging**: Log events as structured data, not just text
- **Multiple Sinks**: Write logs to console, files, databases, etc.
- **Performance**: High-performance logging with minimal overhead
- **Rich Context**: Add contextual properties to all log events

## Installation

Add the following NuGet packages to `MayMessenger.API.csproj`:

```xml
<ItemGroup>
  <PackageReference Include="Serilog.AspNetCore" Version="8.0.0" />
  <PackageReference Include="Serilog.Sinks.Console" Version="5.0.0" />
  <PackageReference Include="Serilog.Sinks.File" Version="5.0.0" />
  <PackageReference Include="Serilog.Sinks.PostgreSQL" Version="2.3.0" />
  <PackageReference Include="Serilog.Enrichers.Environment" Version="2.3.0" />
  <PackageReference Include="Serilog.Enrichers.Thread" Version="3.1.0" />
</ItemGroup>
```

## Configuration in Program.cs

Replace the existing logging configuration with Serilog:

```csharp
using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
    .Enrich.FromLogContext()
    .Enrich.WithEnvironmentName()
    .Enrich.WithMachineName()
    .Enrich.WithThreadId()
    .WriteTo.Console(new JsonFormatter())
    .WriteTo.File(
        new JsonFormatter(),
        "logs/messenger-.log",
        rollingInterval: RollingInterval.Day,
        retainedFileCountLimit: 30,
        buffered: false
    )
    .CreateLogger();

builder.Host.UseSerilog();

// ... rest of configuration
```

## Structured Logging Examples

### In Controllers

```csharp
private readonly ILogger<MessagesController> _logger;

public async Task<ActionResult<MessageDto>> SendMessage([FromBody] SendMessageDto dto)
{
    _logger.LogInformation(
        "Sending message {MessageId} in chat {ChatId} by user {UserId}", 
        message.Id, 
        dto.ChatId, 
        userId
    );
    
    // ... send logic
    
    _logger.LogInformation(
        "Message {MessageId} sent successfully. Type: {MessageType}, Recipients: {RecipientCount}",
        message.Id,
        message.Type,
        chat.Participants.Count
    );
}
```

### In Services

```csharp
private readonly ILogger<FirebaseService> _logger;

public async Task<(bool success, bool shouldDeactivateToken)> SendNotificationAsync(
    string fcmToken,
    string title,
    string body,
    Dictionary<string, string>? data = null)
{
    _logger.LogInformation(
        "Sending FCM notification. Token: {TokenPreview}, Title: {Title}",
        fcmToken.Substring(0, Math.Min(10, fcmToken.Length)) + "...",
        title
    );
    
    try
    {
        var response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
        
        _logger.LogInformation(
            "FCM notification sent successfully. Response: {Response}",
            response
        );
        
        return (true, false);
    }
    catch (FirebaseMessagingException ex)
    {
        _logger.LogError(ex,
            "Failed to send FCM notification. Token: {TokenPreview}, ErrorCode: {ErrorCode}",
            fcmToken.Substring(0, Math.Min(10, fcmToken.Length)) + "...",
            ex.MessagingErrorCode
        );
        
        return (false, ShouldDeactivateToken(ex));
    }
}
```

### Performance Logging

```csharp
using System.Diagnostics;

public async Task<List<Message>> GetChatMessagesAsync(Guid chatId, int skip, int take)
{
    var sw = Stopwatch.StartNew();
    
    var messages = await _context.Messages
        .Where(m => m.ChatId == chatId)
        .OrderByDescending(m => m.CreatedAt)
        .Skip(skip)
        .Take(take)
        .Include(m => m.Sender)
        .ToListAsync();
    
    sw.Stop();
    
    _logger.LogInformation(
        "Retrieved {MessageCount} messages for chat {ChatId}. Query time: {ElapsedMs}ms",
        messages.Count,
        chatId,
        sw.ElapsedMilliseconds
    );
    
    return messages;
}
```

## Contextual Logging with LogContext

Add request context to all logs:

```csharp
// In Program.cs middleware
app.Use(async (context, next) =>
{
    var userId = context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    var requestId = context.TraceIdentifier;
    
    using (LogContext.PushProperty("UserId", userId ?? "anonymous"))
    using (LogContext.PushProperty("RequestId", requestId))
    using (LogContext.PushProperty("RequestPath", context.Request.Path))
    {
        await next();
    }
});
```

Now all logs will automatically include UserId, RequestId, and RequestPath!

## PostgreSQL Sink (Optional)

Store logs in database for advanced querying:

```csharp
.WriteTo.PostgreSQL(
    connectionString: builder.Configuration.GetConnectionString("DefaultConnection"),
    tableName: "Logs",
    needAutoCreateTable: true,
    columnOptions: new Dictionary<string, ColumnWriterBase>
    {
        { "message", new RenderedMessageColumnWriter() },
        { "level", new LevelColumnWriter() },
        { "timestamp", new TimestampColumnWriter() },
        { "exception", new ExceptionColumnWriter() },
        { "properties", new LogEventSerializedColumnWriter() }
    }
)
```

Then query logs with SQL:

```sql
SELECT 
    timestamp,
    level,
    message,
    properties->>'UserId' as user_id,
    properties->>'ChatId' as chat_id,
    exception
FROM "Logs"
WHERE level = 'Error'
  AND timestamp > NOW() - INTERVAL '1 hour'
ORDER BY timestamp DESC;
```

## Log Levels

Use appropriate log levels:

- **Trace**: Very detailed, typically only enabled in development
- **Debug**: Diagnostic information, useful for debugging
- **Information**: General informational messages (default)
- **Warning**: Warnings about potential issues
- **Error**: Errors that need attention but don't crash the app
- **Fatal**: Critical errors that crash the application

## Configuration in appsettings.json

```json
{
  "Serilog": {
    "Using": [ "Serilog.Sinks.Console", "Serilog.Sinks.File" ],
    "MinimumLevel": {
      "Default": "Information",
      "Override": {
        "Microsoft": "Warning",
        "Microsoft.AspNetCore": "Warning",
        "System": "Warning"
      }
    },
    "WriteTo": [
      {
        "Name": "Console",
        "Args": {
          "formatter": "Serilog.Formatting.Json.JsonFormatter, Serilog"
        }
      },
      {
        "Name": "File",
        "Args": {
          "path": "logs/messenger-.log",
          "rollingInterval": "Day",
          "retainedFileCountLimit": 30,
          "formatter": "Serilog.Formatting.Json.JsonFormatter, Serilog"
        }
      }
    ],
    "Enrich": [ "FromLogContext", "WithMachineName", "WithThreadId" ]
  }
}
```

## Viewing Logs

### Development (Console)

Logs are output as JSON to console, easy to read with tools like `jq`:

```bash
dotnet run | jq .
```

### Production (File)

Logs are written to `logs/messenger-YYYYMMDD.log` as JSON:

```bash
# View today's logs
cat logs/messenger-$(date +%Y%m%d).log | jq .

# Filter errors
cat logs/messenger-*.log | jq 'select(.Level == "Error")'

# Find specific user's actions
cat logs/messenger-*.log | jq 'select(.Properties.UserId == "user-id-here")'
```

### Log Analysis Tools

- **Seq**: https://datalust.co/seq (local or cloud)
- **Elasticsearch + Kibana**: Full ELK stack
- **Azure Application Insights**: Cloud monitoring
- **Datadog**: Enterprise monitoring

## Best Practices

1. **Don't log sensitive data**: Never log passwords, tokens, or PII
2. **Use structured properties**: Always use `{PropertyName}` syntax
3. **Be consistent**: Use same property names across the codebase
4. **Include context**: UserId, ChatId, MessageId, etc.
5. **Measure performance**: Log slow operations with timings
6. **Use appropriate levels**: Don't log everything as Information
7. **Handle exceptions properly**: Always include exception in LogError

## Migration from ILogger

Existing `ILogger<T>` code works with Serilog! No code changes needed, but you can enhance it:

```csharp
// Before (still works)
_logger.LogInformation($"Message {messageId} sent");

// After (better - structured)
_logger.LogInformation("Message {MessageId} sent", messageId);
```

## Monitoring Dashboard

Once logs are flowing, you can create dashboards to monitor:

- Message delivery rate
- Error rates by endpoint
- Average response times
- FCM notification success rate
- Database query performance
- SignalR connection status

## Next Steps

1. Install NuGet packages
2. Update Program.cs configuration
3. Test logging in development
4. Deploy to production
5. Set up log analysis tool (Seq recommended for start)
6. Create monitoring dashboards
7. Set up alerting for errors

