using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Dto;
using RareBooksService.Data.Interfaces;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class UserController : BaseController
    {
        private readonly IUserService _userService;
        private readonly ILogger<UserController> _logger;

        public UserController(
            IUserService userService,
            UserManager<ApplicationUser> userManager,
            ILogger<UserController> logger)
            : base(userManager)
        {
            _userService = userService;
            _logger = logger;
        }

        /// <summary>
        /// Получение информации о текущем пользователе
        /// </summary>
        [HttpGet("profile")]
        public async Task<ActionResult<ApplicationUser>> GetCurrentUserProfile()
        {
            _logger.LogInformation("Запрос на получение профиля текущего пользователя");

            var currentUser = await GetCurrentUserAsync();
            if (currentUser == null)
            {
                _logger.LogWarning("Текущий пользователь не найден или не авторизован");
                return NotFound("Пользователь не найден");
            }

            _logger.LogInformation("Профиль пользователя успешно получен");
            return Ok(currentUser);
        }

        /// <summary>
        /// Получение информации о пользователе по ID
        /// </summary>
        [HttpGet("{userId}")]
        public async Task<ActionResult<ApplicationUser>> GetUserById(string userId)
        {
            _logger.LogInformation("Запрос на получение информации о пользователе с ID: {UserId}", userId);

            // Проверяем, что пользователь запрашивает свои данные или является администратором
            var currentUser = await GetCurrentUserAsync();
            if (currentUser == null)
            {
                _logger.LogWarning("Текущий пользователь не найден или не авторизован");
                return Unauthorized("Пользователь не авторизован");
            }

            // Разрешаем доступ только к своему профилю или администратору
            if (currentUser.Id != userId && !IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: пользователь пытается получить данные другого пользователя");
                return Forbid("Вы можете просматривать только свой профиль");
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

        /// <summary>
        /// Получение истории поиска пользователя
        /// </summary>
        [HttpGet("{userId}/searchHistory")]
        public async Task<ActionResult<IEnumerable<UserSearchHistoryDto>>> GetUserSearchHistory(string userId)
        {
            _logger.LogInformation("Запрос на получение истории поиска пользователя с ID: {UserId}", userId);

            // Проверяем, что пользователь запрашивает свои данные или является администратором
            var currentUser = await GetCurrentUserAsync();
            if (currentUser == null)
            {
                _logger.LogWarning("Текущий пользователь не найден или не авторизован");
                return Unauthorized("Пользователь не авторизован");
            }

            // Разрешаем доступ только к своей истории или администратору
            if (currentUser.Id != userId && !IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: пользователь пытается получить историю поиска другого пользователя");
                return Forbid("Вы можете просматривать только свою историю поиска");
            }

            var history = await _userService.GetUserSearchHistoryAsync(userId);

            if (history == null || !history.Any())
            {
                _logger.LogInformation("История поиска для пользователя с ID {UserId} не найдена или пуста.", userId);
                return Ok(new List<UserSearchHistoryDto>()); // Возвращаем пустой список вместо 404
            }

            var historyDto = history.Select(h => new UserSearchHistoryDto
            {
                Id = h.Id,
                Query = h.Query,
                SearchDate = h.SearchDate,
                SearchType = h.SearchType
            }).OrderByDescending(h => h.SearchDate);

            _logger.LogInformation("История поиска для пользователя с ID {UserId} успешно получена. Количество записей: {HistoryCount}", userId, historyDto.Count());

            return Ok(historyDto);
        }
    }
} 