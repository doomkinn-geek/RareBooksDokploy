using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection; // Добавлено для GetRequiredService
using Microsoft.Extensions.Logging; // Добавлено для ILogger
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using RareBooksService.Common.Models;
using RareBooksService.WebApi.Services;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.WebApi.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : BaseController
    {
        private readonly SignInManager<ApplicationUser> _signInManager;
        private readonly IConfiguration _configuration;
        private readonly ILogger<AuthController> _logger; // Добавлено для логирования
        private readonly ICaptchaService _captchaService;
        private readonly IMemoryCache _memoryCache;

        public AuthController(
            UserManager<ApplicationUser> userManager,
            SignInManager<ApplicationUser> signInManager,
            IConfiguration configuration,
            ILogger<AuthController> logger,
            ICaptchaService captchaService,
            IMemoryCache memoryCache)
            : base(userManager)
        {
            _signInManager = signInManager;
            _configuration = configuration;
            _logger = logger;
            _captchaService = captchaService;
            _memoryCache = memoryCache;
        }

        [HttpGet("captcha")]
        public IActionResult GetCaptcha()
        {
            var (imageData, captchaCode) = _captchaService.GenerateCaptchaImage();

            // Генерируем токен (GUID)
            var captchaToken = Guid.NewGuid().ToString();

            // Сохраняем captchaCode в кэш на 5 минут
            _memoryCache.Set(captchaToken, captchaCode, TimeSpan.FromMinutes(5));

            // Устанавливаем заголовок с токеном капчи
            Response.Headers["X-Captcha-Token"] = captchaToken;

            // Возвращаем картинку
            return File(imageData, "image/png");
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterModel model)
        {
            // Проверяем captcha
            if (!_memoryCache.TryGetValue(model.CaptchaToken, out string storedCode))
            {
                return BadRequest(new { error = "Captcha token is invalid or expired." });
            }

            if (!string.Equals(storedCode, model.CaptchaCode, StringComparison.OrdinalIgnoreCase))
            {
                return BadRequest(new { error = "Invalid captcha code." });
            }

            // Капча пройдена, можно удалить из кеша
            _memoryCache.Remove(model.CaptchaToken);

            _logger.LogInformation("Регистрация пользователя с email: {Email}", model.Email);

            var user = new ApplicationUser { UserName = model.Email, Email = model.Email };
            var result = await _userManager.CreateAsync(user, model.Password);

            if (result.Succeeded)
            {
                _logger.LogInformation("Пользователь {Email} успешно зарегистрирован", model.Email);
                
                // Если у пользователя задана роль в свойстве Role, добавляем ее также в Identity
                if (!string.IsNullOrEmpty(user.Role))
                {
                    _logger.LogInformation("Добавление роли {Role} в Identity для пользователя {Email}", user.Role, model.Email);
                    
                    // Проверяем, существует ли роль, и если нет - создаем ее
                    var roleManager = HttpContext.RequestServices.GetRequiredService<RoleManager<IdentityRole>>();
                    if (!await roleManager.RoleExistsAsync(user.Role))
                    {
                        _logger.LogInformation("Роль {Role} не существует, создаем ее", user.Role);
                        await roleManager.CreateAsync(new IdentityRole(user.Role));
                    }
                    
                    // Добавляем пользователя в роль
                    var addToRoleResult = await _userManager.AddToRoleAsync(user, user.Role);
                    if (!addToRoleResult.Succeeded)
                    {
                        _logger.LogWarning("Не удалось добавить пользователя {Email} в роль {Role}: {Errors}", 
                            model.Email, user.Role, string.Join(", ", addToRoleResult.Errors.Select(e => e.Description)));
                    }
                    else
                    {
                        _logger.LogInformation("Пользователь {Email} успешно добавлен в роль {Role}", model.Email, user.Role);
                    }
                }
                
                await _signInManager.SignInAsync(user, isPersistent: false);
                var token = await GenerateJwtTokenAsync(user);
                _logger.LogInformation("JWT токен сгенерирован для пользователя {Email}", model.Email);
                return Ok(new { Token = token });
            }

            var errorDescription = result.Errors.FirstOrDefault()?.Description;
            _logger.LogWarning("Ошибка при регистрации пользователя {Email}: {Error}", model.Email, errorDescription);
            return BadRequest(errorDescription);
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginModel model)
        {
            _logger.LogInformation("Попытка входа для пользователя {Email}", model.Email);

            try
            {
                var result = await _signInManager.PasswordSignInAsync(model.Email, model.Password, isPersistent: false, lockoutOnFailure: false);

                if (result.Succeeded)
                {
                    var user = await _userManager.FindByEmailAsync(model.Email);
                    
                    // Логируем роль пользователя для отладки
                    _logger.LogInformation("Пользователь {Email} имеет роль в модели: {Role}", user.Email, user.Role);
                    var identityRoles = await _userManager.GetRolesAsync(user);
                    _logger.LogInformation("Пользователь {Email} имеет роли в Identity: {Roles}", user.Email, string.Join(", ", identityRoles));
                    
                    var token = await GenerateJwtTokenAsync(user);
                    _logger.LogInformation("Пользователь {Email} успешно вошел в систему", model.Email);
                    return Ok(new { Token = token, User = new { user.Email, user.UserName, user.HasSubscription, user.Role } });
                }

                _logger.LogWarning("Неудачная попытка входа для пользователя {Email}", model.Email);
                return Unauthorized(new { Message = "Неверные учетные данные" });
            }
            catch (PostgresException pgEx)
            {
                _logger.LogError(pgEx, "Проблема с PostgreSQL: {Message}", pgEx.Message);
                // Вернём более конкретный ответ
                return StatusCode(500, new { Message = "Ошибка в базе данных (PostgreSQL). Обратитесь к администратору." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка во время входа для пользователя {Email}", model.Email);
                return StatusCode(500, new { Message = "Произошла ошибка во время входа" });
            }
        }

        [HttpGet("user")]
        public async Task<IActionResult> GetUser()
        {
            _logger.LogInformation("Запрос информации о текущем пользователе");

            // 14.02.2025 - не работало обновление, т.к. при генерации токена информация об id клалась в другой ClaimTypes
            //var userId = User.FindFirstValue(ClaimTypes.Sid);
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (userId == null)
            {
                _logger.LogWarning("Не удалось получить идентификатор текущего пользователя");
                return NotFound("Пользователь не найден");
            }

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                _logger.LogWarning("Пользователь с ID {UserId} не найден", userId);
                return NotFound("Пользователь не найден");
            }

            _logger.LogInformation("Информация о пользователе с ID {UserId} успешно получена", userId);
            return Ok(user);
        }

        private async Task<string> GenerateJwtTokenAsync(ApplicationUser user)
        {
            _logger.LogInformation("Генерация JWT токена для пользователя {Email}", user.Email);

            var claims = new List<Claim>
            {
                //new Claim(JwtRegisteredClaimNames.Sub, user.UserName),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
                //new Claim(ClaimTypes.Sid, user.Id),
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Email, user.Email)
            };

            // Добавление роли пользователя к утверждениям из Identity
            var roles = await _userManager.GetRolesAsync(user);
            _logger.LogInformation("Роли пользователя {Email} из Identity: {Roles}", user.Email, string.Join(", ", roles));
            claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));
            
            // Проверка и добавление роли из свойства ApplicationUser.Role, если она не присутствует в Identity
            if (!string.IsNullOrEmpty(user.Role) && !roles.Contains(user.Role))
            {
                _logger.LogInformation("Добавление роли из свойства ApplicationUser.Role: {Role}", user.Role);
                claims.Add(new Claim(ClaimTypes.Role, user.Role));
            }
            
            _logger.LogInformation("Все роли для пользователя {Email}: {Roles}", user.Email, 
                string.Join(", ", claims.Where(c => c.Type == ClaimTypes.Role).Select(c => c.Value)));

            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_configuration["Jwt:Key"]));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

            var token = new JwtSecurityToken(
                issuer: _configuration["Jwt:Issuer"],
                audience: _configuration["Jwt:Audience"],
                claims: claims,
                expires: DateTime.Now.AddDays(30),
                signingCredentials: creds);

            var tokenString = new JwtSecurityTokenHandler().WriteToken(token);
            _logger.LogInformation("JWT токен успешно сгенерирован для пользователя {Email}", user.Email);

            return tokenString;
        }
    }
}
