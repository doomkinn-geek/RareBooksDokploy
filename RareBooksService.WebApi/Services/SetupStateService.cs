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
            //_isSetupNeeded = true;
            //return;
            try
            {
                // 0) Проверяем, есть ли appsettings.json
                string path = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
                if (!File.Exists(path))
                {
                    _isSetupNeeded = true;
                    return;
                }

                // 1) Проверяем, можем ли мы подключиться к БД + EF 
                using var scope = _serviceProvider.CreateScope();
                var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();

                var anyAdmins = userManager.GetUsersInRoleAsync("Admin").Result;
                if (anyAdmins.Count == 0)
                {
                    _isSetupNeeded = true;
                }
                else
                {
                    _isSetupNeeded = false;
                }

                // 2) Проверяем JWT поля
                //    Если хотите, можно подгрузить IConfiguration и проверить, 
                //    есть ли builder.Configuration["Jwt:Key"] != null/пусто, etc.
                // ...
            }
            catch(AggregateException e)
            {
                //исключение из БД, возможно не была выполнена миграция
                if (e.InnerException is PostgresException)
                {
                    _isSetupNeeded = false;
                    return;
                }
                _isSetupNeeded = true;
            }
            catch (Exception ex)
            {
                // Любое исключение => считаем, что настройка не завершена
                _isSetupNeeded = true;
            }
        }

    }

}
