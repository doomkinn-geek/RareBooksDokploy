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
            try
            {
                return await _userManager.FindByIdAsync(userId);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при получении пользователя по ID: {ex.Message}");
                return null;
            }
        }

        /// <summary>Возвращает список всех пользователей (без подписок).</summary>
        public async Task<IEnumerable<ApplicationUser>> GetAllUsersAsync()
        {
            try
            {
                return await _userManager.Users.ToListAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при получении списка пользователей: {ex.Message}");
                return new List<ApplicationUser>();
            }
        }

        /// <summary>Возвращает историю поиска по UserId.</summary>
        public async Task<IEnumerable<UserSearchHistory>> GetUserSearchHistoryAsync(string userId)
        {            
            try
            {
                return await _userContext.UserSearchHistories
                    .Where(h => h.UserId == userId)
                    .OrderByDescending(h => h.SearchDate)
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при получении истории поиска пользователя: {ex.Message}");
                return new List<UserSearchHistory>();
            }
        }

        /// <summary>Добавляет новую запись в историю поиска пользователя.</summary>
        public async Task AddSearchHistoryAsync(UserSearchHistory history)
        {
            try
            {
                _userContext.UserSearchHistories.Add(history);
                await _userContext.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при добавлении записи в историю поиска: {ex.Message}");
            }
        }

        /// <summary>Обновляет флаг HasSubscription у пользователя.</summary>
        public async Task<bool> UpdateUserSubscriptionAsync(string userId, bool hasSubscription)
        {
            try
            {
                var user = await _userManager.FindByIdAsync(userId);
                if (user == null) return false;

                user.HasSubscription = hasSubscription;
                var result = await _userManager.UpdateAsync(user);
                return result.Succeeded;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при обновлении подписки пользователя: {ex.Message}");
                return false;
            }
        }

        /// <summary>Назначает пользователю новую роль (Role = role) и обновляет в БД.</summary>
        public async Task<bool> AssignRoleAsync(string userId, string role)
        {
            try
            {
                var user = await _userManager.FindByIdAsync(userId);
                if (user == null) return false;

                // Сохраняем старую роль для логирования
                var oldRole = user.Role;
                Console.WriteLine($"Changing role for user {user.Email} from '{oldRole}' to '{role}'");
                
                // Обновляем свойство Role в модели
                user.Role = role;
                
                // Получаем текущие роли из Identity
                var currentRoles = await _userManager.GetRolesAsync(user);
                Console.WriteLine($"Current Identity roles for user {user.Email}: {string.Join(", ", currentRoles)}");
                
                // Удаляем все текущие роли (для упрощения)
                if (currentRoles.Any())
                {
                    var removeResult = await _userManager.RemoveFromRolesAsync(user, currentRoles);
                    if (!removeResult.Succeeded)
                    {
                        Console.WriteLine($"Failed to remove roles for user {user.Email}: {string.Join(", ", removeResult.Errors.Select(e => e.Description))}");
                        return false;
                    }
                }
                
                // Добавляем новую роль в Identity
                var addResult = await _userManager.AddToRoleAsync(user, role);
                if (!addResult.Succeeded)
                {
                    Console.WriteLine($"Failed to add role '{role}' for user {user.Email}: {string.Join(", ", addResult.Errors.Select(e => e.Description))}");
                    return false;
                }
                
                // Обновляем пользователя в базе данных
                var updateResult = await _userManager.UpdateAsync(user);
                if (!updateResult.Succeeded)
                {
                    Console.WriteLine($"Failed to update user {user.Email}: {string.Join(", ", updateResult.Errors.Select(e => e.Description))}");
                    return false;
                }
                
                Console.WriteLine($"Successfully updated role for user {user.Email} from '{oldRole}' to '{role}'");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Ошибка при назначении роли пользователю: {ex.Message}");
                return false;
            }
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
                Console.WriteLine($"Ошибка при получении пользователей с подписками: {ex.Message}");
                return new List<ApplicationUser>();
            }
        }
    }
}
