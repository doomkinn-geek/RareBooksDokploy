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

        /// <summary>
        /// Получение списка избранных книг пользователя
        /// </summary>
        [HttpGet("{userId}/favorites")]
        public async Task<ActionResult<IEnumerable<UserFavoriteBookDto>>> GetUserFavoriteBooks(string userId)
        {
            _logger.LogInformation("Запрос на получение списка избранных книг пользователя с ID: {UserId}", userId);

            // Проверяем, что пользователь запрашивает свои данные или является администратором
            var currentUser = await GetCurrentUserAsync();
            if (currentUser == null)
            {
                _logger.LogWarning("Текущий пользователь не найден или не авторизован");
                return Unauthorized("Пользователь не авторизован");
            }

            // Разрешаем доступ только к своим избранным или администратору
            if (currentUser.Id != userId && !IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: пользователь пытается получить избранные книги другого пользователя");
                return Forbid("Вы можете просматривать только свои избранные книги");
            }

            var favoriteBooks = await _userService.GetUserFavoriteBooksAsync(userId);

            var favoriteBooksDto = favoriteBooks.Select(fb => new UserFavoriteBookDto
            {
                Id = fb.Id,
                BookId = fb.BookId,
                AddedDate = fb.AddedDate
            }).OrderByDescending(fb => fb.AddedDate);

            _logger.LogInformation("Список избранных книг для пользователя с ID {UserId} успешно получен. Количество книг: {Count}", 
                userId, favoriteBooksDto.Count());

            return Ok(favoriteBooksDto);
        }

        /// <summary>
        /// Удаление книги из избранного
        /// </summary>
        [HttpDelete("{userId}/favorites/{bookId}")]
        public async Task<ActionResult> RemoveBookFromFavorites(string userId, int bookId)
        {
            _logger.LogInformation("Запрос на удаление книги {BookId} из избранного пользователя с ID: {UserId}", bookId, userId);

            // Проверяем, что пользователь удаляет свои данные или является администратором
            var currentUser = await GetCurrentUserAsync();
            if (currentUser == null)
            {
                _logger.LogWarning("Текущий пользователь не найден или не авторизован");
                return Unauthorized("Пользователь не авторизован");
            }

            // Разрешаем удаление только своих избранных или администратору
            if (currentUser.Id != userId && !IsUserAdmin(currentUser))
            {
                _logger.LogWarning("Доступ запрещен: пользователь пытается удалить книгу из избранного другого пользователя");
                return Forbid("Вы можете удалять книги только из своего списка избранных");
            }

            var success = await _userService.RemoveBookFromFavoritesAsync(userId, bookId);
            if (!success)
            {
                _logger.LogWarning("Книга с ID {BookId} не найдена в избранном пользователя с ID {UserId}", bookId, userId);
                return NotFound("Книга не найдена в избранном");
            }

            _logger.LogInformation("Книга с ID {BookId} успешно удалена из избранного пользователя с ID {UserId}", bookId, userId);
            return NoContent();
        }
    }
} 