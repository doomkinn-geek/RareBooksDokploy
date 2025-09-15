using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Telegram.Bot;
using Telegram.Bot.Polling;
using Telegram.Bot.Types;
using Telegram.Bot.Exceptions;

namespace TelegramBotManager
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // Читаем конфигурацию
            var configuration = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
                .Build();

            var token = configuration["TelegramBot:Token"];
            
            if (string.IsNullOrEmpty(token) || token == "ВАШ_ТОКЕН_БОТА")
            {
                Console.WriteLine("❌ Токен бота не настроен!");
                Console.WriteLine("Отредактируйте файл appsettings.json и укажите токен вашего бота.");
                Console.WriteLine("Нажмите любую клавишу для выхода...");
                Console.ReadKey();
                return;
            }

            // Создаем хост для зависимостей
            using var host = Host.CreateDefaultBuilder(args)
                .ConfigureServices((context, services) =>
                {
                    services.AddSingleton<ITelegramBotClient>(new TelegramBotClient(token));
                    services.AddSingleton<BotService>();
                })
                .Build();

            var logger = host.Services.GetRequiredService<ILogger<Program>>();
            var botService = host.Services.GetRequiredService<BotService>();

            try
            {
                logger.LogInformation("Запуск Telegram бота...");
                await botService.StartAsync();
                
                Console.WriteLine("Бот запущен! Нажмите Ctrl+C для остановки...");
                
                // Ожидаем сигнал остановки
                var cancellationTokenSource = new CancellationTokenSource();
                Console.CancelKeyPress += (_, e) =>
                {
                    e.Cancel = true;
                    cancellationTokenSource.Cancel();
                };

                await Task.Delay(-1, cancellationTokenSource.Token);
            }
            catch (OperationCanceledException)
            {
                logger.LogInformation("Получен сигнал остановки");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Критическая ошибка");
            }
            finally
            {
                await botService.StopAsync();
                logger.LogInformation("Бот остановлен");
            }
        }
    }

    public class BotService
    {
        private readonly ITelegramBotClient _botClient;
        private readonly ILogger<BotService> _logger;
        private CancellationTokenSource? _cancellationTokenSource;

        public BotService(ITelegramBotClient botClient, ILogger<BotService> logger)
        {
            _botClient = botClient;
            _logger = logger;
        }

        public async Task StartAsync()
        {
            _cancellationTokenSource = new CancellationTokenSource();

            var receiverOptions = new ReceiverOptions
            {
                AllowedUpdates = { }, // получаем все обновления
                DropPendingUpdates = true
            };

            _botClient.StartReceiving(
                HandleUpdateAsync,
                HandlePollingErrorAsync,
                receiverOptions,
                _cancellationTokenSource.Token
            );

            var me = await _botClient.GetMeAsync(_cancellationTokenSource.Token);
            _logger.LogInformation("Бот {BotName} (@{BotUsername}) запущен!", me.FirstName, me.Username);
        }

        public async Task StopAsync()
        {
            if (_cancellationTokenSource != null)
            {
                _cancellationTokenSource.Cancel();
                _cancellationTokenSource.Dispose();
            }
        }

        private async Task HandleUpdateAsync(ITelegramBotClient botClient, Update update, CancellationToken cancellationToken)
        {
            try
            {
                if (update.Message is not { } message) return;
                if (message.Text is not { } messageText) return;

                var chatId = message.Chat.Id;
                var userId = message.From?.Id;

                _logger.LogInformation("Получено сообщение от {UserId}: {Message}", userId, messageText);

                // Обработка команд
                var response = messageText.ToLower() switch
                {
                    "/start" => GenerateStartMessage(userId?.ToString()),
                    "/help" => GenerateHelpMessage(),
                    "/link" => GenerateLinkInstructions(),
                    var text when text.StartsWith("/link ") => await ProcessLinkCommand(text, userId?.ToString()),
                    _ => "❓ Неизвестная команда. Используйте /help для просмотра доступных команд."
                };

                await botClient.SendTextMessageAsync(
                    chatId: chatId,
                    text: response,
                    parseMode: Telegram.Bot.Types.Enums.ParseMode.Html,
                    cancellationToken: cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обработке обновления");
            }
        }

        private async Task HandlePollingErrorAsync(ITelegramBotClient botClient, Exception exception, CancellationToken cancellationToken)
        {
            var errorMessage = exception switch
            {
                ApiRequestException apiRequestException
                    => $"Ошибка Telegram API:\n[{apiRequestException.ErrorCode}]\n{apiRequestException.Message}",
                _ => exception.ToString()
            };

            _logger.LogError("Ошибка поллинга: {ErrorMessage}", errorMessage);

            // Задержка перед повторным подключением при ошибке
            await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
        }

        private string GenerateStartMessage(string? telegramId)
        {
            return $"""
                🤖 <b>Добро пожаловать в бот уведомлений о редких книгах!</b>

                📋 <b>Ваш Telegram ID:</b> <code>{telegramId}</code>

                Этот бот поможет вам получать уведомления о новых интересных книгах на торгах.

                <b>Для начала работы:</b>
                1. Зайдите на сайт rare-books.ru
                2. Авторизуйтесь в своем аккаунте
                3. Перейдите в раздел "Уведомления"
                4. Нажмите "Привязать Telegram"
                5. Получите токен и используйте команду: /link ТОКЕН

                Используйте /help для просмотра всех команд.
                """;
        }

        private string GenerateHelpMessage()
        {
            return """
                📖 <b>Справка по командам бота</b>

                <b>Основные команды:</b>
                /start - Запуск бота и получение вашего ID
                /help - Показать эту справку
                /link ТОКЕН - Привязать аккаунт с сайта
                /settings - Управление настройками уведомлений
                /list - Показать ваши настройки

                <b>Как начать:</b>
                1. Получите ваш Telegram ID командой /start
                2. Зайдите на сайт rare-books.ru в раздел "Уведомления"
                3. Создайте токен привязки и используйте команду /link
                4. Настройте критерии поиска интересных книг
                5. Получайте уведомления о новых лотах!

                <b>Поддержка:</b>
                Если у вас возникли проблемы, обратитесь к администратору сайта.
                """;
        }

        private string GenerateLinkInstructions()
        {
            return """
                🔗 <b>Привязка аккаунта к Telegram</b>

                Для привязки вашего аккаунта:
                1. Зайдите на сайт rare-books.ru
                2. Авторизуйтесь в своем аккаунте
                3. Перейдите в раздел "Уведомления"
                4. Нажмите "Привязать Telegram"
                5. Скопируйте полученный токен
                6. Отправьте команду: <code>/link ВАШ_ТОКЕН</code>

                Например: <code>/link ABC12345</code>

                ⏰ Токен действителен 24 часа.
                """;
        }

        private async Task<string> ProcessLinkCommand(string text, string? telegramId)
        {
            var parts = text.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            
            if (parts.Length != 2)
            {
                return "❌ Неверный формат команды. Используйте: <code>/link ВАШ_ТОКЕН</code>";
            }

            var token = parts[1].Trim().ToUpper();

            // В реальной реализации здесь был бы вызов API для привязки аккаунта
            // Для демонстрации просто показываем, что команда обработана
            
            return $"""
                ✅ Команда привязки обработана!
                
                📋 Токен: <code>{token}</code>
                👤 Telegram ID: <code>{telegramId}</code>
                
                ⚠️ <b>Внимание:</b> Это демонстрационная версия бота.
                Для полной функциональности используйте бота, интегрированного с сайтом rare-books.ru.
                """;
        }
    }
}
