# Предложения по улучшению архитектуры May Messenger

## 1. Переход к микросервисной архитектуре

### Текущая проблема
Все компоненты (API, SignalR, медиа-обработка) работают в одном ASP.NET Core приложении, что создает узкое место для масштабирования.

### Предлагаемое решение

#### 1.1 Разделение на отдельные сервисы
```
may-messenger/
├── api-gateway/           # API Gateway (Ocelot/YARP)
├── auth-service/          # Аутентификация и авторизация
├── chat-service/          # Управление чатами и сообщениями
├── realtime-service/      # SignalR хаб (ASP.NET Core SignalR)
├── media-service/         # Загрузка и обработка медиа
├── notification-service/  # Push-уведомления (Node.js)
├── search-service/        # Полнотекстовый поиск (Elasticsearch)
└── user-service/          # Управление пользователями
```

#### 1.2 Преимущества
- **Независимое масштабирование** каждого сервиса
- **Технологическая гибкость** - разные сервисы могут использовать разные технологии
- **Улучшенная отказоустойчивость** - сбой одного сервиса не влияет на остальные
- **Командная автономия** - разные команды могут работать над разными сервисами

#### 1.3 API Gateway
```csharp
// Ocelot configuration
{
  "Routes": [
    {
      "DownstreamPathTemplate": "/api/auth/{everything}",
      "DownstreamScheme": "http",
      "DownstreamHostAndPorts": [
        {
          "Host": "auth-service",
          "Port": 80
        }
      ],
      "UpstreamPathTemplate": "/api/auth/{everything}",
      "UpstreamHttpMethod": [ "GET", "POST", "PUT", "DELETE" ]
    }
  ]
}
```

## 2. Масштабируемость базы данных

### Текущая проблема
Единая PostgreSQL база данных станет bottleneck при росте нагрузки.

### Предлагаемое решение

#### 2.1 Шардирование по пользователям
```sql
-- Шардирование по user_id (hash-based)
CREATE TABLE messages_0 PARTITION OF messages
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE messages_1 PARTITION OF messages
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
-- ... и т.д.
```

#### 2.2 Read Replicas для поиска
```yaml
# Читать из реплики для поиска
search_service:
  environment:
    - DATABASE_URL=postgresql://user:pass@db_replica:5432/maymessenger
```

#### 2.3 Кэширование с Redis
```csharp
// Distributed caching для пользовательских данных
builder.Services.AddStackExchangeRedisCache(options =>
{
    options.Configuration = "redis:6379";
});

// Session storage для SignalR
builder.Services.AddSignalR().AddRedis(options =>
{
    options.Configuration.Endpoints.Add("redis:6379");
});
```

## 3. Оптимизация SignalR

### Текущая проблема
SignalR работает в одном процессе с API, что ограничивает масштабируемость.

### Предлагаемое решение

#### 3.1 Отдельный SignalR сервис
```csharp
// SignalR-only сервис
public class RealtimeHub : Hub
{
    // Только real-time методы
}

builder.Services.AddSignalR(options =>
{
    options.EnableDetailedErrors = false; // Production optimization
    options.MaximumReceiveMessageSize = 32 * 1024; // Limit message size
});
```

#### 3.2 Redis backplane для масштабирования
```csharp
// Redis для распределения SignalR
builder.Services.AddSignalR().AddRedis(options =>
{
    options.Configuration.Endpoints.Add("redis:6379");
});
```

#### 3.3 WebSocket connection limits
```nginx
# Nginx limits для WebSocket
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    location /hubs/ {
        # Limit concurrent connections per IP
        limit_conn conn_limit_per_ip 10;

        # Rate limiting for connection attempts
        limit_req zone=signalr_burst burst=5 nodelay;
    }
}
```

## 4. Медиа-обработка и хранение

### Текущая проблема
Медиафайлы хранятся локально на диске контейнера, что не масштабируется.

### Предлагаемое решение

#### 4.1 Облачное хранилище (AWS S3 / MinIO)
```csharp
// AWS S3 для хранения медиа
builder.Services.AddAWSService<IAmazonS3>();
builder.Services.AddSingleton<IMediaStorage, S3MediaStorage>();

public class S3MediaStorage : IMediaStorage
{
    public async Task<string> UploadFileAsync(Stream stream, string fileName)
    {
        var request = new PutObjectRequest
        {
            BucketName = _bucketName,
            Key = $"{DateTime.UtcNow:yyyy/MM/dd}/{fileName}",
            InputStream = stream,
            ContentType = GetContentType(fileName)
        };

        await _s3Client.PutObjectAsync(request);
        return $"https://{_bucketName}.s3.amazonaws.com/{request.Key}";
    }
}
```

#### 4.2 CDN для доставки
```nginx
# CloudFront / CDN configuration
location /media/ {
    proxy_pass https://cdn.maymessenger.com;
    proxy_cache media_cache;
    expires 30d;
    add_header Cache-Control "public, immutable";
}
```

#### 4.3 Асинхронная обработка изображений
```csharp
// Background processing для изображений
builder.Services.AddHostedService<ImageProcessingService>();

public class ImageProcessingService : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var pendingImages = await _repository.GetPendingImagesAsync();
            foreach (var image in pendingImages)
            {
                await ProcessImageAsync(image);
            }
            await Task.Delay(1000, stoppingToken);
        }
    }
}
```

## 5. Поиск и аналитика

### Текущая проблема
Полнотекстовый поиск ограничен PostgreSQL возможностями.

### Предлагаемое решение

#### 5.1 Elasticsearch для поиска
```csharp
// Elasticsearch клиент
builder.Services.AddSingleton<IElasticClient>(sp =>
{
    var settings = new ConnectionSettings(new Uri("http://elasticsearch:9200"))
        .DefaultIndex("messages");
    return new ElasticClient(settings);
});

// Индексация сообщений
public class MessageIndexer
{
    public async Task IndexMessageAsync(Message message)
    {
        var document = new MessageDocument
        {
            Id = message.Id,
            ChatId = message.ChatId,
            Content = message.Content,
            SenderId = message.SenderId,
            CreatedAt = message.CreatedAt,
            Type = message.Type.ToString()
        };

        await _elasticClient.IndexDocumentAsync(document);
    }
}
```

#### 5.2 Аналитические данные
```sql
-- Таблица для аналитики
CREATE TABLE message_analytics (
    id UUID PRIMARY KEY,
    chat_id UUID NOT NULL,
    message_count BIGINT,
    participant_count INT,
    last_activity TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## 6. Безопасность и compliance

### Текущая проблема
Базовая безопасность реализована, но отсутствуют enterprise-grade возможности.

### Предлагаемое решение

#### 6.1 End-to-end шифрование
```csharp
// Signal Protocol implementation
public class E2EEncryptionService
{
    public async Task<EncryptedMessage> EncryptMessageAsync(
        Message message,
        Guid recipientId)
    {
        var session = await _sessionStore.GetSessionAsync(recipientId);
        var cipher = new SignalCipher(session);
        var encrypted = await cipher.EncryptAsync(message.Content);

        return new EncryptedMessage
        {
            Ciphertext = encrypted.Ciphertext,
            KeyExchangeMessage = encrypted.KeyExchangeMessage
        };
    }
}
```

#### 6.2 Аудит логов
```csharp
// Structured logging with Serilog
builder.Host.UseSerilog((context, config) =>
{
    config.WriteTo.Elasticsearch(
        new ElasticsearchSinkOptions(new Uri("http://elasticsearch:9200"))
        {
            IndexFormat = "maymessenger-audit-{0:yyyy.MM.dd}",
            AutoRegisterTemplate = true
        });
});
```

#### 6.3 Rate limiting per user
```csharp
// User-based rate limiting
builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy("UserMessageLimit", context =>
    {
        var userId = context.User.FindFirst("sub")?.Value;
        return RateLimitPartition.GetTokenBucketLimiter(
            userId,
            _ => new TokenBucketRateLimiterOptions
            {
                TokenLimit = 100,    // 100 messages
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0,      // No queue
                ReplenishmentPeriod = TimeSpan.FromMinutes(1),
                TokensPerPeriod = 10, // 10 per minute
                AutoReplenishment = true
            });
    });
});
```

## 7. Мониторинг и observability

### Текущая проблема
Отсутствует centralized monitoring и alerting.

### Предлагаемое решение

#### 7.1 Distributed tracing
```csharp
// OpenTelemetry для трассировки
builder.Services.AddOpenTelemetryTracing(builder =>
{
    builder.AddAspNetCoreInstrumentation()
           .AddHttpClientInstrumentation()
           .AddJaegerExporter(options =>
           {
               options.AgentHost = "jaeger";
               options.AgentPort = 6831;
           });
});
```

#### 7.2 Metrics collection
```csharp
// Prometheus metrics
builder.Services.AddMetrics();
builder.Services.AddHostedService<PrometheusMetricsService>();

public class PrometheusMetricsService : BackgroundService
{
    private readonly Meter _meter = new("MayMessenger");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var messageCounter = _meter.CreateCounter<long>(
            "messages_sent_total",
            description: "Total number of messages sent");

        var activeConnections = _meter.CreateObservableGauge<int>(
            "signalr_connections_active",
            () => GetActiveConnectionsCount(),
            description: "Number of active SignalR connections");
    }
}
```

#### 7.3 Health checks
```csharp
// Expanded health checks
builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>("database")
    .AddRedis("redis")
    .AddElasticsearch("elasticsearch")
    .AddUrlGroup(new Uri("https://api.maymessenger.com/health"), "external-api");
```

## 8. CI/CD и DevOps

### Текущая проблема
Ручное развертывание, отсутствие automated testing.

### Предлагаемое решение

#### 8.1 GitOps с ArgoCD
```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: may-messenger
spec:
  project: default
  source:
    repoURL: https://github.com/org/may-messenger
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: may-messenger
```

#### 8.2 Automated testing
```yaml
# GitHub Actions workflow
name: CI/CD Pipeline
on:
  push:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run unit tests
        run: dotnet test --collect:"XPlat Code Coverage"
      - name: Run integration tests
        run: docker-compose -f docker-compose.test.yml up --abort-on-container-exit

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to staging
        run: kubectl apply -f k8s/staging/
```

## 9. Производительность и оптимизации

### Текущая проблема
Отсутствуют некоторые оптимизации для высокой нагрузки.

### Предлагаемое решение

#### 9.1 Message queuing
```csharp
// RabbitMQ для асинхронной обработки
builder.Services.AddMassTransit(x =>
{
    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host("rabbitmq://rabbitmq:5672");
    });

    x.AddConsumer<MessageProcessingConsumer>();
});
```

#### 9.2 Response compression
```csharp
// HTTP compression
builder.Services.AddResponseCompression(options =>
{
    options.Providers.Add<GzipCompressionProvider>();
    options.Providers.Add<BrotliCompressionProvider>();
    options.EnableForHttps = true;
});
```

#### 9.3 Database connection pooling
```csharp
// Connection pooling
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString, npgsqlOptions =>
    {
        npgsqlOptions.MaxPoolSize(100);
        npgsqlOptions.MinPoolSize(10);
        npgsqlOptions.ConnectionIdleLifetime(TimeSpan.FromMinutes(5));
    }));
```

## Заключение

Предложенные улучшения позволят May Messenger масштабироваться до миллионов пользователей, обеспечивая высокую доступность, производительность и безопасность. Основные приоритеты для внедрения:

1. **Микросервисы** - фундамент для масштабируемости
2. **База данных** - шардирование и реплики
3. **SignalR** - отдельный сервис с Redis backplane
4. **Медиа** - облачное хранение и CDN
5. **Безопасность** - E2E шифрование
6. **Мониторинг** - полная observability

Каждое улучшение должно внедряться поэтапно с тщательным тестированием и мониторингом производительности.