using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Common.Models.Dto.RareBooksService.Common.Models.Dto;
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
        private readonly ISubscriptionService _subscriptionService;

        public AdminController(
            IUserService userService,
            UserManager<ApplicationUser> userManager,
            ILogger<AdminController> logger,
            IExportService exportService,
            ISubscriptionService subscriptionService)
            : base(userManager)
        {
            _userService = userService;
            _logger = logger;
            _exportService = exportService;
            _subscriptionService = subscriptionService;
        }

        [HttpPost("export-data")]
        public async Task<IActionResult> StartExport()
        {
            try
            {
                _logger.LogInformation("Запрос на запуск экспорта данных из PostgreSQL в SQLite");
                var taskId = await _exportService.StartExportAsync();
                _logger.LogInformation($"Экспорт запущен с TaskId: {taskId}");
                return Ok(new { TaskId = taskId });
            }
            catch (InvalidOperationException invalidOpEx)
            {
                _logger.LogWarning($"Попытка запуска экспорта при активном процессе: {invalidOpEx.Message}");
                return BadRequest(invalidOpEx.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Критическая ошибка при запуске экспорта");
                return StatusCode(500, "Внутренняя ошибка сервера при запуске экспорта");
            }
        }

        [HttpGet("export-progress/{taskId}")]
        public IActionResult GetExportProgress(Guid taskId)
        {
            try
            {
                _logger.LogDebug($"Запрос прогресса экспорта для TaskId: {taskId}");
                var status = _exportService.GetStatus(taskId);

                if (status.Progress == -1 && !status.IsError)
                {
                    _logger.LogWarning($"Задача экспорта не найдена, TaskId: {taskId}");
                    return NotFound("Задача не найдена.");
                }

                _logger.LogDebug($"Прогресс экспорта TaskId: {taskId}, Progress: {status.Progress}%, IsError: {status.IsError}");
                return Ok(new ExportStatusDto
                {
                    Progress = status.Progress,
                    IsError = status.IsError,
                    ErrorDetails = status.ErrorDetails
                });
            }
            catch (Exception e)
            {
                _logger.LogError(e, $"Критическая ошибка получения прогресса экспорта, TaskId: {taskId}");
                return StatusCode(500, new { Progress = -1, IsError = true, ErrorDetails = "Внутренняя ошибка сервера при получении прогресса экспорта" });
            }
        }

        [HttpGet("export-status")]
        public IActionResult GetExportStatus()
        {
            try
            {
                // Проверяем, есть ли активные экспорты
                // Поскольку в ExportService используются статические словари, проверим их
                var activeExports = _exportService.GetActiveExports();
                
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
                _logger.LogError(e, "Ошибка получения статуса экспорта");
                return Ok(new { isExporting = false });
            }
        }


        [HttpGet("download-exported-file/{taskId}")]
        public IActionResult DownloadExportedFile(Guid taskId)
        {
            var startTime = DateTime.UtcNow;
            try
            {
                _logger.LogInformation($"[DOWNLOAD] Запрос на скачивание файла экспорта, TaskId: {taskId}, IP: {HttpContext.Connection.RemoteIpAddress}");
                
                // Проверяем статус экспорта
                var status = _exportService.GetStatus(taskId);
                _logger.LogInformation($"[DOWNLOAD] Статус экспорта - Progress: {status.Progress}%, IsError: {status.IsError}, TaskId: {taskId}");
                
                if (status.IsError)
                {
                    _logger.LogWarning($"[DOWNLOAD] Экспорт завершился с ошибкой: {status.ErrorDetails}, TaskId: {taskId}");
                    return BadRequest($"Экспорт завершился с ошибкой: {status.ErrorDetails}");
                }
                
                if (status.Progress < 100)
                {
                    _logger.LogWarning($"[DOWNLOAD] Экспорт еще не завершен ({status.Progress}%), TaskId: {taskId}");
                    return BadRequest($"Экспорт еще не завершен. Прогресс: {status.Progress}%");
                }
                
                var file = _exportService.GetExportedFile(taskId);
                if (file == null)
                {
                    _logger.LogError($"[DOWNLOAD] GetExportedFile вернул null, TaskId: {taskId}");
                    return NotFound("Файл экспорта не найден в системе.");
                }
                
                if (!file.Exists)
                {
                    _logger.LogError($"[DOWNLOAD] Файл экспорта не существует на диске: {file.FullName}, TaskId: {taskId}");
                    return NotFound("Файл экспорта не найден на диске.");
                }

                var fileSizeMB = file.Length / (1024.0 * 1024.0);
                _logger.LogInformation($"[DOWNLOAD] Файл найден: {file.FullName}, размер: {fileSizeMB:F2} MB, TaskId: {taskId}");

                // Логируем заголовки запроса для диагностики
                var userAgent = HttpContext.Request.Headers["User-Agent"].ToString();
                var rangeHeader = HttpContext.Request.Headers["Range"].ToString();
                _logger.LogInformation($"[DOWNLOAD] User-Agent: {userAgent}, Range: {rangeHeader}, TaskId: {taskId}");

                // Проверяем, что файл доступен для чтения
                try
                {
                    using (var testStream = System.IO.File.OpenRead(file.FullName))
                    {
                        var testBuffer = new byte[1024];
                        var bytesRead = testStream.Read(testBuffer, 0, 1024);
                        _logger.LogInformation($"[DOWNLOAD] Файл успешно прочитан, первые {bytesRead} байт получены, TaskId: {taskId}");
                    }
                }
                catch (Exception readEx)
                {
                    _logger.LogError(readEx, $"[DOWNLOAD] Ошибка при тестовом чтении файла, TaskId: {taskId}");
                    return StatusCode(500, "Файл поврежден или недоступен для чтения");
                }

                // Создаем результат
                _logger.LogInformation($"[DOWNLOAD] Создаем PhysicalFileResult, TaskId: {taskId}");
                var result = PhysicalFile(file.FullName, "application/zip", $"export_{taskId}.zip");
                
                // Включаем поддержку Range requests для больших файлов (позволяет докачку)
                result.EnableRangeProcessing = true;
                
                var processingTime = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogInformation($"[DOWNLOAD] PhysicalFileResult создан за {processingTime:F2}ms, возвращаем результат, TaskId: {taskId}");
                
                return result;
            }
            catch (Exception ex)
            {
                var processingTime = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogError(ex, $"[DOWNLOAD] КРИТИЧЕСКАЯ ОШИБКА при обработке запроса загрузки за {processingTime:F2}ms, TaskId: {taskId}");
                return StatusCode(500, $"Внутренняя ошибка сервера: {ex.Message}");
            }
        }

        [HttpPost("cancel-export/{taskId}")]
        public IActionResult CancelExport(Guid taskId)
        {
            _exportService.CancelExport(taskId);
            return Ok();
        }

        [HttpGet("users")]
        public async Task<ActionResult<IEnumerable<UserDto>>> GetUsers()
        {
            _logger.LogInformation("Запрос на получение списка пользователей.");

            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Просматривать список пользователей может только администратор");
            }

            var users = await _userService.GetAllUsersWithSubscriptionsAsync();

            _logger.LogInformation("Список пользователей успешно получен. Количество пользователей: {UserCount}", users.Count());

            // Преобразуем пользователей в DTO, чтобы убрать циклические зависимости и лишние данные
            var userDtos = users.Select(user => new UserDto
            {
                Id = user.Id,
                Email = user.Email,
                Role = user.Role,
                HasSubscription = user.HasSubscription,
                CurrentSubscription = user.CurrentSubscription != null ? new SubscriptionDto
                {
                    Id = user.CurrentSubscription.Id,
                    SubscriptionPlanId = user.CurrentSubscription.SubscriptionPlanId,
                    AutoRenew = user.CurrentSubscription.AutoRenew,
                    IsActive = user.CurrentSubscription.IsActive,
                    StartDate = user.CurrentSubscription.StartDate,
                    EndDate = user.CurrentSubscription.EndDate,
                    SubscriptionPlan = user.CurrentSubscription.SubscriptionPlan != null ? new SubscriptionPlanDto
                    {
                        Id = user.CurrentSubscription.SubscriptionPlan.Id,
                        Name = user.CurrentSubscription.SubscriptionPlan.Name,
                        Price = user.CurrentSubscription.SubscriptionPlan.Price,
                        MonthlyRequestLimit = user.CurrentSubscription.SubscriptionPlan.MonthlyRequestLimit,
                        IsActive = user.CurrentSubscription.SubscriptionPlan.IsActive
                    } : null
                } : null
            }).ToList();

            return Ok(userDtos);
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
        [HttpPost("user/{userId}/assign-subscription-plan")]
        public async Task<IActionResult> AssignSubscriptionPlan(string userId, [FromBody] AssignSubscriptionPlanRequest request)
        {
            _logger.LogInformation("Запрос на назначение плана подписки пользователю {UserId}: {PlanId}, autoRenew={AutoRenew}",
                userId, request.PlanId, request.AutoRenew);

            var currentUser = await GetCurrentUserAsync();
            if (!IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: текущий пользователь не является администратором.");
                return Forbid("Назначение подписки может выполнять только администратор");
            }

            // План может быть 0 => означает «отключить подписку»
            // Или > 0 => означает задать конкретный план (включить или заменить).

            bool success;
            if (request.PlanId == 0)
            {
                // Сброс/отключение подписки
                success = await _subscriptionService.DisableSubscriptionAsync(userId);
            }
            else
            {
                // Назначаем/обновляем подписку
                success = await _subscriptionService.AssignSubscriptionPlanAsync(userId, request.PlanId, request.AutoRenew);
            }

            if (!success)
            {
                _logger.LogError("Не удалось изменить подписку пользователю {UserId}", userId);
                return BadRequest("Не удалось изменить подписку.");
            }

            _logger.LogInformation("Подписка пользователя {UserId} успешно изменена (Plan={PlanId}, autoRenew={AutoRenew})",
                userId, request.PlanId, request.AutoRenew);

            return Ok();
        }
        
        /// <summary>
        /// Альтернативный endpoint для потоковой загрузки больших файлов экспорта
        /// </summary>
        [HttpGet("download-exported-file-stream/{taskId}")]
        public async Task<IActionResult> DownloadExportedFileStream(Guid taskId)
        {
            var startTime = DateTime.UtcNow;
            try
            {
                _logger.LogInformation($"[STREAM] Запрос на потоковое скачивание файла экспорта, TaskId: {taskId}, IP: {HttpContext.Connection.RemoteIpAddress}");
                
                // Проверяем статус экспорта
                var status = _exportService.GetStatus(taskId);
                _logger.LogInformation($"[STREAM] Статус экспорта - Progress: {status.Progress}%, IsError: {status.IsError}, TaskId: {taskId}");

                if (status.Progress != 100 || status.IsError)
                {
                    _logger.LogWarning($"[STREAM] Экспорт не завершен или содержит ошибку, TaskId: {taskId}");
                    return BadRequest("Экспорт не завершен или содержит ошибку.");
                }

                var file = _exportService.GetExportedFile(taskId);
                if (file == null || !file.Exists)
                {
                    _logger.LogWarning($"[STREAM] Файл экспорта не найден, TaskId: {taskId}");
                    return NotFound("Файл не найден.");
                }

                var fileSizeMB = file.Length / (1024.0 * 1024.0);
                _logger.LogInformation($"[STREAM] Файл найден: {file.FullName}, размер: {fileSizeMB:F2} MB, TaskId: {taskId}");

                // Логируем заголовки запроса
                var userAgent = HttpContext.Request.Headers["User-Agent"].ToString();
                var rangeHeader = HttpContext.Request.Headers["Range"].ToString();
                _logger.LogInformation($"[STREAM] User-Agent: {userAgent}, Range: {rangeHeader}, TaskId: {taskId}");

                // Проверяем, что файл доступен для чтения
                FileStream fileStream = null;
                try
                {
                    fileStream = new FileStream(file.FullName, FileMode.Open, FileAccess.Read, FileShare.Read, bufferSize: 64 * 1024, useAsync: true);
                    _logger.LogInformation($"[STREAM] Файл успешно открыт для потокового чтения, TaskId: {taskId}");
                }
                catch (Exception readEx)
                {
                    _logger.LogError(readEx, $"[STREAM] Не удалось открыть файл для потокового чтения: {file.FullName}, TaskId: {taskId}");
                    fileStream?.Dispose();
                    return StatusCode(500, "Не удалось получить доступ к файлу экспорта");
                }

                _logger.LogInformation($"[STREAM] Создаем FileStreamResult для потоковой отправки, TaskId: {taskId}");

                var elapsedMs = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogInformation($"[STREAM] FileStreamResult создан за {elapsedMs:F2}ms, начинаем потоковую отправку, TaskId: {taskId}");

                return new FileStreamResult(fileStream, "application/zip")
                {
                    FileDownloadName = $"export_{taskId}.zip",
                    EnableRangeProcessing = true
                };
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"[STREAM] Ошибка при потоковом скачивании файла экспорта, TaskId: {taskId}");
                return StatusCode(500, "Внутренняя ошибка сервера при скачивании файла");
            }
        }
    }

    public class AssignSubscriptionPlanRequest
    {
        public int PlanId { get; set; } // 0 = отключить
        public bool AutoRenew { get; set; }
    }
}
