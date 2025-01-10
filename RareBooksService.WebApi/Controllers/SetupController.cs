using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data;
using Microsoft.Extensions.Configuration;
using System.IO;
using System.Text.Json;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SetupController : ControllerBase
    {
        private readonly IWebHostEnvironment _env;
        private readonly IConfiguration _config;
        private readonly IServiceProvider _serviceProvider;
        private readonly ISetupStateService _setupStateService;

        public SetupController(
            IWebHostEnvironment env,
            IConfiguration config,
            IServiceProvider serviceProvider,
            ISetupStateService setupStateService)
        {
            _env = env;
            _config = config;
            _serviceProvider = serviceProvider;
            _setupStateService = setupStateService;
        }

        public class SetupDto
        {
            public string AdminEmail { get; set; }       // для создания админа
            public string AdminPassword { get; set; }
            public string ConnectionString { get; set; } // для DefaultConnection

            // Новые поля для JWT
            public string JwtKey { get; set; }
            public string JwtIssuer { get; set; }
            public string JwtAudience { get; set; }
        }
        // Внутри SetupController
        [HttpGet("")]
        public IActionResult GetSetupPage()
        {
            // Если уже настроена — возвращаем ошибку
            if (!_setupStateService.IsInitialSetupNeeded)
                return StatusCode(StatusCodes.Status403Forbidden,
                    new { success = false, message = "System is already configured. Re-initialization is not allowed." });
            // Можно отдать тот же index.html из InitialSetup/ 
            var filePath = Path.Combine(_env.ContentRootPath, "InitialSetup", "index.html");
            if (System.IO.File.Exists(filePath))
            {
                return PhysicalFile(filePath, "text/html; charset=utf-8");
            }
            return NotFound("Initial setup page not found. Please contact admin.");
        }


        [HttpPost("initialize")]
        public async Task<IActionResult> Initialize([FromBody] SetupDto dto)
        {
            // Если уже настроена — возвращаем ошибку
            if (!_setupStateService.IsInitialSetupNeeded)
                return StatusCode(StatusCodes.Status403Forbidden,
                    new { success = false, message = "System is already configured. Re-initialization is not allowed." });

            // 1) Сохраняем ConnectionString + Jwt
            // 2) Миграции
            // 3) Создаем admin
            // 4) Перезапуск

            // 1) Сохраняем настройки
            var err = await SaveSettingsToAppSettings(dto);
            if (!string.IsNullOrEmpty(err))
            {
                return BadRequest(new { success = false, message = $"SaveSettings error: {err}" });
            }

            // 2) Миграция
            err = await RunMigrations(dto.ConnectionString);
            if (!string.IsNullOrEmpty(err))
            {
                return BadRequest(new { success = false, message = $"RunMigrations error: {err}" });
            }

            // 3) Создаем администратора
            err = await CreateAdmin(dto.AdminEmail, dto.AdminPassword, dto.ConnectionString);
            if (!string.IsNullOrEmpty(err))
            {
                return BadRequest(new { success = false, message = $"CreateAdmin error: {err}" });
            }

            // Обновляем состояние, возможно
            _setupStateService.DetermineIfSetupNeeded();

            // 4) Перезапуск
            ForceRestart();

            return Ok(new { success = true, message = "Initialization in progress. The server will restart now." });
        }

        /// <summary>
        /// Записываем ConnectionString и Jwt поля в appsettings.json
        /// </summary>
        private async Task<string> SaveSettingsToAppSettings(SetupDto dto)
        {
            try
            {
                var appSettingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
                if (!System.IO.File.Exists(appSettingsPath))
                {
                    using var _ = System.IO.File.CreateText(appSettingsPath);
                }

                var oldJson = await System.IO.File.ReadAllTextAsync(appSettingsPath);
                if (string.IsNullOrWhiteSpace(oldJson))
                {
                    // Создаём заготовку
                    oldJson = "{\"ConnectionStrings\": {}, \"Jwt\": {}}";
                }

                var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(oldJson)
                           ?? new Dictionary<string, object>();

                // --- ConnectionStrings ---
                if (!dict.ContainsKey("ConnectionStrings"))
                {
                    dict["ConnectionStrings"] = new Dictionary<string, string>();
                }

                var connectionStringsObj = dict["ConnectionStrings"];
                Dictionary<string, string> cstrDict;
                if (connectionStringsObj is JsonElement je)
                {
                    cstrDict = JsonSerializer.Deserialize<Dictionary<string, string>>(je.GetRawText())
                               ?? new Dictionary<string, string>();
                }
                else if (connectionStringsObj is Dictionary<string, string> realDict)
                {
                    cstrDict = realDict;
                }
                else
                {
                    cstrDict = new Dictionary<string, string>();
                }

                cstrDict["DefaultConnection"] = dto.ConnectionString;
                dict["ConnectionStrings"] = cstrDict;

                // --- Jwt ---
                // Аналогично создаём / обновляем секцию Jwt
                var jwtDict = new Dictionary<string, string>
                {
                    ["Key"] = dto.JwtKey ?? "SomeKey",
                    ["Issuer"] = dto.JwtIssuer ?? "https://example.com",
                    ["Audience"] = dto.JwtAudience ?? "https://exampleApp.com"
                };
                dict["Jwt"] = jwtDict;

                var newJson = JsonSerializer.Serialize(dict, new JsonSerializerOptions
                {
                    WriteIndented = true
                });

                await System.IO.File.WriteAllTextAsync(appSettingsPath, newJson);
                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        private async Task<string> RunMigrations(string connectionString)
        {
            try
            {
                var optionsBuilder = new DbContextOptionsBuilder<RegularBaseBooksContext>();
                optionsBuilder.UseNpgsql(connectionString);

                using var ctx = new RegularBaseBooksContext(optionsBuilder.Options);
                await ctx.Database.MigrateAsync();
                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        private async Task<string> CreateAdmin(string email, string password, string newConnectionString)
        {
            try
            {
                // 1) Мини-сервисколлекция
                var services = new ServiceCollection();

                // 2) Логирование
                services.AddLogging();

                // 3) DbContext
                services.AddDbContext<RegularBaseBooksContext>(options =>
                {
                    options.UseNpgsql(newConnectionString);
                });

                // 4) Identity
                services.AddIdentity<ApplicationUser, IdentityRole>()
                        .AddEntityFrameworkStores<RegularBaseBooksContext>()
                        .AddDefaultTokenProviders();

                services.Configure<IdentityOptions>(options =>
                {
                    options.Password.RequireDigit = false;
                    options.Password.RequireLowercase = false;
                    options.Password.RequireNonAlphanumeric = false;
                    options.Password.RequireUppercase = false;
                    options.Password.RequiredLength = 6;
                    options.Password.RequiredUniqueChars = 1;
                });

                var sp = services.BuildServiceProvider();

                using var scope = sp.CreateScope();
                var scopedServices = scope.ServiceProvider;

                var roleManager = scopedServices.GetRequiredService<RoleManager<IdentityRole>>();
                var userManager = scopedServices.GetRequiredService<UserManager<ApplicationUser>>();

                // Создаём роль Admin
                if (!await roleManager.RoleExistsAsync("Admin"))
                {
                    await roleManager.CreateAsync(new IdentityRole("Admin"));
                }

                // Ищем / создаём пользователя
                var existing = await userManager.FindByEmailAsync(email);
                if (existing == null)
                {
                    var adminUser = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        HasSubscription = true,
                        EmailConfirmed = true
                    };
                    var result = await userManager.CreateAsync(adminUser, password);
                    if (!result.Succeeded)
                    {
                        var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                        return $"Failed to create admin user: {errors}";
                    }

                    await userManager.AddToRoleAsync(adminUser, "Admin");
                    adminUser.Role = "Admin";
                    await userManager.UpdateAsync(adminUser);
                }

                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        private void ForceRestart()
        {
            Environment.Exit(0);
        }
    }
}
