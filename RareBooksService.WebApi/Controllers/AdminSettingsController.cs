using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // или другой механизм авторизации
    public class AdminSettingsController : BaseController
    {
        private readonly ILogger<AdminSettingsController> _logger;
        private readonly IConfiguration _configuration;
        private readonly IWebHostEnvironment _env;
        private readonly string _appSettingsPath;

        public AdminSettingsController(
            ILogger<AdminSettingsController> logger,
            UserManager<ApplicationUser> userManager,
            IConfiguration configuration,
            IWebHostEnvironment env) : base(userManager)
        {
            _logger = logger;
            _configuration = configuration;
            _env = env;
            // Путь к appsettings.json:
            _appSettingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
        }

        // GET: api/AdminSettings
        // Возвращает нужные секции конфигурации (YandexKassa, YandexDisk, TypeOfAccessImages, и т.д.)
        [HttpGet]
        public async Task<ActionResult> GetSettings()
        {
            try
            {
                var currentUser = await GetCurrentUserAsync();
                if (!IsUserAdmin(currentUser))
                {
                    _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                    return Forbid("Изменять настройки может только администратор");
                }

                if (!System.IO.File.Exists(_appSettingsPath))
                {
                    return NotFound("appsettings.json not found");
                }

                // Считываем файл appsettings.json
                var jsonString = System.IO.File.ReadAllText(_appSettingsPath);

                var rootNode = JsonNode.Parse(jsonString)?.AsObject();
                if (rootNode == null)
                {
                    return BadRequest("Could not parse appsettings.json");
                }

                // Собираем нужные объекты (пример)
                var yandexKassaNode = rootNode["YandexKassa"]?.AsObject();
                var yandexDiskNode = rootNode["YandexDisk"]?.AsObject();
                var typeOfAccessImagesNode = rootNode["TypeOfAccessImages"]?.AsObject();
                var yandexCloudNode = rootNode["YandexCloud"]?.AsObject();
                var smtpNode = rootNode["Smtp"]?.AsObject();

                return Ok(new
                {
                    YandexKassa = yandexKassaNode,
                    YandexDisk = yandexDiskNode,
                    TypeOfAccessImages = typeOfAccessImagesNode,
                    YandexCloud = yandexCloudNode,
                    Smtp = smtpNode
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading settings");
                return StatusCode(500, "Error reading settings from appsettings.json");
            }
        }

        // POST: api/AdminSettings
        // Принимает обновлённые настройки и перезаписывает их в appsettings.json
        // Затем вызывает Reload() конфигурации (при необходимости).
        [HttpPost]
        public async Task<IActionResult> UpdateSettings([FromBody] SettingsDto dto)
        {
            try
            {
                var currentUser = await GetCurrentUserAsync();
                if (!IsUserAdmin(currentUser))
                {
                    _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                    return Forbid("Обновлять настройки может только администратор");
                }

                if (!System.IO.File.Exists(_appSettingsPath))
                {
                    return NotFound("appsettings.json not found");
                }

                // Считываем оригинальный файл
                var jsonString = System.IO.File.ReadAllText(_appSettingsPath);
                var rootNode = JsonNode.Parse(jsonString)?.AsObject();
                if (rootNode == null)
                {
                    return BadRequest("Could not parse appsettings.json");
                }

                // Обновляем YandexKassa
                if (dto.YandexKassa != null)
                {
                    var ykNode = rootNode["YandexKassa"] as JsonObject ?? new JsonObject();
                    ykNode["ShopId"] = dto.YandexKassa.ShopId;
                    ykNode["SecretKey"] = dto.YandexKassa.SecretKey;
                    ykNode["ReturnUrl"] = dto.YandexKassa.ReturnUrl;
                    ykNode["WebhookUrl"] = dto.YandexKassa.WebhookUrl;
                    rootNode["YandexKassa"] = ykNode;
                }

                // Обновляем YandexDisk
                if (dto.YandexDisk != null)
                {
                    var ydNode = rootNode["YandexDisk"] as JsonObject ?? new JsonObject();
                    ydNode["Token"] = dto.YandexDisk.Token;
                    rootNode["YandexDisk"] = ydNode;
                }

                // Обновляем TypeOfAccessImages
                if (dto.TypeOfAccessImages != null)
                {
                    var taNode = rootNode["TypeOfAccessImages"] as JsonObject ?? new JsonObject();
                    taNode["UseLocalFiles"] = dto.TypeOfAccessImages.UseLocalFiles;
                    taNode["LocalPathOfImages"] = dto.TypeOfAccessImages.LocalPathOfImages;
                    rootNode["TypeOfAccessImages"] = taNode;
                }

                // Обновляем YandexCloud
                if (dto.YandexCloud != null)
                {
                    var ycNode = rootNode["YandexCloud"] as JsonObject ?? new JsonObject();
                    ycNode["AccessKey"] = dto.YandexCloud.AccessKey;
                    ycNode["SecretKey"] = dto.YandexCloud.SecretKey;
                    ycNode["ServiceUrl"] = dto.YandexCloud.ServiceUrl;
                    ycNode["BucketName"] = dto.YandexCloud.BucketName;
                    rootNode["YandexCloud"] = ycNode;
                }

                // Обновляем Smtp
                if (dto.Smtp != null)
                {
                    var smtpNode = rootNode["Smtp"] as JsonObject ?? new JsonObject();
                    smtpNode["Host"] = dto.Smtp.Host;
                    smtpNode["Port"] = dto.Smtp.Port;
                    smtpNode["User"] = dto.Smtp.User;
                    smtpNode["Pass"] = dto.Smtp.Pass;
                    rootNode["Smtp"] = smtpNode;
                }

                // Записываем обновлённый JSON обратно в файл
                var updatedJson = rootNode.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
                System.IO.File.WriteAllText(_appSettingsPath, updatedJson);

                // Если хотим сразу подхватить новые настройки:
                // Приводим _configuration к IConfigurationRoot и вызываем Reload().
                if (_configuration is IConfigurationRoot configRoot)
                {
                    configRoot.Reload();
                }

                return Ok(new { message = "Settings updated successfully" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error updating settings");
                return StatusCode(500, "Error updating settings in appsettings.json");
            }
        }
    }
}
