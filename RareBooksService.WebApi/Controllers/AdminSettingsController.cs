using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
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
            // Путь к appsettings.json в корне проекта:
            // Обычно это то же место, где запускается приложение.
            _appSettingsPath = Path.Combine(env.ContentRootPath, "appsettings.json");
        }

        // GET: api/AdminSettings
        // Возвращает нужные секции конфигурации (YandexKassa, YandexDisk, TypeOfAccessImages)
        [HttpGet]
        public async Task<ActionResult<IEnumerable<SettingsDto>>> GetSettings()        
        {
            try
            {
                var currentUser = await GetCurrentUserAsync();
                if (!IsUserAdmin(currentUser))
                {
                    _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                    return Forbid("Обновлять информацию о подписке может только администратор");
                }
                // Считываем файл appsettings.json как текст
                var jsonString = System.IO.File.ReadAllText(_appSettingsPath);

                // Парсим JSON в JsonObject, чтобы можно было вытянуть/изменить нужные поля
                var rootNode = JsonNode.Parse(jsonString)?.AsObject();
                if (rootNode == null)
                {
                    return BadRequest("Could not parse appsettings.json");
                }

                // Собираем нужные объекты настроек
                // Например:
                var yandexKassaNode = rootNode["YandexKassa"]?.AsObject();
                var yandexDiskNode = rootNode["YandexDisk"]?.AsObject();
                var typeOfAccessImagesNode = rootNode["TypeOfAccessImages"]?.AsObject();

                return Ok(new
                {
                    YandexKassa = yandexKassaNode,
                    YandexDisk = yandexDiskNode,
                    TypeOfAccessImages = typeOfAccessImagesNode
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
        [HttpPost]
        public async Task<IActionResult> UpdateSettings([FromBody] SettingsDto dto)
        {
            try
            {
                var currentUser = await GetCurrentUserAsync();
                if (!IsUserAdmin(currentUser))
                {
                    _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                    return Forbid("Обновлять информацию о подписке может только администратор");
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

                // Записываем обратно в файл
                // Важно: убедитесь, что у приложения есть права на перезапись appsettings.json
                var updatedJson = rootNode.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
                System.IO.File.WriteAllText(_appSettingsPath, updatedJson);

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
