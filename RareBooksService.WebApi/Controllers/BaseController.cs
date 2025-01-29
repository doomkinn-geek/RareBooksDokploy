using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using RareBooksService.Common.Models;
using System.Security.Claims;

namespace RareBooksService.WebApi.Controllers
{
    public abstract class BaseController : ControllerBase
    {
        protected readonly UserManager<ApplicationUser> _userManager;

        protected BaseController(UserManager<ApplicationUser> userManager)
        {
            _userManager = userManager;
        }

        protected async Task<ApplicationUser> GetCurrentUserAsync()
        {
            var userId = User?.Claims.FirstOrDefault(c => c.Type == ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userId))
            {
                Console.WriteLine("User ID is missing in the token.");
                return null;
            }
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                Console.WriteLine($"User not found with ID: {userId}");
            }
            return user;
        }

        protected bool IsUserAdmin(ApplicationUser user)
        {
            return user != null && user.Role == "Admin";
        }
    }

}
