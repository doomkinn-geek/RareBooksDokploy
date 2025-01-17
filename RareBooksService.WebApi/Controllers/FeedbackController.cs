using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.WebApi.Services;
using System.Linq;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // Требуется авторизация, чтобы только залогиненные могли отправлять предложения
    public class FeedbackController : BaseController
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IEmailSenderService _emailSenderService;
        private readonly ILogger<FeedbackController> _logger;

        public FeedbackController(
            UserManager<ApplicationUser> userManager,
            IEmailSenderService emailSenderService,
            ILogger<FeedbackController> logger)
            : base(userManager)
        {
            _userManager = userManager;
            _emailSenderService = emailSenderService;
            _logger = logger;
        }

        /// <summary>
        /// DTO для принятия предложения от клиента
        /// </summary>
        public class FeedbackDto
        {
            public string Text { get; set; }
        }

        [HttpPost]
        public async Task<IActionResult> SendFeedback([FromBody] FeedbackDto dto)
        {
            if (dto == null || string.IsNullOrWhiteSpace(dto.Text))
            {
                return BadRequest("Пустое сообщение не допускается.");
            }

            // Текущий пользователь
            var currentUser = await GetCurrentUserAsync();
            if (currentUser == null)
            {
                // Хотя у нас [Authorize], но на всякий случай
                return Unauthorized("Требуется авторизация.");
            }

            // Ищем администратора(ов). Предположим, что у вас одна учётка с ролью Admin. 
            // Либо можно искать всех с ролью Admin:
            // var admins = await _userManager.GetUsersInRoleAsync("Admin");
            // var adminEmail = admins.Select(a => a.Email).FirstOrDefault();

            var admins = await _userManager.GetUsersInRoleAsync("Admin");
            var adminUser = admins.FirstOrDefault();
            if (adminUser == null)
            {
                _logger.LogWarning("Не найден ни один пользователь с ролью Admin. Куда отправлять?");
                return StatusCode(500, "Администратор не найден в системе");
            }

            string adminEmail = adminUser.Email; // E-mail администратора

            // Отправляем письмо через некий сервис IEmailSenderService
            var subject = $"Новое предложение от пользователя {currentUser.Email}";
            var body = $"Пользователь: {currentUser.Email}\n\nТекст предложения:\n{dto.Text}";

            try
            {
                await _emailSenderService.SendEmailAsync(adminEmail, subject, body);
                _logger.LogInformation("Предложение от {UserEmail} отправлено администратору {AdminEmail}", currentUser.Email, adminEmail);
                return Ok("Ваше предложение отправлено администратору.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при отправке письма администратору");
                return StatusCode(500, "Ошибка при отправке письма администратору.");
            }
        }
    }
}
