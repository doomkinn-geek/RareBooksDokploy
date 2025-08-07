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

            // Две строки подключения — для книг и для пользователей
            public string BooksConnectionString { get; set; }
            public string UsersConnectionString { get; set; }

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
            
            // YandexKassa
            public string YandexKassaShopId { get; set; }
            public string YandexKassaSecretKey { get; set; }
            public string YandexKassaReturnUrl { get; set; }
            public string YandexKassaWebhookUrl { get; set; }
            
            // CacheSettings
            public string CacheSettingsLocalCachePath { get; set; }
            public string CacheSettingsDaysToKeep { get; set; }
            public string CacheSettingsMaxCacheSizeMB { get; set; }
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
            try
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

                // 1) Сохраняем настройки (обе строки подключения, JWT и т.д.)
                var err = await SaveSettingsToAppSettings(dto);
                if (!string.IsNullOrEmpty(err))
                {
                    return BadRequest(new { success = false, message = $"SaveSettings error: {err}" });
                }

                // 2) Мигрируем обе базы:
                //    - BooksDbContext
                //    - UsersDbContext
                err = await RunMigrationsForBooksDb(dto.BooksConnectionString);
                if (!string.IsNullOrEmpty(err))
                {
                    return BadRequest(new { success = false, message = $"RunMigrations(BooksDb) error: {err}" });
                }

                err = await RunMigrationsForUsersDb(dto.UsersConnectionString);
                if (!string.IsNullOrEmpty(err))
                {
                    return BadRequest(new { success = false, message = $"RunMigrations(UsersDb) error: {err}" });
                }

                // 3) Создаём администратора (в UsersDb)
                err = await CreateAdmin(dto.AdminEmail, dto.AdminPassword, dto.UsersConnectionString);
                if (!string.IsNullOrEmpty(err))
                {
                    return BadRequest(new { success = false, message = $"CreateAdmin error: {err}" });
                }

                // Обновляем признак «система настроена»
                _setupStateService.DetermineIfSetupNeeded();

                // 4) Перезапуск (по желанию)
                //ForceRestart();

                return Ok(new { success = true, message = "Initialization complete. The server will restart now." });
            }
            catch (Exception ex)
            {
                // Гарантируем возврат JSON даже при необработанных исключениях
                return StatusCode(500, new 
                { 
                    success = false, 
                    message = $"Unexpected error during initialization: {ex.Message}",
                    details = ex.StackTrace
                });
            }
        }

        /// <summary>Запись в appsettings.json</summary>
        private async Task<string> SaveSettingsToAppSettings(SetupDto dto)
        {
            try
            {
                var appSettingsPath = Path.Combine(_env.ContentRootPath, "appsettings.json");
                if (!System.IO.File.Exists(appSettingsPath))
                {
                    // Если файла нет, создаём пустой
                    using var _ = System.IO.File.CreateText(appSettingsPath);
                }

                var oldJson = await System.IO.File.ReadAllTextAsync(appSettingsPath);
                if (string.IsNullOrWhiteSpace(oldJson))
                {
                    // Создаём заготовку
                    oldJson = @"{ 
                      ""ConnectionStrings"": {}, 
                      ""Jwt"": {}, 
                      ""YandexCloud"": {}, 
                      ""TypeOfAccessImages"": {}, 
                      ""YandexDisk"": {},
                      ""YandexKassa"": {},
                      ""CacheSettings"": {}
                    }";
                }

                // 1) Десериализация текущего JSON
                var dict = JsonSerializer.Deserialize<Dictionary<string, object>>(oldJson)
                           ?? new Dictionary<string, object>();

                // 2) Блок "ConnectionStrings"
                if (!dict.ContainsKey("ConnectionStrings"))
                    dict["ConnectionStrings"] = new Dictionary<string, string>();

                var cstrObj = dict["ConnectionStrings"];
                var cstrDict = cstrObj is JsonElement je
                    ? JsonSerializer.Deserialize<Dictionary<string, string>>(je.GetRawText()) ?? new Dictionary<string, string>()
                    : cstrObj as Dictionary<string, string> ?? new Dictionary<string, string>();

                // Записываем обе строки подключения
                cstrDict["BooksDb"] = dto.BooksConnectionString;
                cstrDict["UsersDb"] = dto.UsersConnectionString;
                dict["ConnectionStrings"] = cstrDict;

                // 3) Блок "Jwt"
                var jwtDict = new Dictionary<string, string>
                {
                    ["Key"] = dto.JwtKey ?? "",
                    ["Issuer"] = dto.JwtIssuer ?? "",
                    ["Audience"] = dto.JwtAudience ?? ""
                };
                dict["Jwt"] = jwtDict;

                // 4) YandexDisk
                if (!dict.ContainsKey("YandexDisk"))
                    dict["YandexDisk"] = new Dictionary<string, string>();

                var ydObj = dict["YandexDisk"];
                var ydDict = ydObj is JsonElement yde
                    ? JsonSerializer.Deserialize<Dictionary<string, string>>(yde.GetRawText()) ?? new Dictionary<string, string>()
                    : ydObj as Dictionary<string, string> ?? new Dictionary<string, string>();

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

                // 7) YandexKassa
                if (!dict.ContainsKey("YandexKassa"))
                    dict["YandexKassa"] = new Dictionary<string, string>();

                var ykObj = dict["YandexKassa"];
                var ykDict = ykObj is JsonElement yke
                    ? JsonSerializer.Deserialize<Dictionary<string, string>>(yke.GetRawText()) ?? new Dictionary<string, string>()
                    : ykObj as Dictionary<string, string> ?? new Dictionary<string, string>();

                ykDict["ShopId"] = dto.YandexKassaShopId ?? "";
                ykDict["SecretKey"] = dto.YandexKassaSecretKey ?? "";
                ykDict["ReturnUrl"] = dto.YandexKassaReturnUrl ?? "";
                ykDict["WebhookUrl"] = dto.YandexKassaWebhookUrl ?? "";
                dict["YandexKassa"] = ykDict;

                // 8) CacheSettings
                if (!dict.ContainsKey("CacheSettings"))
                    dict["CacheSettings"] = new Dictionary<string, object>();

                var csObj = dict["CacheSettings"];
                var csDict = csObj is JsonElement cse
                    ? JsonSerializer.Deserialize<Dictionary<string, object>>(cse.GetRawText()) ?? new Dictionary<string, object>()
                    : csObj as Dictionary<string, object> ?? new Dictionary<string, object>();

                csDict["LocalCachePath"] = dto.CacheSettingsLocalCachePath ?? "image_cache";
                csDict["DaysToKeep"] = int.TryParse(dto.CacheSettingsDaysToKeep, out var daysToKeep) ? daysToKeep : 365;
                csDict["MaxCacheSizeMB"] = int.TryParse(dto.CacheSettingsMaxCacheSizeMB, out var maxCacheSizeMB) ? maxCacheSizeMB : 6000;
                dict["CacheSettings"] = csDict;

                // 9) Сериализуем обратно
                var newJson = JsonSerializer.Serialize(dict, new JsonSerializerOptions { WriteIndented = true });
                await System.IO.File.WriteAllTextAsync(appSettingsPath, newJson);

                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        /// <summary>Выполняем миграцию для BooksDbContext</summary>
        private async Task<string> RunMigrationsForBooksDb(string connectionString)
        {
            try
            {
                var optionsBuilder = new DbContextOptionsBuilder<BooksDbContext>();
                optionsBuilder.UseNpgsql(connectionString);

                using var ctx = new BooksDbContext(optionsBuilder.Options);
                await ctx.Database.MigrateAsync();
                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        /// <summary>Выполняем миграцию для UsersDbContext</summary>
        private async Task<string> RunMigrationsForUsersDb(string connectionString)
        {
            try
            {
                var optionsBuilder = new DbContextOptionsBuilder<UsersDbContext>();
                optionsBuilder.UseNpgsql(connectionString);

                using var ctx = new UsersDbContext(optionsBuilder.Options);
                await ctx.Database.MigrateAsync();
                return "";
            }
            catch (Exception ex)
            {
                return ex.Message;
            }
        }

        /// <summary>
        /// Создаём администратора в UsersDbContext, т.к. именно там хранятся Identity‑таблицы.
        /// </summary>
        private async Task<string> CreateAdmin(string email, string password, string usersConnectionString)
        {
            try
            {
                var services = new ServiceCollection();
                services.AddLogging();

                // Регистрируем UsersDbContext
                services.AddDbContext<UsersDbContext>(options =>
                {
                    options.UseNpgsql(usersConnectionString);
                });

                // Регистрируем Identity на основе UsersDbContext
                services.AddIdentity<ApplicationUser, IdentityRole>()
                        .AddEntityFrameworkStores<UsersDbContext>()
                        .AddDefaultTokenProviders();

                // Параметры валидации пароля (упрощённые)
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

                // Убедимся, что роль "Admin" создана
                if (!await roleManager.RoleExistsAsync("Admin"))
                {
                    await roleManager.CreateAsync(new IdentityRole("Admin"));
                }

                // Ищем, есть ли уже такой пользователь
                var existing = await userManager.FindByEmailAsync(email);
                if (existing == null)
                {
                    var adminUser = new ApplicationUser
                    {
                        UserName = email,
                        Email = email,
                        EmailConfirmed = true,
                        HasSubscription = false,
                        Role = "Admin" // для удобства
                    };
                    var result = await userManager.CreateAsync(adminUser, password);
                    if (!result.Succeeded)
                    {
                        var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                        return $"Failed to create admin user: {errors}";
                    }
                    await userManager.AddToRoleAsync(adminUser, "Admin");

                    // Дополнительно можно явно сохранить user.Role = "Admin"
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
