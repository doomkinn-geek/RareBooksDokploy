using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class AdminController : BaseController
    {
        private readonly IExportService _exportService;
        private readonly IUserService _userService;
        private readonly ILogger<AdminController> _logger;

        public AdminController(
            IUserService userService,
            UserManager<ApplicationUser> userManager,
            ILogger<AdminController> logger,
            IExportService exportService)
            : base(userManager)
        {
            _userService = userService;
            _logger = logger;
            _exportService = exportService;
        }

        [HttpPost("export-data")]
        public async Task<IActionResult> StartExport()
        {
            _logger.LogInformation("Запущен экспорт данных из PostgreSQL в SQLite");
            var taskId = await _exportService.StartExportAsync();
            return Ok(new { TaskId = taskId });
        }

        [HttpGet("export-progress/{taskId}")]
        public IActionResult GetExportProgress(Guid taskId)
        {
            int progress = _exportService.GetProgress(taskId);
            if (progress == -1)
                return NotFound("Задача не найдена или произошла ошибка.");
            return Ok(new { Progress = progress });
        }

        [HttpGet("download-exported-file/{taskId}")]
        public IActionResult DownloadExportedFile(Guid taskId)
        {
            var file = _exportService.GetExportedFile(taskId);
            if (file == null || !file.Exists)
                return NotFound("Файл не найден.");

            return PhysicalFile(file.FullName, "application/octet-stream", $"export_{taskId}.db");
        }

        [HttpPost("cancel-export/{taskId}")]
        public IActionResult CancelExport(Guid taskId)
        {
            _exportService.CancelExport(taskId);
            return Ok();
        }

        [HttpGet("users")]
        public async Task<ActionResult<IEnumerable<ApplicationUser>>> GetUsers()
        {
            _logger.LogInformation("Запрос на получение списка пользователей.");

            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Просматривать список пользователей может только администратор");
            }

            var users = await _userService.GetAllUsersAsync();

            _logger.LogInformation("Список пользователей успешно получен. Количество пользователей: {UserCount}", users.Count());
            return Ok(users);
        }

        [HttpGet("user/{userId}")]
        public async Task<ActionResult<ApplicationUser>> GetUser(string userId)
        {
            _logger.LogInformation("Запрос на получение информации о пользователе с ID: {UserId}", userId);

            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Просматривать информацию о пользователе может только администратор");
            }

            var user = await _userService.GetUserByIdAsync(userId);
            if (user == null)
            {
                _logger.LogWarning("Пользователь с ID {UserId} не найден.", userId);
                return NotFound("Пользователь не найден");
            }

            _logger.LogInformation("Информация о пользователе с ID {UserId} успешно получена.", userId);
            return Ok(user);
        }

        [HttpGet("user/{userId}/searchHistory")]
        public async Task<ActionResult<IEnumerable<UserSearchHistoryDto>>> GetUserSearchHistory(string userId)
        {
            _logger.LogInformation("Запрос на получение истории поиска пользователя с ID: {UserId}", userId);

            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Просматривать историю поиска может только администратор");
            }

            var history = await _userService.GetUserSearchHistoryAsync(userId);

            if (history == null || !history.Any())
            {
                _logger.LogInformation("История поиска для пользователя с ID {UserId} не найдена или пуста.", userId);
                return NotFound("История поиска не найдена");
            }

            var historyDto = history.Select(h => new UserSearchHistoryDto
            {
                Id = h.Id,
                Query = h.Query,
                SearchDate = h.SearchDate,
                SearchType = h.SearchType
            });

            _logger.LogInformation("История поиска для пользователя с ID {UserId} успешно получена. Количество записей: {HistoryCount}", userId, historyDto.Count());

            return Ok(historyDto);
        }

        [HttpPost("user/{userId}/subscription")]
        public async Task<IActionResult> UpdateUserSubscription(string userId, [FromBody] bool hasSubscription)
        {
            _logger.LogInformation("Запрос на обновление подписки пользователя с ID: {UserId}. Новое значение подписки: {HasSubscription}", userId, hasSubscription);

            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Обновлять информацию о подписке может только администратор");
            }

            var result = await _userService.UpdateUserSubscriptionAsync(userId, hasSubscription);
            if (result)
            {
                _logger.LogInformation("Подписка пользователя с ID {UserId} успешно обновлена до значения {HasSubscription}", userId, hasSubscription);
                return Ok();
            }

            _logger.LogError("Не удалось обновить статус подписки для пользователя с ID {UserId}", userId);
            return BadRequest("Не удалось обновить статус подписки.");
        }

        [HttpPost("user/{userId}/role")]
        public async Task<IActionResult> AssignRole(string userId, [FromBody] string role)
        {
            _logger.LogInformation("Запрос на назначение роли '{Role}' пользователю с ID: {UserId}", role, userId);

            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Назначение ролей может выполнять только администратор");
            }

            // Предполагается, что IUserService.AssignRoleAsync теперь использует методы UserManager:
            // - GetRolesAsync(user)
            // - RemoveFromRolesAsync(user, oldRoles)
            // - AddToRoleAsync(user, role)
            // - user.Role = role;
            // - UpdateAsync(user)
            var result = await _userService.AssignRoleAsync(userId, role);
            if (result)
            {
                _logger.LogInformation("Роль '{Role}' успешно назначена пользователю с ID {UserId}", role, userId);
                return Ok();
            }

            _logger.LogError("Не удалось назначить роль '{Role}' пользователю с ID {UserId}", role, userId);
            return BadRequest("Не удалось назначить роль.");
        }
    }
}
