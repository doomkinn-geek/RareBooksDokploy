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
        private readonly ISubscriptionPlanExportService _subscriptionPlanExportService;
        private readonly ISubscriptionPlanImportService _subscriptionPlanImportService;

        public AdminController(
            IUserService userService,
            UserManager<ApplicationUser> userManager,
            ILogger<AdminController> logger,
            IExportService exportService,
            ISubscriptionService subscriptionService,
            ISubscriptionPlanExportService subscriptionPlanExportService,
            ISubscriptionPlanImportService subscriptionPlanImportService)
            : base(userManager)
        {
            _userService = userService;
            _logger = logger;
            _exportService = exportService;
            _subscriptionService = subscriptionService;
            _subscriptionPlanExportService = subscriptionPlanExportService;
            _subscriptionPlanImportService = subscriptionPlanImportService;
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
        public IActionResult DownloadExportedFile(Guid taskId, [FromQuery] string token = null)
        {
            var startTime = DateTime.UtcNow;
            try
            {
                _logger.LogInformation($"[DOWNLOAD] Запрос на скачивание файла экспорта, TaskId: {taskId}, IP: {HttpContext.Connection.RemoteIpAddress}");
                
                // Проверяем авторизацию (если токен передан через query параметр)
                if (!string.IsNullOrEmpty(token))
                {
                    _logger.LogInformation($"[DOWNLOAD] Проверяем токен из query параметра, TaskId: {taskId}");
                    // Здесь можно добавить проверку JWT токена, пока просто логируем
                    // TODO: Добавить валидацию JWT токена
                }
                
                // Логируем подробности запроса для диагностики
                var requestHeaders = string.Join("; ", HttpContext.Request.Headers.Select(h => $"{h.Key}={h.Value}"));
                _logger.LogInformation($"[DOWNLOAD] Headers: {requestHeaders}, TaskId: {taskId}");
                
                // Проверяем статус экспорта
                var status = _exportService.GetStatus(taskId);
                _logger.LogInformation($"[DOWNLOAD] Статус экспорта - Progress: {status.Progress}%, IsError: {status.IsError}, TaskId: {taskId}");
                
                if (status.IsError)
                {
                    _logger.LogWarning($"[DOWNLOAD] 400 BadRequest - Экспорт завершился с ошибкой: {status.ErrorDetails}, TaskId: {taskId}");
                    return BadRequest($"Экспорт завершился с ошибкой: {status.ErrorDetails}");
                }
                
                if (status.Progress < 100)
                {
                    _logger.LogWarning($"[DOWNLOAD] 400 BadRequest - Экспорт еще не завершен ({status.Progress}%), TaskId: {taskId}");
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
        public async Task<IActionResult> DownloadExportedFileStream(Guid taskId, [FromQuery] string token = null)
        {
            var startTime = DateTime.UtcNow;
            try
            {
                _logger.LogInformation($"[STREAM] Запрос на потоковое скачивание файла экспорта, TaskId: {taskId}, IP: {HttpContext.Connection.RemoteIpAddress}");
                
                // Проверяем авторизацию (если токен передан через query параметр)
                if (!string.IsNullOrEmpty(token))
                {
                    _logger.LogInformation($"[STREAM] Проверяем токен из query параметра, TaskId: {taskId}");
                    // TODO: Добавить валидацию JWT токена
                }
                
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

        // ===== ЭКСПОРТ/ИМПОРТ ПЛАНОВ ПОДПИСОК =====

        [HttpPost("export-subscription-plans")]
        public async Task<IActionResult> StartSubscriptionPlanExport()
        {
            try
            {
                _logger.LogInformation("Запрос на запуск экспорта планов подписок");
                var taskId = await _subscriptionPlanExportService.StartExportAsync();
                _logger.LogInformation($"Экспорт планов подписок запущен с TaskId: {taskId}");
                return Ok(new { TaskId = taskId });
            }
            catch (InvalidOperationException invalidOpEx)
            {
                _logger.LogWarning($"Попытка запуска экспорта планов при активном процессе: {invalidOpEx.Message}");
                return BadRequest(invalidOpEx.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при запуске экспорта планов подписок");
                return StatusCode(500, $"Внутренняя ошибка сервера: {ex.Message}");
            }
        }

        [HttpGet("subscription-plan-export-progress/{taskId}")]
        public IActionResult GetSubscriptionPlanExportProgress(Guid taskId)
        {
            try
            {
                _logger.LogDebug($"Запрос прогресса экспорта планов, TaskId: {taskId}");
                var status = _subscriptionPlanExportService.GetStatus(taskId);
                
                if (status.IsError)
                {
                    _logger.LogError($"Экспорт планов завершился с ошибкой, TaskId: {taskId}, Error: {status.ErrorDetails}");
                }
                
                return Ok(status);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Критическая ошибка при получении прогресса экспорта планов, TaskId: {taskId}");
                return StatusCode(500, $"Внутренняя ошибка сервера: {ex.Message}");
            }
        }

        [HttpGet("download-exported-subscription-plans/{taskId}")]
        public IActionResult DownloadExportedSubscriptionPlans(Guid taskId, [FromQuery] string token = null)
        {
            var startTime = DateTime.UtcNow;
            try
            {
                _logger.LogInformation($"[PLAN-DOWNLOAD] Запрос на скачивание файла экспорта планов подписок, TaskId: {taskId}, IP: {HttpContext.Connection.RemoteIpAddress}");
                
                // Логируем заголовки запроса для диагностики
                var userAgent = HttpContext.Request.Headers["User-Agent"].ToString();
                var rangeHeader = HttpContext.Request.Headers["Range"].ToString();
                _logger.LogInformation($"[PLAN-DOWNLOAD] User-Agent: {userAgent}, Range: {rangeHeader}, TaskId: {taskId}");
                
                // Проверяем авторизацию (если токен передан через query параметр)
                if (!string.IsNullOrEmpty(token))
                {
                    _logger.LogInformation($"[PLAN-DOWNLOAD] Проверяем токен из query параметра, TaskId: {taskId}");
                }
                
                // Проверяем статус экспорта с детальным логированием
                _logger.LogInformation($"[PLAN-DOWNLOAD] Получаем статус экспорта планов, TaskId: {taskId}");
                var status = _subscriptionPlanExportService.GetStatus(taskId);
                _logger.LogInformation($"[PLAN-DOWNLOAD] Статус экспорта планов - Progress: {status.Progress}%, IsError: {status.IsError}, ErrorDetails: '{status.ErrorDetails}', TaskId: {taskId}");
                
                if (status.IsError)
                {
                    _logger.LogWarning($"[PLAN-DOWNLOAD] 400 BadRequest - Экспорт планов завершился с ошибкой: {status.ErrorDetails}, TaskId: {taskId}");
                    return BadRequest($"Экспорт планов завершился с ошибкой: {status.ErrorDetails}");
                }
                
                if (status.Progress < 100)
                {
                    _logger.LogWarning($"[PLAN-DOWNLOAD] 400 BadRequest - Экспорт планов еще не завершен ({status.Progress}%), TaskId: {taskId}");
                    return BadRequest($"Экспорт планов еще не завершен. Прогресс: {status.Progress}%");
                }
                
                _logger.LogInformation($"[PLAN-DOWNLOAD] Статус экспорта планов корректный, получаем файл, TaskId: {taskId}");
                var file = _subscriptionPlanExportService.GetExportedFile(taskId);
                if (file == null)
                {
                    _logger.LogError($"[PLAN-DOWNLOAD] GetExportedFile вернул null, TaskId: {taskId}");
                    return NotFound("Файл экспорта планов не найден в системе.");
                }
                
                if (!file.Exists)
                {
                    _logger.LogError($"[PLAN-DOWNLOAD] Файл экспорта планов не существует на диске: {file.FullName}, TaskId: {taskId}");
                    return NotFound("Файл экспорта планов не найден на диске.");
                }

                var fileSizeMB = file.Length / (1024.0 * 1024.0);
                _logger.LogInformation($"[PLAN-DOWNLOAD] Файл экспорта планов найден: {file.FullName}, размер: {fileSizeMB:F2} MB, TaskId: {taskId}");
                
                // Проверяем, что файл доступен для чтения
                try
                {
                    using (var testStream = System.IO.File.OpenRead(file.FullName))
                    {
                        var testBuffer = new byte[1024];
                        var bytesRead = testStream.Read(testBuffer, 0, 1024);
                        _logger.LogInformation($"[PLAN-DOWNLOAD] Файл планов успешно прочитан, первые {bytesRead} байт получены, TaskId: {taskId}");
                    }
                }
                catch (Exception readEx)
                {
                    _logger.LogError(readEx, $"[PLAN-DOWNLOAD] Ошибка при тестовом чтении файла планов, TaskId: {taskId}");
                    return StatusCode(500, "Файл планов поврежден или недоступен для чтения");
                }
                
                // Создаем результат
                _logger.LogInformation($"[PLAN-DOWNLOAD] Создаем PhysicalFileResult для планов, TaskId: {taskId}");
                var result = PhysicalFile(file.FullName, "application/zip", $"subscription_plans_export_{taskId}.zip");
                
                // Включаем поддержку Range requests для больших файлов (позволяет докачку)
                result.EnableRangeProcessing = true;
                
                var processingTime = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogInformation($"[PLAN-DOWNLOAD] PhysicalFileResult для планов создан за {processingTime:F2}ms, возвращаем результат, TaskId: {taskId}");
                
                return result;
            }
            catch (Exception ex)
            {
                var processingTime = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogError(ex, $"[PLAN-DOWNLOAD] КРИТИЧЕСКАЯ ОШИБКА при обработке запроса загрузки планов за {processingTime:F2}ms, TaskId: {taskId}");
                return StatusCode(500, $"Внутренняя ошибка сервера: {ex.Message}");
            }
        }

        [HttpPost("cancel-subscription-plan-export/{taskId}")]
        public IActionResult CancelSubscriptionPlanExport(Guid taskId)
        {
            try
            {
                _subscriptionPlanExportService.CancelExport(taskId);
                _logger.LogInformation($"Экспорт планов отменён, TaskId: {taskId}");
                return Ok(new { Message = "Экспорт планов отменён" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка при отмене экспорта планов, TaskId: {taskId}");
                return StatusCode(500, $"Внутренняя ошибка сервера: {ex.Message}");
            }
        }

        // ИМПОРТ ПЛАНОВ ПОДПИСОК

        [HttpPost("start-subscription-plan-import")]
        public IActionResult StartSubscriptionPlanImport([FromQuery] long? expectedFileSize = null)
        {
            try
            {
                var importId = _subscriptionPlanImportService.StartImport(expectedFileSize ?? 0);
                _logger.LogInformation($"Импорт планов подписок начат, ImportId: {importId}");
                return Ok(new { ImportId = importId });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning($"Невозможно начать импорт планов: {ex.Message}");
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при запуске импорта планов подписок");
                return StatusCode(500, ex.Message);
            }
        }

        [HttpPut("subscription-plan-import/{importId}/file-size")]
        public IActionResult UpdateSubscriptionPlanImportFileSize(Guid importId, [FromBody] UpdateFileSizeRequest request)
        {
            try
            {
                _subscriptionPlanImportService.UpdateExpectedFileSize(importId, request.ExpectedFileSize);
                return Ok();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка при обновлении размера файла планов, ImportId: {importId}");
                return BadRequest(ex.Message);
            }
        }

        [HttpPost("subscription-plan-import/{importId}/chunk")]
        public IActionResult UploadSubscriptionPlanImportChunk(Guid importId, IFormFile chunk)
        {
            try
            {
                if (chunk == null || chunk.Length == 0)
                {
                    return BadRequest("Файл не предоставлен или пустой");
                }

                using var stream = chunk.OpenReadStream();
                var buffer = new byte[chunk.Length];
                var totalRead = 0;
                int bytesRead;

                while (totalRead < chunk.Length && (bytesRead = stream.Read(buffer, totalRead, (int)chunk.Length - totalRead)) > 0)
                {
                    totalRead += bytesRead;
                }

                _subscriptionPlanImportService.WriteFileChunk(importId, buffer, totalRead);
                return Ok();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка при загрузке чанка планов, ImportId: {importId}");
                return BadRequest(ex.Message);
            }
        }

        [HttpPost("subscription-plan-import/{importId}/finish")]
        public async Task<IActionResult> FinishSubscriptionPlanImport(Guid importId)
        {
            try
            {
                await _subscriptionPlanImportService.FinishFileUploadAsync(importId);
                return Ok(new { Message = "Загрузка файла планов завершена, начинается импорт" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка при завершении загрузки файла планов, ImportId: {importId}");
                return BadRequest(ex.Message);
            }
        }

        [HttpGet("subscription-plan-import-progress/{importId}")]
        public IActionResult GetSubscriptionPlanImportProgress(Guid importId)
        {
            try
            {
                var progress = _subscriptionPlanImportService.GetImportProgress(importId);
                return Ok(progress);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка при получении прогресса импорта планов, ImportId: {importId}");
                return StatusCode(500, ex.Message);
            }
        }

        [HttpPost("cancel-subscription-plan-import/{importId}")]
        public async Task<IActionResult> CancelSubscriptionPlanImport(Guid importId)
        {
            try
            {
                await _subscriptionPlanImportService.CancelImportAsync(importId);
                return Ok(new { Message = "Импорт планов отменён" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Ошибка при отмене импорта планов, ImportId: {importId}");
                return StatusCode(500, ex.Message);
            }
        }
    }

    public class AssignSubscriptionPlanRequest
    {
        public int PlanId { get; set; } // 0 = отключить
        public bool AutoRenew { get; set; }
    }

    public class UpdateFileSizeRequest
    {
        public long ExpectedFileSize { get; set; }
    }
}
