using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.FileProviders;
using MayMessenger.Application.Interfaces;
using MayMessenger.Domain.Interfaces;
using MayMessenger.Infrastructure.Data;
using MayMessenger.Infrastructure.Repositories;
using MayMessenger.Infrastructure.Services;
using MayMessenger.API.Hubs;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Configure WebRootPath for background services
builder.Configuration["WebRootPath"] = builder.Environment.WebRootPath;

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Health Checks
builder.Services.AddHealthChecks()
    .AddCheck<MayMessenger.API.HealthChecks.DatabaseHealthCheck>("database")
    .AddCheck<MayMessenger.API.HealthChecks.FirebaseHealthCheck>("firebase");

// Database
var useSqlite = builder.Configuration.GetValue<bool>("UseSqlite", false);
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));
/*{
    if (useSqlite)
    {
        options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection"));
    }
    else
    {
        options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection"));
    }
});*/

// Repositories
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IChatRepository, ChatRepository>();
builder.Services.AddScoped<IMessageRepository, MessageRepository>();
builder.Services.AddScoped<IInviteLinkRepository, InviteLinkRepository>();
builder.Services.AddScoped<IFcmTokenRepository, FcmTokenRepository>();
builder.Services.AddScoped<IContactRepository, ContactRepository>();
builder.Services.AddScoped<IDeliveryReceiptRepository, DeliveryReceiptRepository>();
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();

// Services
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddSingleton<MayMessenger.Application.Services.IFirebaseService, MayMessenger.Application.Services.FirebaseService>();

// Background Services
builder.Services.AddHostedService<MayMessenger.Application.Services.AudioCleanupService>();
builder.Services.AddHostedService<MayMessenger.Application.Services.CleanupInvalidTokensService>();

// JWT Authentication
var jwtSecret = builder.Configuration["Jwt:Secret"] ?? "YourSuperSecretKeyForJWTTokenGeneration123456789";
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "MayMessenger";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "MayMessengerClient";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret))
        };
        
        // For SignalR
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();

// SignalR with custom UserIdProvider
builder.Services.AddSingleton<IUserIdProvider, CustomUserIdProvider>();
builder.Services.AddSignalR();

// CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        // Allow specific origins with credentials for security
        // For development, you can add localhost origins
        policy.WithOrigins(
                "https://messenger.rare-books.ru",
                "https://rare-books.ru",
                "http://localhost:3000",
                "http://localhost:5173",
                "http://localhost:5000",
                "http://localhost:5001",
                "https://localhost:5000",
                "https://localhost:5001",
                "http://127.0.0.1:5000",
                "http://127.0.0.1:5001"
              )
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "MayMessenger.WebApi", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        In = ParameterLocation.Header,
        Description = "Please insert JWT with Bearer into field",
        Name = "Authorization",
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement {
                    {
                        new OpenApiSecurityScheme {
                            Reference = new OpenApiReference {
                                Type = ReferenceType.SecurityScheme,
                                Id = "Bearer"
                            }
                        },
                        new string[] {}
                    }});
});

var app = builder.Build();

// Apply pending migrations automatically on startup
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var logger = services.GetRequiredService<ILogger<Program>>();
    
    try
    {
        logger.LogInformation("Checking database connection...");
        var context = services.GetRequiredService<AppDbContext>();
        
        // Test database connection with timeout
        var canConnect = await context.Database.CanConnectAsync();
        if (!canConnect)
        {
            logger.LogError("Cannot connect to database. Please check connection string and ensure database is running.");
            logger.LogWarning("Application will continue to start, but database features will not work.");
        }
        else
        {
            logger.LogInformation("Database connection successful");
            
            // Check for pending migrations
            var pendingMigrations = await context.Database.GetPendingMigrationsAsync();
            if (pendingMigrations.Any())
            {
                logger.LogInformation("Applying {Count} pending database migrations...", pendingMigrations.Count());
                foreach (var migration in pendingMigrations)
                {
                    logger.LogInformation("  - {MigrationName}", migration);
                }
                
                // Apply migrations
                await context.Database.MigrateAsync();
                logger.LogInformation("Database migrations applied successfully");
            }
            else
            {
                logger.LogInformation("Database is up to date. No pending migrations.");
            }
            
            // Initialize database and seed data
            var passwordHasher = services.GetRequiredService<IPasswordHasher>();
            await DbInitializer.InitializeAsync(context, passwordHasher);
            logger.LogInformation("Database initialization completed");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "An error occurred while migrating or initializing the database.");
        logger.LogError("Connection string: {ConnectionString}", 
            builder.Configuration.GetConnectionString("DefaultConnection")?.Replace("Password=", "Password=***"));
        logger.LogWarning("Application will continue to start, but database features may not work properly.");
        // Don't throw - allow app to start so health check can report the issue
    }
}

// Configure the HTTP request pipeline
app.UseSwagger();
app.UseSwaggerUI();

// Health check endpoints
app.MapHealthChecks("/health", new Microsoft.AspNetCore.Diagnostics.HealthChecks.HealthCheckOptions
{
    ResponseWriter = async (context, report) =>
    {
        context.Response.ContentType = "application/json";
        
        var result = new
        {
            status = report.Status.ToString(),
            timestamp = DateTime.UtcNow,
            duration = report.TotalDuration,
            checks = report.Entries.Select(e => new
            {
                name = e.Key,
                status = e.Value.Status.ToString(),
                description = e.Value.Description,
                duration = e.Value.Duration,
                data = e.Value.Data,
                exception = e.Value.Exception?.Message
            })
        };
        
        await context.Response.WriteAsJsonAsync(result);
    }
});

// Simple health check for load balancers
app.MapGet("/health/ready", () => Results.Ok(new { status = "Ready" }));

// Initialize Firebase if config exists
try
{
    var firebaseService = app.Services.GetRequiredService<MayMessenger.Application.Services.IFirebaseService>();
    var configPath = builder.Configuration["Firebase:ConfigPath"] ?? Path.Combine(app.Environment.ContentRootPath, "firebase_config.json");
    
    if (File.Exists(configPath))
    {
        firebaseService.Initialize(configPath);
        app.Logger.LogInformation($"Firebase initialized from {configPath}");
    }
    else
    {
        app.Logger.LogWarning($"Firebase config not found at {configPath}. Push notifications will not be available.");
    }
}
catch (Exception ex)
{
    app.Logger.LogError(ex, "Failed to initialize Firebase");
}

// Закомментировано для локальной разработки по HTTP
// app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseCors("AllowAll");

// Rate limiting middleware
app.UseMiddleware<MayMessenger.API.Middleware.RateLimitingMiddleware>();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<MayMessenger.API.Hubs.ChatHub>("/hubs/chat");

app.Run();
