# Health Checks Guide

## Overview

May Messenger backend includes comprehensive health checks for monitoring system health and dependencies.

## Endpoints

### Detailed Health Check
```
GET /health
```

Returns detailed information about all system components:

```json
{
  "status": "Healthy",
  "timestamp": "2024-12-18T10:30:00Z",
  "duration": "00:00:00.1234567",
  "checks": [
    {
      "name": "database",
      "status": "Healthy",
      "description": "Database is healthy",
      "duration": "00:00:00.0500000",
      "data": {
        "database": "PostgreSQL",
        "status": "Connected",
        "userCount": 42
      },
      "exception": null
    },
    {
      "name": "firebase",
      "status": "Healthy",
      "description": "Firebase is initialized and ready",
      "duration": "00:00:00.0010000",
      "data": {
        "service": "Firebase Admin SDK",
        "initialized": true
      },
      "exception": null
    }
  ]
}
```

### Simple Readiness Check
```
GET /health/ready
```

Returns simple response for load balancers:

```json
{
  "status": "Ready"
}
```

## Health Check Components

### 1. Database Health Check

**File**: `HealthChecks/DatabaseHealthCheck.cs`

**Checks**:
- Database connection
- Ability to query tables
- Counts users for basic validation

**Status Codes**:
- `Healthy`: Database is accessible and responsive
- `Unhealthy`: Cannot connect or query database

### 2. Firebase Health Check

**File**: `HealthChecks/FirebaseHealthCheck.cs`

**Checks**:
- Firebase Admin SDK initialization status

**Status Codes**:
- `Healthy`: Firebase is initialized
- `Degraded`: Firebase not initialized (push notifications unavailable)
- `Unhealthy`: Error checking Firebase status

## Health Status Levels

- **Healthy**: Everything is working normally
- **Degraded**: System is functional but some features may be limited
- **Unhealthy**: Critical component is down

## Integration with Monitoring

### Kubernetes Liveness & Readiness Probes

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: maymessenger-api
spec:
  containers:
  - name: api
    image: maymessenger/api:latest
    livenessProbe:
      httpGet:
        path: /health/ready
        port: 5000
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /health
        port: 5000
      initialDelaySeconds: 10
      periodSeconds: 5
```

### Docker Compose Health Checks

```yaml
services:
  maymessenger_backend:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

### Azure Application Insights

Health check results are automatically logged and can be monitored:

```csharp
// Already configured via AddHealthChecks()
```

### Prometheus Metrics

Add health check metrics exporter:

```csharp
builder.Services.AddHealthChecksUI()
    .AddInMemoryStorage();

app.UseHealthChecksPrometheusExporter("/health/metrics");
```

## Monitoring Best Practices

### 1. Alert on Unhealthy Status

Set up alerts when health checks fail:

```bash
# Example: Check health every minute
*/1 * * * * curl -f http://messenger.rare-books.ru/health || echo "Health check failed" | mail -s "Alert" admin@example.com
```

### 2. Log Health Check Results

Health check results are automatically logged by the system.

### 3. Dashboard

Create a dashboard showing:
- Current health status
- Historical uptime
- Response times
- Error rates

### 4. Load Balancer Configuration

Configure load balancer to remove unhealthy instances:

**Nginx**:
```nginx
upstream maymessenger_backend {
    server backend1:5000 max_fails=3 fail_timeout=30s;
    server backend2:5000 max_fails=3 fail_timeout=30s;
    
    check interval=10000 rise=2 fall=3 timeout=5000 type=http;
    check_http_send "GET /health/ready HTTP/1.0\r\n\r\n";
    check_http_expect_alive http_2xx http_3xx;
}
```

## Adding Custom Health Checks

### Example: SignalR Health Check

```csharp
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.SignalR;

public class SignalRHealthCheck : IHealthCheck
{
    private readonly IHubContext<ChatHub> _hubContext;
    private readonly ILogger<SignalRHealthCheck> _logger;

    public SignalRHealthCheck(
        IHubContext<ChatHub> hubContext,
        ILogger<SignalRHealthCheck> logger)
    {
        _hubContext = hubContext;
        _logger = logger;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Check if SignalR hub is responsive
            // In real implementation, you might ping a test client
            
            var data = new Dictionary<string, object>
            {
                { "service", "SignalR" },
                { "status", "Operational" }
            };

            return HealthCheckResult.Healthy("SignalR is operational", data);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "SignalR health check failed");
            return HealthCheckResult.Unhealthy("SignalR health check failed", ex);
        }
    }
}
```

Register in `Program.cs`:

```csharp
builder.Services.AddHealthChecks()
    .AddCheck<DatabaseHealthCheck>("database")
    .AddCheck<FirebaseHealthCheck>("firebase")
    .AddCheck<SignalRHealthCheck>("signalr");
```

## Testing Health Checks

### Manual Testing

```bash
# Detailed health check
curl http://localhost:5000/health | jq .

# Simple readiness check
curl http://localhost:5000/health/ready
```

### Automated Testing

```csharp
[Fact]
public async Task HealthCheck_ShouldReturn_Healthy()
{
    // Arrange
    var factory = new WebApplicationFactory<Program>();
    var client = factory.CreateClient();

    // Act
    var response = await client.GetAsync("/health");

    // Assert
    response.EnsureSuccessStatusCode();
    var content = await response.Content.ReadAsStringAsync();
    Assert.Contains("Healthy", content);
}
```

## Troubleshooting

### Database Health Check Fails

1. Check PostgreSQL is running
2. Verify connection string in appsettings.json
3. Check network connectivity
4. Verify database credentials

```bash
# Test PostgreSQL connection
psql -h localhost -U postgres -d maymessenger -c "SELECT 1"
```

### Firebase Health Check Degraded

1. Check if `firebase_config.json` exists
2. Verify Firebase Admin SDK credentials
3. Initialize Firebase via `/messenger/setup/` if needed

### All Health Checks Timeout

1. Check application is running
2. Verify port 5000 is accessible
3. Check application logs for startup errors
4. Ensure database migrations are applied

## Production Recommendations

1. **Monitor health checks** in production with alerts
2. **Set up redundancy** - run multiple instances
3. **Use load balancer** health checks to route traffic
4. **Log health check failures** for post-mortem analysis
5. **Create runbooks** for common health check failures
6. **Test failover** scenarios regularly

## Health Check Response Codes

- **200 OK**: All systems healthy
- **200 OK (Degraded)**: System operational but degraded
- **503 Service Unavailable**: Critical component unhealthy

The detailed `/health` endpoint always returns 200 but includes status in the body.

