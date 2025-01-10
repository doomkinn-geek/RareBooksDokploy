using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Data.Services
{
    public class UserService : IUserService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RegularBaseBooksContext _context;

        public UserService(UserManager<ApplicationUser> userManager, RegularBaseBooksContext context)
        {
            _userManager = userManager;
            _context = context;
        }

        public async Task<ApplicationUser> GetUserByIdAsync(string userId)
        {
            return await _userManager.FindByIdAsync(userId);
        }

        public async Task<IEnumerable<ApplicationUser>> GetAllUsersAsync()
        {
            return await _userManager.Users.ToListAsync();
        }

        public async Task<IEnumerable<UserSearchHistory>> GetUserSearchHistoryAsync(string userId)
        {
            return await _context.UserSearchHistories.Where(h => h.UserId == userId).ToListAsync();
        }

        public async Task AddSearchHistoryAsync(UserSearchHistory history)
        {
            _context.UserSearchHistories.Add(history);
            await _context.SaveChangesAsync();
        }

        public async Task<bool> UpdateUserSubscriptionAsync(string userId, bool hasSubscription)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user != null)
            {
                user.HasSubscription = hasSubscription;
                var result = await _userManager.UpdateAsync(user);
                return result.Succeeded;
            }
            return false;
        }

        public async Task<bool> AssignRoleAsync(string userId, string role)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user != null)
            {
                user.Role = role;
                var result = await _userManager.UpdateAsync(user);
                return result.Succeeded;
            }
            return false;
        }
    }
}
