using Microsoft.AspNetCore.Identity;
using Npgsql;
using RareBooksService.Common.Models;

namespace RareBooksService.WebApi.Services
{

    public interface ISetupStateService
    {
        bool IsInitialSetupNeeded { get; }
        void DetermineIfSetupNeeded();
    }

    public class SetupStateService : ISetupStateService
    {
        private bool _isSetupNeeded = false;
        private readonly IServiceProvider _serviceProvider;

        public bool IsInitialSetupNeeded => _isSetupNeeded;

        public SetupStateService(IServiceProvider serviceProvider)
        {
            _serviceProvider = serviceProvider;
        }

        public void DetermineIfSetupNeeded()
        {
            // ВРЕМЕННО для диагностики - всегда возвращаем true
            _isSetupNeeded = true;
            Console.WriteLine("[SetupStateService] DIAGNOSTIC MODE: Force IsInitialSetupNeeded = true");
            return;
            
            try
            {
                Console.WriteLine("[SetupStateService] Starting DetermineIfSetupNeeded...");
                
                // 0) Проверяем, есть ли appsettings.json
                string path = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
                Console.WriteLine($"[SetupStateService] Checking appsettings.json at: {path}");
                if (!File.Exists(path))
                {
                    Console.WriteLine("[SetupStateService] appsettings.json not found - setup needed");
                    _isSetupNeeded = true;
                    return;
                }

                // 1) Проверяем, можем ли мы подключиться к БД + EF 
                Console.WriteLine("[SetupStateService] Checking database and admin users...");
                using var scope = _serviceProvider.CreateScope();
                var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

                var anyAdmins = userManager.GetUsersInRoleAsync("Admin").Result;
                Console.WriteLine($"[SetupStateService] Found {anyAdmins.Count} admin users");
                if (anyAdmins.Count == 0)
                {
                    Console.WriteLine("[SetupStateService] No admin users found - setup needed");
                    _isSetupNeeded = true;
                }
                else
                {
                    Console.WriteLine("[SetupStateService] Admin users found - setup not needed");
                    _isSetupNeeded = false;
                }

                // 2) Проверяем JWT поля
                //    Если хотите, можно подгрузить IConfiguration и проверить, 
                //    есть ли builder.Configuration["Jwt:Key"] != null/пусто, etc.
                // ...
            }
            catch(AggregateException e)
            {
                Console.WriteLine($"[SetupStateService] AggregateException: {e.Message}");
                Console.WriteLine($"[SetupStateService] InnerException: {e.InnerException?.Message}");
                //исключение из БД, возможно не была выполнена миграция
                if (e.InnerException is PostgresException)
                {
                    Console.WriteLine("[SetupStateService] PostgresException detected - setup needed");
                    _isSetupNeeded = true;  // Исправлена логика: если БД недоступна, нужна настройка
                    return;
                }
                Console.WriteLine("[SetupStateService] Other AggregateException - setup needed");
                _isSetupNeeded = true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[SetupStateService] General Exception: {ex.Message}");
                Console.WriteLine($"[SetupStateService] StackTrace: {ex.StackTrace}");
                // Любое исключение => считаем, что настройка не завершена
                Console.WriteLine("[SetupStateService] Exception occurred - setup needed");
                _isSetupNeeded = true;
            }
            
            Console.WriteLine($"[SetupStateService] Final result: IsInitialSetupNeeded = {_isSetupNeeded}");
        }

    }

}
