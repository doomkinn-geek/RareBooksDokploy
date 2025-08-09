using Microsoft.AspNetCore.Identity;
using System;
using System.Collections.Generic;

namespace RareBooksService.Common.Models
{
    public class ApplicationUser : IdentityUser
    {
        /// <summary>
        /// Дата и время регистрации пользователя (UTC)
        /// </summary>
        public DateTime CreatedAt { get; set; }

        public bool HasSubscription { get; set; }

        public List<UserSearchHistory> SearchHistory { get; set; }
            = new List<UserSearchHistory>();

        public string Role { get; set; } = "User";

        // Множество подписок пользователя (история). 
        // Связь (1 ко многим) — но нам нужно уметь быстро найти активную.
        public List<Subscription> Subscriptions { get; set; }
            = new List<Subscription>();

        // Можно сделать вычислимое свойство
        public Subscription? CurrentSubscription
        {
            get
            {
                // Возвращаем ту, у которой IsActive == true
                return Subscriptions?.FirstOrDefault(s => s.IsActive);
            }
        }

        // Избранные книги пользователя
        public List<UserFavoriteBook> FavoriteBooks { get; set; } 
            = new List<UserFavoriteBook>();
    }
}
