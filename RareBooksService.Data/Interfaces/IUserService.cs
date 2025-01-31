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
    }
}
