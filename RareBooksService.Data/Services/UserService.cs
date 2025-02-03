using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Data.Interfaces;

namespace RareBooksService.Data.Services
{
    public class UserService : IUserService
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly UsersDbContext _userContext;

        public UserService(UserManager<ApplicationUser> userManager, UsersDbContext context)
        {
            _userManager = userManager;
            _userContext = context;
        }

        /// <summary>Возвращает пользователя по его идентификатору.</summary>
        public async Task<ApplicationUser> GetUserByIdAsync(string userId)
        {
            return await _userManager.FindByIdAsync(userId);
        }

        /// <summary>Возвращает список всех пользователей (без подписок).</summary>
        public async Task<IEnumerable<ApplicationUser>> GetAllUsersAsync()
        {
            return await _userManager.Users.ToListAsync();
        }

        /// <summary>Возвращает историю поиска по UserId.</summary>
        public async Task<IEnumerable<UserSearchHistory>> GetUserSearchHistoryAsync(string userId)
        {
            return await _userContext.UserSearchHistories
                .Where(h => h.UserId == userId)
                .ToListAsync();
        }

        /// <summary>Добавляет новую запись в историю поиска пользователя.</summary>
        public async Task AddSearchHistoryAsync(UserSearchHistory history)
        {
            _userContext.UserSearchHistories.Add(history);
            await _userContext.SaveChangesAsync();
        }

        /// <summary>Обновляет флаг HasSubscription у пользователя.</summary>
        public async Task<bool> UpdateUserSubscriptionAsync(string userId, bool hasSubscription)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return false;

            user.HasSubscription = hasSubscription;
            var result = await _userManager.UpdateAsync(user);
            return result.Succeeded;
        }

        /// <summary>Назначает пользователю новую роль (Role = role) и обновляет в БД.</summary>
        public async Task<bool> AssignRoleAsync(string userId, string role)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null) return false;

            user.Role = role;
            // При необходимости используйте _userManager.AddToRoleAsync(user, role)
            // и удаляйте предыдущую роль, если нужно.
            var result = await _userManager.UpdateAsync(user);
            return result.Succeeded;
        }

        /// <summary>Возвращает всех пользователей вместе с их подписками.</summary>
        public async Task<List<ApplicationUser>> GetAllUsersWithSubscriptionsAsync()
        {
            try
            {
                // Важно! У нас нет поля CurrentSubscription в ApplicationUser,
                // но есть коллекция Subscriptions. По желанию можно реализовать 
                // вычисляемое свойство CurrentSubscription.
                // Здесь загружаем все подписки и планы подписок:
                return await _userContext.Users
                    .Include(u => u.Subscriptions)
                    .ThenInclude(s => s.SubscriptionPlan)
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                return new List<ApplicationUser>();
            }
        }
    }
}
