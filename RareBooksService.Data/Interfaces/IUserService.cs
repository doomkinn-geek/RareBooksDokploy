using RareBooksService.Common.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Data.Interfaces
{
    public interface IUserService
    {
        Task<ApplicationUser> GetUserByIdAsync(string userId);
        Task<IEnumerable<ApplicationUser>> GetAllUsersAsync();
        Task<IEnumerable<UserSearchHistory>> GetUserSearchHistoryAsync(string userId);
        Task AddSearchHistoryAsync(UserSearchHistory history);
        Task<bool> UpdateUserSubscriptionAsync(string userId, bool hasSubscription);
        Task<bool> AssignRoleAsync(string userId, string role);
        Task<List<ApplicationUser>> GetAllUsersWithSubscriptionsAsync();

        // Методы для работы с избранными книгами
        Task<IEnumerable<UserFavoriteBook>> GetUserFavoriteBooksAsync(string userId);
        Task<bool> AddBookToFavoritesAsync(string userId, int bookId);
        Task<bool> RemoveBookFromFavoritesAsync(string userId, int bookId);
        Task<bool> IsBookInFavoritesAsync(string userId, int bookId);
    }
}
