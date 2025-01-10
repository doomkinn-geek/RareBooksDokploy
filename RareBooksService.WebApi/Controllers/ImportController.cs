using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.WebApi.Services;

namespace RareBooksService.WebApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ImportController : BaseController
    {
        private readonly IImportService _importService;
        private readonly ILogger<ImportController> _logger;

        public ImportController(IImportService importService,
            UserManager<ApplicationUser> userManager,
            ILogger<ImportController> logger) : base(userManager)
        {
            _importService = importService;
            _logger = logger;
        }

        /// <summary>
        /// 1) Инициализируем новую задачу импорта, возвращаем importTaskId
        /// </summary>
        [HttpPost("init")]
        public async Task<IActionResult> InitImport([FromQuery] long? fileSize = null)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Обновлять информацию о подписке может только администратор");
            }
            var taskId = _importService.StartImport();

            // Если клиент знает общий размер, можем сохранить:
            var progress = _importService.GetImportProgress(taskId);
            if (fileSize.HasValue)
            {
                // Зададим ExpectedFileSize
                // (нужно будет расширить IImportService, 
                //  чтобы можно было устанавливать ExpectedFileSize)
            }

            return Ok(new { importTaskId = taskId });
        }

        /// <summary>
        /// 2) Загрузка кусков файла (или всего файла целиком) для указанного importTaskId
        /// </summary>
        [HttpPost("upload")]
        public async Task<IActionResult> UploadFileChunk([FromQuery] Guid importTaskId)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Обновлять информацию о подписке может только администратор");
            }
            if (Request.ContentType == null || !Request.ContentType.Contains("application/octet-stream"))
            {
                return BadRequest("Content-Type must be 'application/octet-stream'");
            }

            // Читаем body построчно:
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = await Request.Body.ReadAsync(buffer, 0, buffer.Length)) > 0)
            {
                _importService.WriteFileChunk(importTaskId, buffer, bytesRead);
            }

            return Ok();
        }

        /// <summary>
        /// 3) После загрузки файла вызываем Finish, чтобы запустить импорт
        /// </summary>
        [HttpPost("finish")]
        public async Task<IActionResult> Finish([FromQuery] Guid importTaskId)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Обновлять информацию о подписке может только администратор");
            }
            try
            {
                await _importService.FinishFileUploadAsync(importTaskId);
                return Ok();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error finishing file upload");
                return StatusCode(500, ex.Message);
            }
        }

        /// <summary>
        /// 4) Получение статуса импортной задачи
        /// </summary>
        [HttpGet("progress/{importTaskId}")]
        public IActionResult GetProgress(Guid importTaskId)
        {
            var p = _importService.GetImportProgress(importTaskId);
            return Ok(p);
        }

        /// <summary>
        /// 5) Отмена
        /// </summary>
        [HttpPost("cancel")]
        public IActionResult Cancel(Guid importTaskId)
        {
            _importService.CancelImport(importTaskId);
            return Ok();
        }
    }
}
