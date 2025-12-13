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

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Database
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Repositories
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IChatRepository, ChatRepository>();
builder.Services.AddScoped<IMessageRepository, MessageRepository>();
builder.Services.AddScoped<IInviteLinkRepository, InviteLinkRepository>();
builder.Services.AddScoped<IFcmTokenRepository, FcmTokenRepository>();
builder.Services.AddScoped<IUnitOfWork, UnitOfWork>();

// Services
builder.Services.AddScoped<IPasswordHasher, PasswordHasher>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddSingleton<MayMessenger.Application.Services.IFirebaseService, MayMessenger.Application.Services.FirebaseService>();

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
                "http://localhost:5173"
              )
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

var app = builder.Build();

// Initialize database and seed data
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<AppDbContext>();
        var passwordHasher = services.GetRequiredService<IPasswordHasher>();
        await DbInitializer.InitializeAsync(context, passwordHasher);
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogError(ex, "An error occurred while initializing the database.");
    }
}

// Configure the HTTP request pipeline
app.UseSwagger();
app.UseSwaggerUI();

// Health check endpoint
app.MapGet("/health", () => Results.Ok(new { status = "Healthy" }));

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

app.UseHttpsRedirection();
app.UseStaticFiles();

app.UseCors("AllowAll");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<MayMessenger.API.Hubs.ChatHub>("/hubs/chat");

app.Run();
