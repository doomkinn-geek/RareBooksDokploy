using System;

namespace RareBooksService.Common.Models
{
    public class UserFavoriteBook
    {
        public int Id { get; set; }
        
        // Связь с пользователем
        public string UserId { get; set; }
        public ApplicationUser User { get; set; }
        
        // ID книги из RegularBaseBook
        public int BookId { get; set; }
        
        // Дата добавления в избранное
        public DateTime AddedDate { get; set; } = DateTime.UtcNow;
    }
} 