using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using MayMessenger.Application.DTOs;
using MayMessenger.Application.Services;
using MayMessenger.Domain.Entities;
using MayMessenger.Domain.Interfaces;

namespace MayMessenger.API.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IImageCompressionService _imageCompressionService;
    private readonly IWebHostEnvironment _environment;
    
    public UsersController(
        IUnitOfWork unitOfWork, 
        IImageCompressionService imageCompressionService,
        IWebHostEnvironment environment)
    {
        _unitOfWork = unitOfWork;
        _imageCompressionService = imageCompressionService;
        _environment = environment;
    }
    
    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        return Guid.Parse(userIdClaim ?? throw new UnauthorizedAccessException());
    }
    
    /// <summary>
    /// Получить профиль текущего пользователя
    /// </summary>
    [HttpGet("me")]
    public async Task<ActionResult<UserDto>> GetMyProfile()
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user == null)
        {
            return NotFound("User not found");
        }
        
        return Ok(new UserDto
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            DisplayName = user.DisplayName,
            Avatar = user.Avatar,
            Role = user.Role,
            IsOnline = user.IsOnline,
            LastSeenAt = user.LastSeenAt,
            Bio = user.Bio,
            Status = user.Status,
            CreatedAt = user.CreatedAt
        });
    }
    
    /// <summary>
    /// Обновить профиль текущего пользователя
    /// </summary>
    [HttpPut("me")]
    public async Task<ActionResult<UserDto>> UpdateMyProfile([FromBody] UpdateProfileDto dto)
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user == null)
        {
            return NotFound("Пользователь не найден");
        }
        
        // Update only provided fields
        if (!string.IsNullOrEmpty(dto.DisplayName))
        {
            user.DisplayName = dto.DisplayName;
        }
        
        if (dto.Bio != null)
        {
            user.Bio = dto.Bio;
        }
        
        if (dto.Status != null)
        {
            user.Status = dto.Status;
        }
        
        user.UpdatedAt = DateTime.UtcNow;
        
        await _unitOfWork.Users.UpdateAsync(user);
        await _unitOfWork.SaveChangesAsync();
        
        return Ok(new UserDto
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            DisplayName = user.DisplayName,
            Avatar = user.Avatar,
            Role = user.Role,
            IsOnline = user.IsOnline,
            LastSeenAt = user.LastSeenAt,
            Bio = user.Bio,
            Status = user.Status,
            CreatedAt = user.CreatedAt
        });
    }
    
    /// <summary>
    /// Загрузить аватарку
    /// </summary>
    [HttpPost("me/avatar")]
    public async Task<ActionResult<UserDto>> UploadAvatar(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest("Файл не выбран");
        }
        
        // Validate file type
        var allowedTypes = new[] { "image/jpeg", "image/png", "image/gif", "image/webp" };
        if (!allowedTypes.Contains(file.ContentType.ToLower()))
        {
            return BadRequest("Разрешены только изображения (JPEG, PNG, GIF, WebP)");
        }
        
        // Validate file size (max 10MB)
        if (file.Length > 10 * 1024 * 1024)
        {
            return BadRequest("Файл слишком большой. Максимум 10 МБ");
        }
        
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user == null)
        {
            return NotFound("Пользователь не найден");
        }
        
        try
        {
            // Delete old avatar if exists
            if (!string.IsNullOrEmpty(user.Avatar))
            {
                var oldAvatarPath = Path.Combine(_environment.WebRootPath, user.Avatar.TrimStart('/'));
                if (System.IO.File.Exists(oldAvatarPath))
                {
                    System.IO.File.Delete(oldAvatarPath);
                }
            }
            
            // Create avatars directory if not exists
            var avatarsDir = Path.Combine(_environment.WebRootPath, "avatars", "users");
            if (!Directory.Exists(avatarsDir))
            {
                Directory.CreateDirectory(avatarsDir);
            }
            
            // Generate unique filename
            var fileName = $"{userId}_{DateTime.UtcNow.Ticks}.webp";
            var filePath = Path.Combine(avatarsDir, fileName);
            
            // Read and compress image
            using var stream = file.OpenReadStream();
            using var memoryStream = new MemoryStream();
            await stream.CopyToAsync(memoryStream);
            var imageData = memoryStream.ToArray();
            
            // Compress to WebP with max 512x512 for avatar
            var compressedData = await _imageCompressionService.CompressImageAsync(imageData, 512, 512);
            await System.IO.File.WriteAllBytesAsync(filePath, compressedData);
            
            // Update user avatar URL
            user.Avatar = $"/avatars/users/{fileName}";
            user.UpdatedAt = DateTime.UtcNow;
            
            await _unitOfWork.Users.UpdateAsync(user);
            await _unitOfWork.SaveChangesAsync();
            
            return Ok(new UserDto
            {
                Id = user.Id,
                PhoneNumber = user.PhoneNumber,
                DisplayName = user.DisplayName,
                Avatar = user.Avatar,
                Role = user.Role,
                IsOnline = user.IsOnline,
                LastSeenAt = user.LastSeenAt,
                Bio = user.Bio,
                Status = user.Status,
                CreatedAt = user.CreatedAt
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, $"Ошибка загрузки: {ex.Message}");
        }
    }
    
    /// <summary>
    /// Удалить аватарку
    /// </summary>
    [HttpDelete("me/avatar")]
    public async Task<ActionResult<UserDto>> DeleteAvatar()
    {
        var userId = GetCurrentUserId();
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user == null)
        {
            return NotFound("Пользователь не найден");
        }
        
        // Delete avatar file if exists
        if (!string.IsNullOrEmpty(user.Avatar))
        {
            var avatarPath = Path.Combine(_environment.WebRootPath, user.Avatar.TrimStart('/'));
            if (System.IO.File.Exists(avatarPath))
            {
                System.IO.File.Delete(avatarPath);
            }
            
            user.Avatar = null;
            user.UpdatedAt = DateTime.UtcNow;
            
            await _unitOfWork.Users.UpdateAsync(user);
            await _unitOfWork.SaveChangesAsync();
        }
        
        return Ok(new UserDto
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            DisplayName = user.DisplayName,
            Avatar = user.Avatar,
            Role = user.Role,
            IsOnline = user.IsOnline,
            LastSeenAt = user.LastSeenAt,
            Bio = user.Bio,
            Status = user.Status,
            CreatedAt = user.CreatedAt
        });
    }
    
    /// <summary>
    /// Получить профиль пользователя по ID (публичный)
    /// </summary>
    [HttpGet("{userId}")]
    public async Task<ActionResult<UserDto>> GetUserProfile(Guid userId)
    {
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        
        if (user == null)
        {
            return NotFound("Пользователь не найден");
        }
        
        return Ok(new UserDto
        {
            Id = user.Id,
            PhoneNumber = user.PhoneNumber,
            DisplayName = user.DisplayName,
            Avatar = user.Avatar,
            Role = user.Role,
            IsOnline = user.IsOnline,
            LastSeenAt = user.LastSeenAt,
            Bio = user.Bio,
            Status = user.Status,
            CreatedAt = user.CreatedAt
        });
    }
    
    /// <summary>
    /// Создать персональный invite link (1 использование, срок 7 дней)
    /// </summary>
    [HttpPost("invite-link")]
    public async Task<ActionResult<InviteLinkDto>> CreateInviteLink()
    {
        var userId = GetCurrentUserId();
        
        var inviteLink = new InviteLink
        {
            Code = Guid.NewGuid().ToString("N")[..8].ToUpper(),
            CreatedBy = userId,
            UsesLeft = 1, // Одно использование
            ExpiresAt = DateTime.UtcNow.AddDays(7), // Срок 7 дней
            IsActive = true
        };
        
        await _unitOfWork.InviteLinks.AddAsync(inviteLink);
        await _unitOfWork.SaveChangesAsync();
        
        return Ok(new InviteLinkDto
        {
            Id = inviteLink.Id,
            Code = inviteLink.Code,
            UsesLeft = inviteLink.UsesLeft,
            ExpiresAt = inviteLink.ExpiresAt,
            IsActive = inviteLink.IsActive,
            CreatedAt = inviteLink.CreatedAt
        });
    }
    
    /// <summary>
    /// Получить свои активные invite links
    /// </summary>
    [HttpGet("my-invite-links")]
    public async Task<ActionResult<IEnumerable<InviteLinkDto>>> GetMyInviteLinks()
    {
        var userId = GetCurrentUserId();
        var allLinks = await _unitOfWork.InviteLinks.GetAllAsync();
        
        var myLinks = allLinks
            .Where(l => l.CreatedBy == userId && l.IsActive && 
                       (l.ExpiresAt == null || l.ExpiresAt > DateTime.UtcNow) &&
                       (l.UsesLeft == null || l.UsesLeft > 0))
            .OrderByDescending(l => l.CreatedAt)
            .Select(l => new InviteLinkDto
            {
                Id = l.Id,
                Code = l.Code,
                UsesLeft = l.UsesLeft,
                ExpiresAt = l.ExpiresAt,
                IsActive = l.IsActive,
                CreatedAt = l.CreatedAt
            });
        
        return Ok(myLinks);
    }
    
    /// <summary>
    /// Получить список всех пользователей (для создания чатов)
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<UserDto>>> GetUsers()
    {
        var currentUserId = GetCurrentUserId();
        var users = await _unitOfWork.Users.GetAllAsync();
        
        var userDtos = users
            .Where(u => u.Id != currentUserId) // Исключаем текущего пользователя
            .Select(u => new UserDto
            {
                Id = u.Id,
                PhoneNumber = u.PhoneNumber,
                DisplayName = u.DisplayName,
                Avatar = u.Avatar,
                Role = u.Role,
                IsOnline = u.IsOnline,
                LastSeenAt = u.LastSeenAt
            });
        
        return Ok(userDtos);
    }
    
    /// <summary>
    /// Поиск зарегистрированных пользователей по имени или номеру телефона
    /// </summary>
    [HttpGet("search")]
    public async Task<ActionResult<IEnumerable<UserDto>>> SearchUsers(
        [FromQuery] string query, 
        [FromQuery] bool contactsOnly = false)
    {
        if (string.IsNullOrWhiteSpace(query) || query.Length < 2)
        {
            return BadRequest("Query must be at least 2 characters");
        }
        
        var currentUserId = GetCurrentUserId();
        
        if (contactsOnly)
        {
            // Search only in user's contacts (from phone book)
            var contactResults = await _unitOfWork.Contacts.SearchUserContactsAsync(currentUserId, query);
            
            var userDtos = contactResults
                .Take(20)
                .Select(r => new UserDto
                {
                    Id = r.user.Id,
                    PhoneNumber = r.user.PhoneNumber,
                    DisplayName = r.contactDisplayName ?? r.user.DisplayName, // Use phone book name if available
                    Avatar = r.user.Avatar,
                    Role = r.user.Role,
                    IsOnline = r.user.IsOnline,
                    LastSeenAt = r.user.LastSeenAt
                });
            
            return Ok(userDtos);
        }
        else
        {
            // Search all users (original behavior)
            var users = await _unitOfWork.Users.GetAllAsync();
            
            // Search by display name or phone number
            var searchResults = users
                .Where(u => u.Id != currentUserId && (
                    u.DisplayName.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                    u.PhoneNumber.Contains(query)
                ))
                .Take(20) // Limit results
                .Select(u => new UserDto
                {
                    Id = u.Id,
                    PhoneNumber = u.PhoneNumber,
                    DisplayName = u.DisplayName,
                    Avatar = u.Avatar,
                    Role = u.Role,
                    IsOnline = u.IsOnline,
                    LastSeenAt = u.LastSeenAt
                });
            
            return Ok(searchResults);
        }
    }
    
    /// <summary>
    /// Получить статусы (онлайн/офлайн) для списка пользователей
    /// </summary>
    [HttpGet("status")]
    public async Task<ActionResult<IEnumerable<UserStatusDto>>> GetUsersStatus(
        [FromQuery] List<Guid> userIds)
    {
        if (userIds == null || !userIds.Any())
        {
            return BadRequest("UserIds cannot be empty");
        }
        
        var currentUserId = GetCurrentUserId();
        var statusList = new List<UserStatusDto>();
        
        foreach (var userId in userIds.Distinct().Take(100)) // Limit to 100 users
        {
            // Skip current user
            if (userId == currentUserId) continue;
            
            var user = await _unitOfWork.Users.GetByIdAsync(userId);
            if (user != null)
            {
                statusList.Add(new UserStatusDto
                {
                    UserId = user.Id,
                    IsOnline = user.IsOnline,
                    LastSeenAt = user.LastSeenAt
                });
            }
        }
        
        return Ok(statusList);
    }
}

