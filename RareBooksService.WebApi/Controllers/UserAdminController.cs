using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme)]
    public class UserAdminController : BaseController
    {
        private readonly IUserExportService _userExportService;
        private readonly IUserImportService _userImportService;
        private readonly ILogger<UserAdminController> _logger;

        public UserAdminController(
            UserManager<ApplicationUser> userManager,
            ILogger<UserAdminController> logger,
            IUserExportService userExportService,
            IUserImportService userImportService)
            : base(userManager)
        {
            _logger = logger;
            _userExportService = userExportService;
            _userImportService = userImportService;
        }

        // ==================== ЭКСПОРТ ПОЛЬЗОВАТЕЛЕЙ ====================

        [HttpPost("export-users")]
        public async Task<IActionResult> StartUserExport()
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Попытка экспорта пользователей не-администратором");
                return Forbid("Экспорт пользователей доступен только администраторам");
            }

            try
            {
                _logger.LogInformation("Запущен экспорт пользователей");
                var taskId = await _userExportService.StartExportAsync();
                return Ok(new { TaskId = taskId });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка запуска экспорта пользователей");
                return StatusCode(500, "Внутренняя ошибка сервера");
            }
        }

        [HttpGet("user-export-progress/{taskId}")]
        public IActionResult GetUserExportProgress(Guid taskId)
        {
            var currentUser = GetCurrentUserAsync().Result;
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            try
            {
                var status = _userExportService.GetStatus(taskId);

                if (status.Progress == -1 && !status.IsError)
                {
                    return NotFound("Задача не найдена.");
                }

                return Ok(new ExportStatusDto
                {
                    Progress = status.Progress,
                    IsError = status.IsError,
                    ErrorDetails = status.ErrorDetails
                });
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Ошибка получения прогресса экспорта пользователей");
                return Ok(new { Progress = -1, IsError = true, ErrorDetails = e.ToString() });
            }
        }

        [HttpGet("user-export-status")]
        public IActionResult GetUserExportStatus()
        {
            var currentUser = GetCurrentUserAsync().Result;
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            try
            {
                var activeExports = _userExportService.GetActiveExports();
                
                if (activeExports != null && activeExports.Any())
                {
                    var activeExport = activeExports.First();
                    return Ok(new
                    {
                        isExporting = true,
                        taskId = activeExport.TaskId,
                        progress = activeExport.Progress
                    });
                }

                return Ok(new { isExporting = false });
            }
            catch (Exception e)
            {
                _logger.LogError(e, "Ошибка получения статуса экспорта пользователей");
                return Ok(new { isExporting = false });
            }
        }

        [HttpGet("download-exported-users/{taskId}")]
        public IActionResult DownloadExportedUsersFile(Guid taskId)
        {
            var currentUser = GetCurrentUserAsync().Result;
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            var file = _userExportService.GetExportedFile(taskId);
            if (file == null || !file.Exists)
                return NotFound("Файл не найден.");

            var result = PhysicalFile(file.FullName, "application/zip", $"users_export_{taskId}.zip");
            result.EnableRangeProcessing = true;
            
            return result;
        }

        [HttpPost("cancel-user-export/{taskId}")]
        public IActionResult CancelUserExport(Guid taskId)
        {
            var currentUser = GetCurrentUserAsync().Result;
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            _userExportService.CancelExport(taskId);
            return Ok();
        }

        // ==================== ИМПОРТ ПОЛЬЗОВАТЕЛЕЙ ====================

        [HttpPost("init-user-import")]
        public async Task<IActionResult> InitUserImport([FromQuery] long? fileSize = null)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Попытка импорта пользователей не-администратором");
                return Forbid("Импорт пользователей доступен только администраторам");
            }

            try
            {
                var actualFileSize = fileSize ?? 0;
                var importTaskId = await _userImportService.InitImportAsync(actualFileSize);
                
                _logger.LogInformation($"Инициализирован импорт пользователей {importTaskId}, размер файла: {actualFileSize}");
                
                return Ok(new { ImportTaskId = importTaskId });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка инициализации импорта пользователей");
                return StatusCode(500, $"Ошибка инициализации: {ex.Message}");
            }
        }

        [HttpPost("upload-user-chunk/{importTaskId}")]
        public async Task<IActionResult> UploadUserChunk(Guid importTaskId)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            try
            {
                using var memoryStream = new MemoryStream();
                await Request.Body.CopyToAsync(memoryStream);
                var chunkData = memoryStream.ToArray();

                await _userImportService.UploadChunkAsync(importTaskId, chunkData);

                return Ok(new { Success = true });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка загрузки chunk для импорта пользователей {importTaskId}");
                return StatusCode(500, $"Ошибка загрузки: {ex.Message}");
            }
        }

        [HttpPost("finish-user-upload/{importTaskId}")]
        public async Task<IActionResult> FinishUserUpload(Guid importTaskId)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            try
            {
                await _userImportService.FinishUploadAsync(importTaskId);
                
                _logger.LogInformation($"Завершена загрузка файла для импорта пользователей {importTaskId}");
                
                return Ok(new { Success = true });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка завершения загрузки для импорта пользователей {importTaskId}");
                return StatusCode(500, $"Ошибка завершения загрузки: {ex.Message}");
            }
        }

        [HttpGet("user-import-progress/{importTaskId}")]
        public IActionResult GetUserImportProgress(Guid importTaskId)
        {
            var currentUser = GetCurrentUserAsync().Result;
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            try
            {
                var progress = _userImportService.GetProgress(importTaskId);
                return Ok(progress);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка получения прогресса импорта пользователей {importTaskId}");
                return StatusCode(500, $"Ошибка получения прогресса: {ex.Message}");
            }
        }

        [HttpPost("cancel-user-import/{importTaskId}")]
        public async Task<IActionResult> CancelUserImport(Guid importTaskId)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                return Forbid("Доступ запрещен");
            }

            try
            {
                await _userImportService.CancelImportAsync(importTaskId);
                
                _logger.LogInformation($"Отменён импорт пользователей {importTaskId}");
                
                return Ok(new { Success = true });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка отмены импорта пользователей {importTaskId}");
                return StatusCode(500, $"Ошибка отмены: {ex.Message}");
            }
        }
    }
}