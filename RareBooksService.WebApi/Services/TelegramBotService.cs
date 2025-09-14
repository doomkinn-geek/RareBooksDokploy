using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Telegram;
using RareBooksService.Data;
using System.Text;
using System.Text.Json;

namespace RareBooksService.WebApi.Services
{
    public interface ITelegramBotService
    {
        Task ProcessUpdateAsync(TelegramUpdate update, CancellationToken cancellationToken = default);
    }

    public partial class TelegramBotService : ITelegramBotService
    {
        private readonly ITelegramNotificationService _telegramService;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<TelegramBotService> _logger;

        public TelegramBotService(
            ITelegramNotificationService telegramService,
            IServiceScopeFactory scopeFactory,
            ILogger<TelegramBotService> logger)
        {
            _telegramService = telegramService ?? throw new ArgumentNullException(nameof(telegramService));
            _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public async Task ProcessUpdateAsync(TelegramUpdate update, CancellationToken cancellationToken = default)
        {
            try
            {
                if (update.Message != null)
                {
                    await ProcessMessageAsync(update.Message, cancellationToken);
                }
                else if (update.CallbackQuery != null)
                {
                    await ProcessCallbackQueryAsync(update.CallbackQuery, cancellationToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обработке обновления от Telegram: {UpdateId}", update.UpdateId);
            }
        }

        private async Task ProcessMessageAsync(TelegramMessage message, CancellationToken cancellationToken)
        {
            var chatId = message.Chat.Id.ToString();
            var telegramId = message.From.Id.ToString();
            var messageText = message.Text?.Trim();

            _logger.LogInformation("Получено сообщение от пользователя {TelegramId}: {Message}", telegramId, messageText);

            if (string.IsNullOrEmpty(messageText))
                return;

            // Получаем состояние пользователя
            var userState = await _telegramService.GetUserStateAsync(telegramId, cancellationToken);

            // Обработка команд
            if (messageText.StartsWith("/"))
            {
                await ProcessCommandAsync(chatId, telegramId, messageText, cancellationToken);
                return;
            }

            // Обработка состояний
            if (userState != null && userState.State != TelegramBotStates.None)
            {
                // TODO: Implement ProcessUserStateAsync
                await ShowMainMenuAsync(chatId, telegramId, cancellationToken);
                return;
            }

            // Если пользователь не в состоянии редактирования и не отправил команду
            await ShowMainMenuAsync(chatId, telegramId, cancellationToken);
        }

        private async Task ProcessCommandAsync(string chatId, string telegramId, string command, CancellationToken cancellationToken)
        {
            switch (command.ToLower())
            {
                case "/start":
                    await HandleStartCommandAsync(chatId, telegramId, cancellationToken);
                    break;
                case "/help":
                    await HandleHelpCommandAsync(chatId, cancellationToken);
                    break;
                case "/settings":
                    await HandleSettingsCommandAsync(chatId, telegramId, cancellationToken);
                    break;
                case "/list":
                    await HandleListCommandAsync(chatId, telegramId, cancellationToken);
                    break;
                case "/cancel":
                    await HandleCancelCommandAsync(chatId, telegramId, cancellationToken);
                    break;
                default:
                    await _telegramService.SendMessageWithKeyboardAsync(chatId, 
                        "❓ Неизвестная команда. Используйте /help для просмотра доступных команд.", 
                        cancellationToken: cancellationToken);
                    break;
            }
        }

        private async Task HandleStartCommandAsync(string chatId, string telegramId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);

            var welcomeMessage = new StringBuilder();
            welcomeMessage.AppendLine("🤖 <b>Добро пожаловать в бот уведомлений о редких книгах!</b>");
            welcomeMessage.AppendLine();

            if (user == null)
            {
                welcomeMessage.AppendLine("📋 <b>Ваш Telegram ID:</b> <code>" + telegramId + "</code>");
                welcomeMessage.AppendLine();
                welcomeMessage.AppendLine("Чтобы начать получать уведомления:");
                welcomeMessage.AppendLine("1. Скопируйте ваш ID выше");
                welcomeMessage.AppendLine("2. Перейдите на сайт в раздел \"Уведомления\"");
                welcomeMessage.AppendLine("3. Привяжите ваш Telegram ID к аккаунту");
                welcomeMessage.AppendLine("4. Настройте критерии поиска интересных книг");
            }
            else
            {
                welcomeMessage.AppendLine($"👋 Привет, {user.UserName ?? "пользователь"}!");
                welcomeMessage.AppendLine();
                welcomeMessage.AppendLine("Ваш аккаунт уже подключен к системе уведомлений.");
                welcomeMessage.AppendLine("Используйте кнопки ниже для управления настройками:");
                
                var keyboard = new TelegramInlineKeyboardMarkup(); // TODO: Implement CreateMainMenuKeyboard
                await _telegramService.SendMessageWithKeyboardAsync(chatId, welcomeMessage.ToString(), keyboard, cancellationToken);
                return;
            }

            var helpKeyboard = new TelegramInlineKeyboardMarkup();
            helpKeyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "ℹ️ Справка", 
                    CallbackData = TelegramBotStates.CallbackHelp 
                }
            });

            await _telegramService.SendMessageWithKeyboardAsync(chatId, welcomeMessage.ToString(), helpKeyboard, cancellationToken);
        }

        private async Task HandleHelpCommandAsync(string chatId, CancellationToken cancellationToken)
        {
            var helpMessage = new StringBuilder();
            helpMessage.AppendLine("📖 <b>Справка по командам бота</b>");
            helpMessage.AppendLine();
            helpMessage.AppendLine("<b>Основные команды:</b>");
            helpMessage.AppendLine("/start - Запуск бота и получение вашего ID");
            helpMessage.AppendLine("/help - Показать эту справку");
            helpMessage.AppendLine("/settings - Управление настройками уведомлений");
            helpMessage.AppendLine("/list - Показать ваши настройки");
            helpMessage.AppendLine("/cancel - Отменить текущую операцию");
            helpMessage.AppendLine();
            helpMessage.AppendLine("<b>Как начать:</b>");
            helpMessage.AppendLine("1. Получите ваш Telegram ID командой /start");
            helpMessage.AppendLine("2. Зайдите на сайт в раздел \"Уведомления\"");
            helpMessage.AppendLine("3. Подключите ваш Telegram ID");
            helpMessage.AppendLine("4. Создайте настройки уведомлений");
            helpMessage.AppendLine("5. Управляйте настройками через этот бот!");

            await _telegramService.SendNotificationAsync(chatId, helpMessage.ToString(), cancellationToken);
        }

        private async Task HandleSettingsCommandAsync(string chatId, string telegramId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Ваш аккаунт не подключен к системе. Используйте /start для получения инструкций.", 
                    cancellationToken);
                return;
            }

            await ShowSettingsMenuAsync(chatId, telegramId, cancellationToken);
        }

        private async Task HandleListCommandAsync(string chatId, string telegramId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Ваш аккаунт не подключен к системе.", 
                    cancellationToken);
                return;
            }

            var preferences = await _telegramService.GetUserNotificationPreferencesAsync(user.Id, cancellationToken);
            
            if (!preferences.Any())
            {
                await _telegramService.SendMessageWithKeyboardAsync(chatId, 
                    "📭 У вас пока нет настроек уведомлений.\n\nСоздайте первую настройку:", 
                    new TelegramInlineKeyboardMarkup(), // TODO: Implement CreateCreateNotificationKeyboard 
                    cancellationToken);
                return;
            }

            var listMessage = new StringBuilder();
            listMessage.AppendLine("📋 <b>Ваши настройки уведомлений:</b>");
            listMessage.AppendLine();

            foreach (var preference in preferences.Take(10)) // Показываем максимум 10
            {
                var status = preference.IsEnabled ? "✅" : "❌";
                var keywords = string.IsNullOrEmpty(preference.Keywords) 
                    ? "Не заданы" 
                    : preference.Keywords.Length > 30 
                        ? preference.Keywords.Substring(0, 30) + "..." 
                        : preference.Keywords;

                listMessage.AppendLine($"{status} <b>ID {preference.Id}</b>");
                listMessage.AppendLine($"   Ключевые слова: {keywords}");
                listMessage.AppendLine($"   Частота: {preference.NotificationFrequencyMinutes} мин");
                listMessage.AppendLine();
            }

            if (preferences.Count > 10)
            {
                listMessage.AppendLine($"... и еще {preferences.Count - 10} настроек");
                listMessage.AppendLine();
            }

            var keyboard = CreateSettingsListKeyboard(preferences.Take(5).ToList()); // Кнопки для первых 5 настроек
            await _telegramService.SendMessageWithKeyboardAsync(chatId, listMessage.ToString(), keyboard, cancellationToken);
        }

        private async Task HandleCancelCommandAsync(string chatId, string telegramId, CancellationToken cancellationToken)
        {
            await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
            await _telegramService.SendNotificationAsync(chatId, 
                "✅ Операция отменена.", 
                cancellationToken);
        }

        private async Task ProcessCallbackQueryAsync(TelegramCallbackQuery callbackQuery, CancellationToken cancellationToken)
        {
            var chatId = callbackQuery.Message.Chat.Id.ToString();
            var telegramId = callbackQuery.From.Id.ToString();
            var data = callbackQuery.Data;

            _logger.LogInformation("Получен callback query от пользователя {TelegramId}: {Data}", telegramId, data);

            await _telegramService.AnswerCallbackQueryAsync(callbackQuery.Id, cancellationToken: cancellationToken);

            if (data == TelegramBotStates.CallbackSettings)
            {
                await ShowSettingsMenuAsync(chatId, telegramId, cancellationToken);
            }
            else if (data == TelegramBotStates.CallbackCreate)
            {
                await StartCreateNotificationAsync(chatId, telegramId, cancellationToken);
            }
            else if (data.StartsWith(TelegramBotStates.CallbackEdit))
            {
                var preferenceId = int.Parse(data.Replace(TelegramBotStates.CallbackEdit, ""));
                await ShowEditNotificationMenuAsync(chatId, telegramId, preferenceId, cancellationToken);
            }
            else if (data.StartsWith(TelegramBotStates.CallbackDelete))
            {
                var preferenceId = int.Parse(data.Replace(TelegramBotStates.CallbackDelete, ""));
                await ShowDeleteConfirmationAsync(chatId, telegramId, preferenceId, cancellationToken);
            }
            else if (data.StartsWith(TelegramBotStates.CallbackDeleteConfirm))
            {
                var preferenceId = int.Parse(data.Replace(TelegramBotStates.CallbackDeleteConfirm, ""));
                await DeleteNotificationAsync(chatId, telegramId, preferenceId, cancellationToken);
            }
            else if (data.StartsWith(TelegramBotStates.CallbackToggle))
            {
                var preferenceId = int.Parse(data.Replace(TelegramBotStates.CallbackToggle, ""));
                await ToggleNotificationAsync(chatId, telegramId, preferenceId, cancellationToken);
            }
            else if (data == TelegramBotStates.CallbackSettings)
            {
                await ShowSettingsMenuAsync(chatId, telegramId, cancellationToken);
            }
            else if (data == TelegramBotStates.CallbackHelp)
            {
                await HandleHelpCommandAsync(chatId, cancellationToken);
            }
            else if (data == TelegramBotStates.CallbackCancel || data == TelegramBotStates.CallbackCancelDelete)
            {
                await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
                await ShowMainMenuAsync(chatId, telegramId, cancellationToken);
            }
            // Обработка редактирования полей настройки
            else if (data.StartsWith(TelegramBotStates.CallbackEditKeywords))
            {
                var preferenceId = int.Parse(data.Replace(TelegramBotStates.CallbackEditKeywords, ""));
                await StartEditKeywordsAsync(chatId, telegramId, preferenceId, cancellationToken);
            }
            else if (data.StartsWith(TelegramBotStates.CallbackEditPrice))
            {
                var preferenceId = int.Parse(data.Replace(TelegramBotStates.CallbackEditPrice, ""));
                await StartEditPriceAsync(chatId, telegramId, preferenceId, cancellationToken);
            }
            // Добавим обработку других полей по аналогии
        }

        // ProcessUserStateAsync реализован в TelegramBotServiceMethods.cs

        // Создание клавиатур реализовано в TelegramBotServiceMethods.cs

        // CreateCreateNotificationKeyboard реализован в TelegramBotServiceMethods.cs

        private TelegramInlineKeyboardMarkup CreateSettingsListKeyboard(List<UserNotificationPreference> preferences)
        {
            var keyboard = new TelegramInlineKeyboardMarkup();

            foreach (var preference in preferences)
            {
                var status = preference.IsEnabled ? "✅" : "❌";
                var keywords = string.IsNullOrEmpty(preference.Keywords) 
                    ? "Настройка" 
                    : preference.Keywords.Length > 15 
                        ? preference.Keywords.Substring(0, 15) + "..." 
                        : preference.Keywords;

                keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
                {
                    new TelegramInlineKeyboardButton 
                    { 
                        Text = $"{status} {keywords}", 
                        CallbackData = TelegramBotStates.CallbackEdit + preference.Id 
                    }
                });
            }

            keyboard.InlineKeyboard.Add(new List<TelegramInlineKeyboardButton>
            {
                new TelegramInlineKeyboardButton 
                { 
                    Text = "➕ Создать новую", 
                    CallbackData = TelegramBotStates.CallbackCreate 
                },
                new TelegramInlineKeyboardButton 
                { 
                    Text = "🔙 Назад", 
                    CallbackData = TelegramBotStates.CallbackSettings 
                }
            });

            return keyboard;
        }

        // Методы для работы с настройками (будут дополнены)

        private async Task ShowMainMenuAsync(string chatId, string telegramId, CancellationToken cancellationToken)
        {
            var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
            if (user == null)
            {
                await HandleStartCommandAsync(chatId, telegramId, cancellationToken);
                return;
            }

            await _telegramService.SendNotificationAsync(chatId, 
                "🏠 <b>Главное меню</b>\n\nВыберите действие:\n/settings - Настройки\n/list - Мои настройки\n/help - Справка", 
                cancellationToken);
        }

        private async Task ShowSettingsMenuAsync(string chatId, string telegramId, CancellationToken cancellationToken)
        {
            await HandleListCommandAsync(chatId, telegramId, cancellationToken);
        }

        // Методы реализованы в TelegramBotServiceExtended.cs
    }
}
