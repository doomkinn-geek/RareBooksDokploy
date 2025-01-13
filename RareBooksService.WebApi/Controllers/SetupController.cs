using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using Microsoft.Extensions.Configuration;
using System.IO;
using System.Text.Json;
using RareBooksService.WebApi.Services;
using RareBooksService.Data;

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

        // DTO для входных данных
        public class SetupDto
        {
            public string AdminEmail { get; set; }
            public string AdminPassword { get; set; }
            public string ConnectionString { get; set; }

            // JWT
            public string JwtKey { get; set; }
            public string JwtIssuer { get; set; }
            public string JwtAudience { get; set; }

            // Например, YandexDisk.Token, если нужно
            public string YandexDiskToken { get; set; }

            // TypeOfAccessImages
            public string TypeOfAccessImagesUseLocalFiles { get; set; }
            public string TypeOfAccessImagesLocalPathOfImages { get; set; }

            // YandexCloud
            public string YandexCloudAccessKey { get; set; }
            public string YandexCloudSecretKey { get; set; }
            public string YandexCloudServiceUrl { get; set; }
            public string YandexCloudBucketName { get; set; }
        }

        /// <summary>Отдаёт страницу инициализации.</summary>
        [HttpGet("")]
        public IActionResult GetSetupPage()
        {
            // Если уже настроено — выдаём JSON-ответ с пояснением, 
            // чтобы на фронте не было ошибок парсинга HTML.
            if (!_setupStateService.IsInitialSetupNeeded)
            {
                return StatusCode(StatusCodes.Status403Forbidden,
                    new { success = false, message = "System is already configured." });
            }

            var filePath = Path.Combine(_env.ContentRootPath, "InitialSetup", "index.html");
            if (System.IO.File.Exists(filePath))
            {
                return PhysicalFile(filePath, "text/html; charset=utf-8");
            }
            return NotFound("Initial setup page not found. Please contact admin.");
        }

        /// <summary>Основной метод инициализации.</summary>
        [HttpPost("initialize")]
        public async Task<IActionResult> Initialize([FromBody] SetupDto dto)
        {
            // Если уже настроена — возвращаем JSON, 
            // чтобы фронт не пытался парсить HTML и не падал.
            if (!_setupStateService.IsInitialSetupNeeded)
            {
                // Можем вернуть 200 (OK) или 403. 
                // Но главное — ответить JSON.
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    success = false,
                    message = "System is already configured. Re-initialization is not allowed."
                });
            }

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

            // 3) Создаём администратора
            err = await CreateAdmin(dto.AdminEmail, dto.AdminPassword, dto.ConnectionString);
            if (!string.IsNullOrEmpty(err))
            {
                return BadRequest(new { success = false, message = $"CreateAdmin error: {err}" });
            }

            // Обновляем признак «система настроена»
            _setupStateService.DetermineIfSetupNeeded();

            // 4) Перезапуск
            //ForceRestart();

            return Ok(new { success = true, message = "Initialization in progress. The server will restart now." });
        }

        /// <summary>Запись в appsettings.json</summary>
        private async Task<string> SaveSettingsToAppSettings(SetupDto dto)
        {
            try
            {
                //var appSettingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
                var appSettingsPath = Path.Combine(_env.ContentRootPath, "appsettings.json");
                if (!System.IO.File.Exists(appSettingsPath))
                {
                    using var _ = System.IO.File.CreateText(appSettingsPath);
                }

                var oldJson = await System.IO.File.ReadAllTextAsync(appSettingsPath);
                if (string.IsNullOrWhiteSpace(oldJson))
                {
                    // Создаём заготовку
                    oldJson = "{\"ConnectionStrings\": {}, \"Jwt\": {}, \"YandexCloud\": {}, \"TypeOfAccessImages\": {}, \"YandexDisk\": {}}";
                }

                // 1) Десериализация
                var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(oldJson)
                           ?? new Dictionary<string, object>();

                // 2) ConnectionStrings
                if (!dict.ContainsKey("ConnectionStrings"))
                    dict["ConnectionStrings"] = new Dictionary<string, string>();

                var cstrObj = dict["ConnectionStrings"];
                var cstrDict = cstrObj is JsonElement je
                    ? JsonSerializer.Deserialize<Dictionary<string, string>>(je.GetRawText()) ?? new Dictionary<string, string>()
                    : cstrObj as Dictionary<string, string> ?? new Dictionary<string, string>();

                cstrDict["DefaultConnection"] = dto.ConnectionString;
                dict["ConnectionStrings"] = cstrDict;

                // 3) Jwt
                var jwtDict = new Dictionary<string, string>
                {
                    ["Key"] = dto.JwtKey ?? "",
                    ["Issuer"] = dto.JwtIssuer ?? "",
                    ["Audience"] = dto.JwtAudience ?? ""
                };
                dict["Jwt"] = jwtDict;

                // 4) YandexDisk (при желании)
                if (!dict.ContainsKey("YandexDisk"))
                    dict["YandexDisk"] = new Dictionary<string, string>();

                var ydObj = dict["YandexDisk"];
                var ydDict = ydObj is JsonElement yde
                    ? JsonSerializer.Deserialize<Dictionary<string, string>>(yde.GetRawText()) ?? new Dictionary<string, string>()
                    : ydObj as Dictionary<string, string> ?? new Dictionary<string, string>();

                // Заполним
                ydDict["Token"] = dto.YandexDiskToken ?? "";
                dict["YandexDisk"] = ydDict;

                // 5) TypeOfAccessImages
                if (!dict.ContainsKey("TypeOfAccessImages"))
                    dict["TypeOfAccessImages"] = new Dictionary<string, string>();

                var toaObj = dict["TypeOfAccessImages"];
                var toaDict = toaObj is JsonElement taej
                    ? JsonSerializer.Deserialize<Dictionary<string, string>>(taej.GetRawText()) ?? new Dictionary<string, string>()
                    : toaObj as Dictionary<string, string> ?? new Dictionary<string, string>();

                toaDict["UseLocalFiles"] = dto.TypeOfAccessImagesUseLocalFiles ?? "false";
                toaDict["LocalPathOfImages"] = dto.TypeOfAccessImagesLocalPathOfImages ?? "";
                dict["TypeOfAccessImages"] = toaDict;

                // 6) YandexCloud
                if (!dict.ContainsKey("YandexCloud"))
                    dict["YandexCloud"] = new Dictionary<string, string>();

                var ycObj = dict["YandexCloud"];
                var ycDict = ycObj is JsonElement yce
                    ? JsonSerializer.Deserialize<Dictionary<string, string>>(yce.GetRawText()) ?? new Dictionary<string, string>()
                    : ycObj as Dictionary<string, string> ?? new Dictionary<string, string>();

                ycDict["AccessKey"] = dto.YandexCloudAccessKey ?? "";
                ycDict["SecretKey"] = dto.YandexCloudSecretKey ?? "";
                ycDict["ServiceUrl"] = dto.YandexCloudServiceUrl ?? "";
                ycDict["BucketName"] = dto.YandexCloudBucketName ?? "";
                dict["YandexCloud"] = ycDict;

                // 7) Сериализуем обратно
                var newJson = JsonSerializer.Serialize(dict, new JsonSerializerOptions { WriteIndented = true });
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
                var services = new ServiceCollection();
                services.AddLogging();
                services.AddDbContext<RegularBaseBooksContext>(options =>
                {
                    options.UseNpgsql(newConnectionString);
                });
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

                if (!await roleManager.RoleExistsAsync("Admin"))
                {
                    await roleManager.CreateAsync(new IdentityRole("Admin"));
                }

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
            // Вариант: Environment.Exit(0) + Docker restart
            Environment.Exit(0);
        }
    }
}
