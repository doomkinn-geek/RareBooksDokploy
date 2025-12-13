---
name: Firebase Push Setup
overview: Создание системы первичной настройки для передачи Firebase Admin SDK секретов и полная реализация push уведомлений в backend и Flutter приложении с интеграцией через SignalR.
todos: []
---

# Реализация Firebase Push Notifications для May Messenger

## Архитектура решения

```mermaid
flowchart TB
    Admin[Администратор] -->|1. Загружает Firebase JSON| SetupPage[Setup Page]
    SetupPage -->|2. POST /api/setup/initialize| SetupController
    SetupController -->|3. Сохраняет в appsettings.json| AppSettings[appsettings.json]
    SetupController -->|4. Инициализирует| FirebaseApp[Firebase Admin SDK]
    
    FlutterApp[Flutter App] -->|FCM Token| RegisterToken[/api/notifications/register-token]
    RegisterToken --> TokenStore[(Token Storage)]
    
    User[Пользователь] -->|Отправляет сообщение| Backend[Backend API]
    Backend -->|SignalR Broadcast| AllUsers[Все участники чата]
    Backend -->|Проверяет offline| TokenStore
    Backend -->|Отправляет Push| FCM[Firebase Cloud Messaging]
    FCM --> OfflineDevice[Устройство оффлайн пользователя]
```

## 1. Backend Setup System

### 1.1 SetupController и HTML страница

Создание контроллера аналогичного [`RareBooksService.WebApi/Controllers/SetupController.cs`](c:/rarebooks/RareBooksService.WebApi/Controllers/SetupController.cs) с адаптацией для May Messenger:

**Файл:** [`_may_messenger_backend/src/MayMessenger.API/Controllers/SetupController.cs`](_may_messenger_backend/src/MayMessenger.API/Controllers/SetupController.cs)

Функционал:

- `GET /api/setup` - отдает HTML страницу (только если система не настроена)
- `GET /api/setup/status` - проверка статуса инициализации
- `POST /api/setup/initialize` - прием и сохранение настроек

**DTO для SetupDto:**

```csharp
public class SetupDto
{
    // Существующие
    public string AdminEmail { get; set; }
    public string AdminPassword { get; set; }
    public string JwtSecret { get; set; }
    public string JwtIssuer { get; set; }
    public string JwtAudience { get; set; }
    public string ConnectionString { get; set; }
    
    // Новые для Firebase
    public string FirebaseProjectId { get; set; }
    public string FirebasePrivateKeyId { get; set; }
    public string FirebasePrivateKey { get; set; }
    public string FirebaseClientEmail { get; set; }
    public string FirebaseClientId { get; set; }
    public string FirebaseAuthUri { get; set; }
    public string FirebaseTokenUri { get; set; }
    public string FirebaseAuthProviderX509CertUrl { get; set; }
    public string FirebaseClientX509CertUrl { get; set; }
}
```

**HTML страница:** [`_may_messenger_backend/src/MayMessenger.API/InitialSetup/index.html`](_may_messenger_backend/src/MayMessenger.API/InitialSetup/index.html)

Аналогична [`RareBooksService.WebApi/InitialSetup/index.html`](c:/rarebooks/RareBooksService.WebApi/InitialSetup/index.html) с добавлением секции Firebase:

```html
<div class="section">
    <h3>Firebase Admin SDK</h3>
    <div>
        <label>Firebase JSON (вставьте содержимое файла):</label>
        <textarea name="firebaseJson" rows="10" required></textarea>
        <div class="field-description">
          Содержимое firebase-adminsdk-xxxxx.json из Firebase Console
        </div>
    </div>
</div>
```

JavaScript парсит JSON и заполняет отдельные поля DTO.

### 1.2 Сервис состояния Setup

**Файл:** [`_may_messenger_backend/src/MayMessenger.API/Services/SetupStateService.cs`](_may_messenger_backend/src/MayMessenger.API/Services/SetupStateService.cs)

```csharp
public interface ISetupStateService
{
    bool IsInitialSetupNeeded { get; }
    void DetermineIfSetupNeeded();
}

public class SetupStateService : ISetupStateService
{
    private bool _isSetupNeeded;
    private readonly IConfiguration _configuration;

    public SetupStateService(IConfiguration configuration)
    {
        _configuration = configuration;
        DetermineIfSetupNeeded();
    }

    public bool IsInitialSetupNeeded => _isSetupNeeded;

    public void DetermineIfSetupNeeded()
    {
        // Проверяем наличие критичных настроек
        var jwtSecret = _configuration["Jwt:Secret"];
        var connStr = _configuration.GetConnectionString("DefaultConnection");
        var firebaseProjectId = _configuration["Firebase:ProjectId"];
        
        _isSetupNeeded = string.IsNullOrEmpty(jwtSecret) 
                      || string.IsNullOrEmpty(connStr)
                      || string.IsNullOrEmpty(firebaseProjectId);
    }
}
```

Регистрация в `Program.cs`:

```csharp
builder.Services.AddSingleton<ISetupStateService, SetupStateService>();
```

### 1.3 Middleware для редиректа на Setup

**Файл:** [`_may_messenger_backend/src/MayMessenger.API/Middleware/SetupRedirectMiddleware.cs`](_may_messenger_backend/src/MayMessenger.API/Middleware/SetupRedirectMiddleware.cs)

```csharp
public class SetupRedirectMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ISetupStateService _setupStateService;

    public SetupRedirectMiddleware(RequestDelegate next, ISetupStateService setupStateService)
    {
        _next = next;
        _setupStateService = setupStateService;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Разрешаем доступ к /api/setup и статическим файлам
        if (context.Request.Path.StartsWithSegments("/api/setup") ||
            context.Request.Path.StartsWithSegments("/health"))
        {
            await _next(context);
            return;
        }

        // Если setup нужен - редирект
        if (_setupStateService.IsInitialSetupNeeded)
        {
            context.Response.Redirect("/api/setup");
            return;
        }

        await _next(context);
    }
}
```

## 2. Firebase Admin SDK Integration

### 2.1 NuGet пакеты

Добавить в [`MayMessenger.API.csproj`](_may_messenger_backend/src/MayMessenger.API/MayMessenger.API.csproj):

```xml
<PackageReference Include="FirebaseAdmin" Version="3.0.1" />
```

### 2.2 Firebase Service

**Файл:** [`_may_messenger_backend/src/MayMessenger.Application/Services/FirebaseService.cs`](_may_messenger_backend/src/MayMessenger.Application/Services/FirebaseService.cs)

```csharp
public interface IFirebaseService
{
    Task SendNotificationAsync(string fcmToken, string title, string body, Dictionary<string, string>? data = null);
    Task SendMulticastAsync(List<string> tokens, string title, string body, Dictionary<string, string>? data = null);
}

public class FirebaseService : IFirebaseService
{
    private readonly ILogger<FirebaseService> _logger;
    private bool _isInitialized;

    public FirebaseService(IConfiguration configuration, ILogger<FirebaseService> logger)
    {
        _logger = logger;
        InitializeFirebase(configuration);
    }

    private void InitializeFirebase(IConfiguration configuration)
    {
        try
        {
            if (FirebaseApp.DefaultInstance != null)
            {
                _isInitialized = true;
                return;
            }

            var projectId = configuration["Firebase:ProjectId"];
            var privateKey = configuration["Firebase:PrivateKey"];
            var clientEmail = configuration["Firebase:ClientEmail"];

            if (string.IsNullOrEmpty(projectId))
            {
                _logger.LogWarning("Firebase not configured");
                return;
            }

            // Восстанавливаем переносы строк в private key
            privateKey = privateKey?.Replace("\\n", "\n");

            var credential = GoogleCredential.FromJson(JsonSerializer.Serialize(new
            {
                type = "service_account",
                project_id = projectId,
                private_key_id = configuration["Firebase:PrivateKeyId"],
                private_key = privateKey,
                client_email = clientEmail,
                client_id = configuration["Firebase:ClientId"],
                auth_uri = configuration["Firebase:AuthUri"] ?? "https://accounts.google.com/o/oauth2/auth",
                token_uri = configuration["Firebase:TokenUri"] ?? "https://oauth2.googleapis.com/token",
                auth_provider_x509_cert_url = configuration["Firebase:AuthProviderX509CertUrl"] ?? "https://www.googleapis.com/oauth2/v1/certs",
                client_x509_cert_url = configuration["Firebase:ClientX509CertUrl"]
            }));

            FirebaseApp.Create(new AppOptions
            {
                Credential = credential,
                ProjectId = projectId
            });

            _isInitialized = true;
            _logger.LogInformation("Firebase Admin SDK initialized");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to initialize Firebase");
        }
    }

    public async Task SendNotificationAsync(string fcmToken, string title, string body, Dictionary<string, string>? data = null)
    {
        if (!_isInitialized)
        {
            _logger.LogWarning("Firebase not initialized, skipping notification");
            return;
        }

        try
        {
            var message = new Message
            {
                Token = fcmToken,
                Notification = new Notification
                {
                    Title = title,
                    Body = body
                },
                Data = data ?? new Dictionary<string, string>(),
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        Sound = "default",
                        ChannelId = "messages_channel"
                    }
                },
                Apns = new ApnsConfig
                {
                    Aps = new Aps
                    {
                        Sound = "default",
                        Badge = 1
                    }
                }
            };

            var result = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation($"Notification sent successfully: {result}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Failed to send notification to token {fcmToken}");
        }
    }

    public async Task SendMulticastAsync(List<string> tokens, string title, string body, Dictionary<string, string>? data = null)
    {
        if (!_isInitialized || tokens.Count == 0)
        {
            return;
        }

        try
        {
            var message = new MulticastMessage
            {
                Tokens = tokens,
                Notification = new Notification
                {
                    Title = title,
                    Body = body
                },
                Data = data ?? new Dictionary<string, string>()
            };

            var result = await FirebaseMessaging.DefaultInstance.SendMulticastAsync(message);
            _logger.LogInformation($"Multicast sent: {result.SuccessCount} success, {result.FailureCount} failures");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send multicast notification");
        }
    }
}
```

Регистрация:

```csharp
builder.Services.AddSingleton<IFirebaseService, FirebaseService>();
```

## 3. Token Storage и Management

### 3.1 Database Entity

**Файл:** [`_may_messenger_backend/src/MayMessenger.Domain/Entities/UserDevice.cs`](_may_messenger_backend/src/MayMessenger.Domain/Entities/UserDevice.cs)(_may_messenger