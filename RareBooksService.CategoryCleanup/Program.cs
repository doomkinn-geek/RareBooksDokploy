using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using NLog.Web;
using RareBooksService.Data;
using RareBooksService.Data.Interfaces;
using RareBooksService.Data.Services;
using System;
using System.IO;
using System.Threading.Tasks;

namespace RareBooksService.CategoryCleanup
{
    /// <summary>
    /// Консольная утилита для удаления нежелательных категорий
    /// </summary>
    public class Program
    {
        /// <summary>
        /// Точка входа для консольной утилиты очистки категорий
        /// </summary>
        /// <param name="args">Аргументы командной строки</param>
        /// <returns>Код завершения (0 - успех, 1 - ошибка)</returns>
        public static async Task<int> Main(string[] args)
        {
            try
            {
                // Создаем логгер через NLog
                var logger = NLogBuilder.ConfigureNLog("nlog.config").GetCurrentClassLogger();
                logger.Info("Запуск утилиты очистки нежелательных категорий");

                // Настраиваем хост
                using var host = CreateHostBuilder(args).Build();
                
                // Получаем сервисы
                using var scope = host.Services.CreateScope();
                var services = scope.ServiceProvider;
                
                // Получаем логгер
                var serviceLogger = services.GetRequiredService<ILogger<Program>>();
                serviceLogger.LogInformation("Инициализация сервиса очистки категорий");
                
                // Получаем сервис очистки категорий
                var categoryCleanupService = services.GetRequiredService<ICategoryCleanupService>();
                
                // Выполняем очистку категорий
                serviceLogger.LogInformation("Запуск процедуры удаления категорий...");
                var result = await categoryCleanupService.DeleteUnwantedCategoriesAsync();
                
                // Выводим результат
                serviceLogger.LogInformation($"Очистка завершена. Удалено {result.deletedCategoriesCount} категорий и {result.deletedBooksCount} книг");
                Console.WriteLine($"Очистка завершена. Удалено {result.deletedCategoriesCount} категорий и {result.deletedBooksCount} книг");
                
                return 0; // Успешное завершение
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Ошибка при выполнении очистки категорий: {ex.Message}");
                return 1; // Ошибка
            }
        }

        /// <summary>
        /// Создает хост для получения доступа к сервисам
        /// </summary>
        private static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureAppConfiguration((hostingContext, config) =>
                {
                    // Устанавливаем базовый путь для конфигурации
                    config.SetBasePath(AppContext.BaseDirectory);

                    // Загружаем конфигурацию из appsettings.json
                    var appSettingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
                    if (File.Exists(appSettingsPath))
                    {
                        config.AddJsonFile(appSettingsPath, optional: false, reloadOnChange: true);
                    }
                    else
                    {
                        Console.WriteLine($"Файл конфигурации не найден: {appSettingsPath}");
                    }
                })
                .ConfigureServices((hostContext, services) =>
                {
                    // Регистрируем сервисы
                    // Подключение к БД
                    services.AddDbContext<BooksDbContext>(options =>
                        options.UseSqlServer(
                            hostContext.Configuration.GetConnectionString("BooksConnection"),
                            b => b.MigrationsAssembly("RareBooksService.Data")));

                    services.AddDbContext<UsersDbContext>(options =>
                        options.UseSqlServer(
                            hostContext.Configuration.GetConnectionString("UsersConnection"),
                            b => b.MigrationsAssembly("RareBooksService.Data")));

                    // Регистрируем наши сервисы
                    services.AddScoped<IRegularBaseBooksRepository, RegularBaseBooksRepository>();
                    services.AddScoped<ICategoryCleanupService, CategoryCleanupService>();
                })
                .UseNLog(); // Настраиваем NLog для логирования
    }
} 