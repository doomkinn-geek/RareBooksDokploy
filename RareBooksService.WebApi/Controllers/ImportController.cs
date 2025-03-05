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

            try
            {
                // Передаем ожидаемый размер файла, если он известен
                var taskId = _importService.StartImport(fileSize ?? 0);
                return Ok(new { importTaskId = taskId });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Ошибка при инициализации импорта");
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Непредвиденная ошибка при инициализации импорта");
                return StatusCode(500, "Произошла ошибка при инициализации импорта. Пожалуйста, попробуйте позже.");
            }
        }

        /// <summary>
        /// 2) Загрузка кусков файла (или всего файла целиком) для указанного importTaskId
        /// </summary>
        [DisableRequestSizeLimit]
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
                return BadRequest("Content-Type должен быть 'application/octet-stream'");
            }

            try
            {
                // Читаем body построчно:
                byte[] buffer = new byte[8192];
                int bytesRead;
                while ((bytesRead = await Request.Body.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    _importService.WriteFileChunk(importTaskId, buffer, bytesRead);
                }

                return Ok();
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Ошибка при загрузке файла для importTaskId={ImportTaskId}", importTaskId);
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Непредвиденная ошибка при загрузке файла для importTaskId={ImportTaskId}", importTaskId);
                return StatusCode(500, "Произошла ошибка при загрузке файла. Пожалуйста, попробуйте позже.");
            }
        }

        /// <summary>
        /// 3) После загрузки файла вызываем Finish, чтобы запустить импорт
        /// </summary>
        [HttpPost("finish")]
        public async Task<IActionResult> Finish([FromQuery] Guid importTaskId, CancellationToken cancellationToken = default)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Обновлять информацию о подписке может только администратор");
            }
            
            try
            {
                await _importService.FinishFileUploadAsync(importTaskId, cancellationToken);
                return Ok();
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Ошибка при завершении загрузки файла для importTaskId={ImportTaskId}", importTaskId);
                return BadRequest(ex.Message);
            }
            catch (OperationCanceledException)
            {
                _logger.LogWarning("Операция импорта была отменена для importTaskId={ImportTaskId}", importTaskId);
                return StatusCode(499, "Операция была отменена");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при завершении загрузки файла для importTaskId={ImportTaskId}", importTaskId);
                return StatusCode(500, ex.Message);
            }
        }

        /// <summary>
        /// 4) Получение статуса импортной задачи
        /// </summary>
        [HttpGet("progress/{importTaskId}")]
        public IActionResult GetProgress(Guid importTaskId)
        {
            try
            {
                var p = _importService.GetImportProgress(importTaskId);
                return Ok(p);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при получении статуса импорта для importTaskId={ImportTaskId}", importTaskId);
                return StatusCode(500, "Произошла ошибка при получении статуса импорта");
            }
        }

        /// <summary>
        /// 5) Отмена
        /// </summary>
        [HttpPost("cancel")]
        public async Task<IActionResult> Cancel(Guid importTaskId)
        {
            try
            {
                await _importService.CancelImportAsync(importTaskId);
                return Ok();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отмене импорта для importTaskId={ImportTaskId}", importTaskId);
                return StatusCode(500, "Произошла ошибка при отмене импорта");
            }
        }

        /// <summary>
        /// Обновляет ожидаемый размер файла для существующей задачи импорта
        /// </summary>
        [HttpPut("filesize")]
        public async Task<IActionResult> UpdateFileSize([FromQuery] Guid importTaskId, [FromQuery] long fileSize)
        {
            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Обновлять информацию о подписке может только администратор");
            }

            try
            {
                if (fileSize <= 0)
                {
                    return BadRequest("Размер файла должен быть положительным числом.");
                }

                _importService.UpdateExpectedFileSize(importTaskId, fileSize);
                return Ok();
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "Ошибка при обновлении размера файла для importTaskId={ImportTaskId}", importTaskId);
                return BadRequest(ex.Message);
            }
            catch (ArgumentOutOfRangeException ex)
            {
                _logger.LogWarning(ex, "Некорректное значение размера файла: {FileSize}", fileSize);
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Непредвиденная ошибка при обновлении размера файла для importTaskId={ImportTaskId}", importTaskId);
                return StatusCode(500, "Произошла ошибка при обновлении размера файла.");
            }
        }
    }
}
