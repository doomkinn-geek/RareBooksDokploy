using System.ComponentModel.DataAnnotations;

namespace RareBooksService.Common.Models
{
    /// <summary>
    /// Токен для привязки Telegram аккаунта к пользователю
    /// </summary>
    public class TelegramLinkToken
    {
        [Key]
        public int Id { get; set; }
        
        /// <summary>
        /// Одноразовый токен
        /// </summary>
        [Required]
        [StringLength(50)]
        public string Token { get; set; }
        
        /// <summary>
        /// ID пользователя, для которого создан токен
        /// </summary>
        [Required]
        public string UserId { get; set; }
        
        /// <summary>
        /// Пользователь
        /// </summary>
        public ApplicationUser User { get; set; }
        
        /// <summary>
        /// Дата создания токена
        /// </summary>
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        /// <summary>
        /// Дата истечения токена (24 часа по умолчанию)
        /// </summary>
        public DateTime ExpiresAt { get; set; } = DateTime.UtcNow.AddHours(24);
        
        /// <summary>
        /// Использован ли токен
        /// </summary>
        public bool IsUsed { get; set; } = false;
        
        /// <summary>
        /// Дата использования токена
        /// </summary>
        public DateTime? UsedAt { get; set; }
        
        /// <summary>
        /// Telegram ID пользователя, который использовал токен
        /// </summary>
        [StringLength(50)]
        public string? UsedByTelegramId { get; set; }
        
        /// <summary>
        /// Username пользователя в Telegram
        /// </summary>
        [StringLength(100)]
        public string? TelegramUsername { get; set; }
    }
}
