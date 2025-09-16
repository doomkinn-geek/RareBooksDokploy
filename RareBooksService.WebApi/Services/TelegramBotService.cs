using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using RareBooksService.Common.Models;
using RareBooksService.Common.Models.Telegram;
using RareBooksService.Data;
using System.Collections.Generic;
using System.Linq;
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
        private readonly ITelegramLinkService _linkService;

        public TelegramBotService(
            ITelegramNotificationService telegramService,
            IServiceScopeFactory scopeFactory,
            ILogger<TelegramBotService> logger,
            ITelegramLinkService linkService)
        {
            _telegramService = telegramService ?? throw new ArgumentNullException(nameof(telegramService));
            _scopeFactory = scopeFactory ?? throw new ArgumentNullException(nameof(scopeFactory));
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _linkService = linkService ?? throw new ArgumentNullException(nameof(linkService));
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
                await ProcessUserStateAsync(chatId, telegramId, messageText, userState, cancellationToken);
                return;
            }

            // Если пользователь не в состоянии редактирования и не отправил команду
            await ShowMainMenuAsync(chatId, telegramId, cancellationToken);
        }

        private async Task ProcessCommandAsync(string chatId, string telegramId, string command, CancellationToken cancellationToken)
        {
            _logger.LogInformation("Обрабатываем команду: '{Command}' от пользователя {TelegramId}", command, telegramId);
            
            // Разделяем команду и параметры
            var commandParts = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var baseCommand = commandParts[0].ToLower();
            
            switch (baseCommand)
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
                case "/link":
                    await HandleLinkCommandAsync(chatId, telegramId, command, cancellationToken);
                    break;
                case "/register":
                    await HandleRegisterCommandAsync(chatId, telegramId, command, cancellationToken);
                    break;
                case "/login":
                    await HandleLoginCommandAsync(chatId, telegramId, command, cancellationToken);
                    break;
                case "/lots":
                    await HandleLotsCommandAsync(chatId, telegramId, command, cancellationToken);
                    break;
                default:
                    _logger.LogWarning("Неизвестная команда: '{Command}' от пользователя {TelegramId}", command, telegramId);
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
                    CallbackData = TelegramCallbacks.Help 
                }
            });

            await _telegramService.SendMessageWithKeyboardAsync(chatId, welcomeMessage.ToString(), helpKeyboard, cancellationToken);
        }

        private async Task HandleHelpCommandAsync(string chatId, CancellationToken cancellationToken)
        {
            var helpMessage = new StringBuilder();
            helpMessage.AppendLine("📖 <b>Справка по командам бота</b>");
            helpMessage.AppendLine();
            helpMessage.AppendLine("🔑 <b>Регистрация и вход:</b>");
            helpMessage.AppendLine("/register EMAIL ПАРОЛЬ - Создать новый аккаунт");
            helpMessage.AppendLine("/login EMAIL ПАРОЛЬ - Войти в существующий аккаунт");
            helpMessage.AppendLine("/link ТОКЕН - Привязка через токен с сайта");
            helpMessage.AppendLine();
            helpMessage.AppendLine("🔧 <b>Основные команды:</b>");
            helpMessage.AppendLine("/start - Запуск бота и получение вашего ID");
            helpMessage.AppendLine("/help - Показать эту справку");
            helpMessage.AppendLine("/settings - Управление настройками уведомлений");
            helpMessage.AppendLine("/list - Показать ваши настройки");
            helpMessage.AppendLine("/lots - Показать активные лоты по вашим критериям");
            helpMessage.AppendLine("/cancel - Отменить текущую операцию");
            helpMessage.AppendLine();
            helpMessage.AppendLine("🚀 <b>Быстрый старт:</b>");
            helpMessage.AppendLine("1. <code>/register email@example.com пароль</code>");
            helpMessage.AppendLine("2. <code>/settings</code> - настройте уведомления");
            helpMessage.AppendLine("3. <code>/lots</code> - смотрите активные лоты");
            helpMessage.AppendLine("4. Получайте уведомления о новых книгах!");
            helpMessage.AppendLine();
            helpMessage.AppendLine("📚 <b>Поиск лотов:</b>");
            helpMessage.AppendLine("• <code>/lots</code> - показать активные лоты (стр. 1)");
            helpMessage.AppendLine("• <code>/lots 2</code> - показать страницу 2");
            helpMessage.AppendLine("• Лоты фильтруются по вашим настройкам");
            helpMessage.AppendLine();
            helpMessage.AppendLine("📝 <b>Альтернативный способ:</b>");
            helpMessage.AppendLine("• Зайдите на rare-books.ru");
            helpMessage.AppendLine("• Перейдите в \"Уведомления\"");
            helpMessage.AppendLine("• Получите токен и используйте /link");

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

        private async Task HandleLinkCommandAsync(string chatId, string telegramId, string command, CancellationToken cancellationToken)
        {
            var parts = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            
            if (parts.Length == 1)
            {
                // Просто команда /link без токена
                var message = new StringBuilder();
                message.AppendLine("🔗 <b>Привязка аккаунта к Telegram</b>");
                message.AppendLine();
                message.AppendLine("💡 <b>Простой способ (рекомендуется):</b>");
                message.AppendLine("• <code>/register email@example.com пароль</code> - создать новый аккаунт");
                message.AppendLine("• <code>/login email@example.com пароль</code> - войти в существующий аккаунт");
                message.AppendLine();
                message.AppendLine("📋 <b>Через сайт (альтернативный способ):</b>");
                message.AppendLine("1. Зайдите на сайт rare-books.ru");
                message.AppendLine("2. Авторизуйтесь в своем аккаунте");
                message.AppendLine("3. Перейдите в раздел \"Уведомления\"");
                message.AppendLine("4. Нажмите \"Привязать Telegram\"");
                message.AppendLine("5. Скопируйте полученный токен");
                message.AppendLine("6. Отправьте команду: <code>/link ВАШ_ТОКЕН</code>");

                await _telegramService.SendNotificationAsync(chatId, message.ToString(), cancellationToken);
                return;
            }

            if (parts.Length != 2)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Неверный формат команды. Используйте: <code>/link ВАШ_ТОКЕН</code>", 
                    cancellationToken);
                return;
            }

            var token = parts[1].Trim().ToUpper();

            try
            {
                // Получаем информацию о пользователе в Telegram
                var telegramUser = await _telegramService.GetUserInfoAsync(chatId, cancellationToken);
                var telegramUsername = telegramUser?.Username;

                var result = await _linkService.LinkTelegramAccountAsync(token, telegramId, telegramUsername, cancellationToken);

                if (result.Success)
                {
                    var successMessage = new StringBuilder();
                    successMessage.AppendLine("🎉 <b>Аккаунт успешно привязан!</b>");
                    successMessage.AppendLine();
                    successMessage.AppendLine($"Пользователь: {result.User.UserName ?? result.User.Email}");
                    successMessage.AppendLine();
                    successMessage.AppendLine("Теперь вы можете:");
                    successMessage.AppendLine("• Управлять настройками уведомлений через бота");
                    successMessage.AppendLine("• Получать уведомления о новых интересных книгах");
                    successMessage.AppendLine("• Использовать команды:");
                    successMessage.AppendLine("  /settings - управление настройками");
                    successMessage.AppendLine("  /list - просмотр ваших настроек");

                    await _telegramService.SendNotificationAsync(chatId, successMessage.ToString(), cancellationToken);
                }
                else
                {
                    await _telegramService.SendNotificationAsync(chatId, 
                        $"❌ <b>Ошибка привязки:</b> {result.ErrorMessage}", 
                        cancellationToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при привязке аккаунта для Telegram ID {TelegramId}", telegramId);
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Произошла ошибка при привязке аккаунта. Попробуйте позже.", 
                    cancellationToken);
            }
        }

        private async Task HandleRegisterCommandAsync(string chatId, string telegramId, string command, CancellationToken cancellationToken)
        {
            var parts = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            
            if (parts.Length == 1)
            {
                // Справка по команде
                var helpMessage = new StringBuilder();
                helpMessage.AppendLine("📝 <b>Регистрация нового аккаунта</b>");
                helpMessage.AppendLine();
                helpMessage.AppendLine("Формат команды:");
                helpMessage.AppendLine("<code>/register EMAIL ПАРОЛЬ</code>");
                helpMessage.AppendLine();
                helpMessage.AppendLine("Пример:");
                helpMessage.AppendLine("<code>/register ivan@example.com MyPassword123</code>");
                helpMessage.AppendLine();
                helpMessage.AppendLine("⚠️ <b>Требования к паролю:</b>");
                helpMessage.AppendLine("• Минимум 6 символов");
                helpMessage.AppendLine("• Желательно использовать цифры и буквы");

                await _telegramService.SendNotificationAsync(chatId, helpMessage.ToString(), cancellationToken);
                return;
            }

            if (parts.Length != 3)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Неверный формат команды. Используйте: <code>/register EMAIL ПАРОЛЬ</code>", 
                    cancellationToken);
                return;
            }

            var email = parts[1].Trim();
            var password = parts[2].Trim();

            try
            {
                // Проверка уже привязанного аккаунта
                var existingUser = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
                if (existingUser != null)
                {
                    await _telegramService.SendNotificationAsync(chatId, 
                        $"⚠️ У вас уже есть привязанный аккаунт: {existingUser.Email}", 
                        cancellationToken);
                    return;
                }

                var result = await RegisterUserDirectlyAsync(email, password, telegramId, cancellationToken);

                if (result.IsSuccess)
                {
                    var successMessage = new StringBuilder();
                    successMessage.AppendLine("🎉 <b>Аккаунт успешно создан и привязан!</b>");
                    successMessage.AppendLine();
                    successMessage.AppendLine($"📧 Email: {email}");
                    successMessage.AppendLine($"🆔 Telegram ID: {telegramId}");
                    successMessage.AppendLine();
                    successMessage.AppendLine("Теперь вы можете:");
                    successMessage.AppendLine("• /settings - настройка уведомлений");
                    successMessage.AppendLine("• /list - просмотр настроек");
                    successMessage.AppendLine("• Получать уведомления о новых книгах");

                    await _telegramService.SendNotificationAsync(chatId, successMessage.ToString(), cancellationToken);
                }
                else
                {
                    await _telegramService.SendNotificationAsync(chatId, 
                        $"❌ <b>Ошибка регистрации:</b> {result.ErrorMessage}", 
                        cancellationToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при регистрации пользователя через Telegram ID {TelegramId}", telegramId);
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Произошла ошибка при регистрации. Попробуйте позже.", 
                    cancellationToken);
            }
        }

        private async Task HandleLoginCommandAsync(string chatId, string telegramId, string command, CancellationToken cancellationToken)
        {
            var parts = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            
            if (parts.Length == 1)
            {
                // Справка по команде
                var helpMessage = new StringBuilder();
                helpMessage.AppendLine("🔑 <b>Вход в существующий аккаунт</b>");
                helpMessage.AppendLine();
                helpMessage.AppendLine("Формат команды:");
                helpMessage.AppendLine("<code>/login EMAIL ПАРОЛЬ</code>");
                helpMessage.AppendLine();
                helpMessage.AppendLine("Пример:");
                helpMessage.AppendLine("<code>/login ivan@example.com MyPassword123</code>");
                helpMessage.AppendLine();
                helpMessage.AppendLine("📝 Если у вас нет аккаунта, используйте:");
                helpMessage.AppendLine("<code>/register EMAIL ПАРОЛЬ</code>");

                await _telegramService.SendNotificationAsync(chatId, helpMessage.ToString(), cancellationToken);
                return;
            }

            if (parts.Length != 3)
            {
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Неверный формат команды. Используйте: <code>/login EMAIL ПАРОЛЬ</code>", 
                    cancellationToken);
                return;
            }

            var email = parts[1].Trim();
            var password = parts[2].Trim();

            try
            {
                // Проверка уже привязанного аккаунта
                var existingUser = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
                if (existingUser != null)
                {
                    await _telegramService.SendNotificationAsync(chatId, 
                        $"⚠️ У вас уже есть привязанный аккаунт: {existingUser.Email}", 
                        cancellationToken);
                    return;
                }

                var result = await LoginUserDirectlyAsync(email, password, telegramId, cancellationToken);

                if (result.IsSuccess)
                {
                    var successMessage = new StringBuilder();
                    successMessage.AppendLine("🎉 <b>Успешный вход и привязка!</b>");
                    successMessage.AppendLine();
                    successMessage.AppendLine($"📧 Email: {email}");
                    successMessage.AppendLine($"🆔 Telegram ID: {telegramId}");
                    successMessage.AppendLine();
                    successMessage.AppendLine("Теперь вы можете:");
                    successMessage.AppendLine("• /settings - настройка уведомлений");
                    successMessage.AppendLine("• /list - просмотр настроек");
                    successMessage.AppendLine("• Получать уведомления о новых книгах");

                    await _telegramService.SendNotificationAsync(chatId, successMessage.ToString(), cancellationToken);
                }
                else
                {
                    await _telegramService.SendNotificationAsync(chatId, 
                        $"❌ <b>Ошибка входа:</b> {result.ErrorMessage}", 
                        cancellationToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при входе пользователя через Telegram ID {TelegramId}", telegramId);
                await _telegramService.SendNotificationAsync(chatId, 
                    "❌ Произошла ошибка при входе. Попробуйте позже.", 
                    cancellationToken);
            }
        }

        private async Task ProcessUserStateAsync(string chatId, string telegramId, string messageText, TelegramUserState userState, CancellationToken cancellationToken)
        {
            switch (userState.State)
            {
                case TelegramBotStates.EditingKeywords:
                    await ProcessEditKeywordsStateAsync(chatId, telegramId, messageText, userState, cancellationToken);
                    break;
                case TelegramBotStates.EditingPrice:
                    await ProcessEditPriceStateAsync(chatId, telegramId, messageText, userState, cancellationToken);
                    break;
                case TelegramBotStates.CreatingNotification:
                    await ProcessCreateNotificationStateAsync(chatId, telegramId, messageText, userState, cancellationToken);
                    break;
                default:
                    await _telegramService.ClearUserStateAsync(telegramId, cancellationToken);
                    await ShowMainMenuAsync(chatId, telegramId, cancellationToken);
                    break;
            }
        }

        private async Task HandleLotsCommandAsync(string chatId, string telegramId, string command, CancellationToken cancellationToken)
        {
            try
            {
                // Проверяем, привязан ли пользователь
                var user = await _telegramService.FindUserByTelegramIdAsync(telegramId, cancellationToken);
                if (user == null)
                {
                    await _telegramService.SendNotificationAsync(chatId,
                        "❌ Для просмотра лотов необходимо зарегистрироваться или войти в аккаунт.\n\n" +
                        "Используйте:\n" +
                        "• <code>/register email@example.com пароль</code>\n" +
                        "• <code>/login email@example.com пароль</code>",
                        cancellationToken);
                    return;
                }

                var parts = command.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                int page = 1;
                int pageSize = 5;

                // Парсим номер страницы, если указан
                if (parts.Length > 1 && int.TryParse(parts[1], out int requestedPage) && requestedPage > 0)
                {
                    page = requestedPage;
                }

                _logger.LogInformation("Пользователь {TelegramId} запросил активные лоты, страница {Page}", telegramId, page);

                using var scope = _scopeFactory.CreateScope();
                var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();
                var booksContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

                // Получаем настройки уведомлений пользователя
                var notificationPreferences = await usersContext.UserNotificationPreferences
                    .Where(np => np.UserId == user.Id && np.IsEnabled)
                    .FirstOrDefaultAsync(cancellationToken);

                if (notificationPreferences == null)
                {
                    await _telegramService.SendNotificationAsync(chatId,
                        "📝 У вас нет активных настроек поиска.\n\n" +
                        "Используйте <code>/settings</code> для настройки критериев поиска книг.",
                        cancellationToken);
                    return;
                }

                // Поиск активных лотов по критериям
                var activeLotsResult = await SearchActiveLotsAsync(booksContext, notificationPreferences, page, pageSize, cancellationToken);

                if (activeLotsResult.TotalCount == 0)
                {
                    await _telegramService.SendNotificationAsync(chatId,
                        "📭 <b>По вашим критериям нет активных лотов</b>\n\n" +
                        "Попробуйте:\n" +
                        "• Изменить настройки поиска: <code>/settings</code>\n" +
                        "• Расширить ценовой диапазон\n" +
                        "• Убрать фильтры по городу или году",
                        cancellationToken);
                    return;
                }

                // Форматируем результаты для отображения
                var message = await FormatLotsMessageAsync(activeLotsResult, page, pageSize, notificationPreferences, cancellationToken);

                await _telegramService.SendNotificationAsync(chatId, message, cancellationToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при обработке команды /lots для пользователя {TelegramId}", telegramId);
                await _telegramService.SendNotificationAsync(chatId,
                    "❌ Произошла ошибка при поиске лотов. Попробуйте позже.",
                    cancellationToken);
            }
        }

        private async Task<LotsSearchResult> SearchActiveLotsAsync(BooksDbContext booksContext, UserNotificationPreference preferences, int page, int pageSize, CancellationToken cancellationToken)
        {
            var query = booksContext.BooksInfo.Include(b => b.Category).AsQueryable();

            // Фильтр: только активные торги (торги еще не закончились)
            var now = DateTime.UtcNow;
            query = query.Where(b => b.EndDate > now);

            // Фильтр по ключевым словам
            var keywords = preferences.GetKeywordsList();
            if (keywords.Any())
            {
                // Нормализуем ключевые слова к нижнему регистру заранее
                var normalizedKeywords = keywords.Select(k => k.ToLower()).ToList();
                
                foreach (var keyword in normalizedKeywords)
                {
                    query = query.Where(b => 
                        b.NormalizedTitle.Contains(keyword) || 
                        b.NormalizedDescription.Contains(keyword) ||
                        EF.Functions.ILike(EF.Property<string>(b, "Tags"), $"%{keyword}%"));
                }
            }

            // Фильтр по категориям
            var categoryIds = preferences.GetCategoryIdsList();
            if (categoryIds.Any())
            {
                query = query.Where(b => categoryIds.Contains(b.CategoryId));
            }

            // Фильтр по цене
            if (preferences.MinPrice > 0)
            {
                query = query.Where(b => (decimal)b.Price >= preferences.MinPrice);
            }
            if (preferences.MaxPrice > 0)
            {
                query = query.Where(b => (decimal)b.Price <= preferences.MaxPrice);
            }

            // Фильтр по году издания
            if (preferences.MinYear > 0)
            {
                query = query.Where(b => b.YearPublished >= preferences.MinYear);
            }
            if (preferences.MaxYear > 0)
            {
                query = query.Where(b => b.YearPublished <= preferences.MaxYear);
            }

            // Фильтр по городам
            var cities = preferences.GetCitiesList();
            if (cities.Any())
            {
                // Нормализуем названия городов к нижнему регистру заранее
                var normalizedCities = cities.Select(c => c.ToLower()).ToList();
                
                foreach (var city in normalizedCities)
                {
                    // Используем регистронезависимый поиск через ILIKE (PostgreSQL)
                    // Если ILIKE не поддерживается, Entity Framework автоматически заменит на LIKE
                    query = query.Where(b => EF.Functions.ILike(b.City, $"%{city}%"));
                }
            }

            // Сортировка по дате окончания (ближайшие к завершению - первыми)
            query = query.OrderBy(b => b.EndDate);

            var totalCount = await query.CountAsync(cancellationToken);
            var books = await query
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .AsNoTracking()
                .ToListAsync(cancellationToken);

            return new LotsSearchResult
            {
                Books = books,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            };
        }

        private async Task<string> FormatLotsMessageAsync(LotsSearchResult result, int page, int pageSize, UserNotificationPreference preferences, CancellationToken cancellationToken)
        {
            var message = new StringBuilder();

            var totalPages = (int)Math.Ceiling((double)result.TotalCount / pageSize);

            message.AppendLine("📚 <b>Активные лоты по вашим критериям</b>");
            message.AppendLine();
            message.AppendLine($"📊 Найдено: {result.TotalCount} лотов");
            message.AppendLine($"📄 Страница: {page}/{totalPages}");
            message.AppendLine();

            // Показываем активные критерии
            var criteriaLines = new List<string>();
            if (!string.IsNullOrEmpty(preferences.Keywords))
                criteriaLines.Add($"🔍 Ключевые слова: {preferences.Keywords}");
            if (preferences.MinPrice > 0 || preferences.MaxPrice > 0)
                criteriaLines.Add($"💰 Цена: {(preferences.MinPrice > 0 ? $"от {preferences.MinPrice:N0} ₽" : "")} {(preferences.MaxPrice > 0 ? $"до {preferences.MaxPrice:N0} ₽" : "")}".Trim());
            if (preferences.MinYear > 0 || preferences.MaxYear > 0)
                criteriaLines.Add($"📅 Год: {(preferences.MinYear > 0 ? $"от {preferences.MinYear}" : "")} {(preferences.MaxYear > 0 ? $"до {preferences.MaxYear}" : "")}".Trim());
            if (!string.IsNullOrEmpty(preferences.Cities))
                criteriaLines.Add($"🏙️ Города: {preferences.Cities}");

            if (criteriaLines.Any())
            {
                message.AppendLine("<b>Активные критерии:</b>");
                foreach (var criteria in criteriaLines)
                {
                    message.AppendLine($"  {criteria}");
                }
                message.AppendLine();
            }

            int index = (page - 1) * pageSize + 1;
            foreach (var book in result.Books)
            {
                var timeLeft = book.EndDate - DateTime.UtcNow;
                var timeLeftStr = timeLeft.TotalDays >= 1 
                    ? $"{(int)timeLeft.TotalDays} дн."
                    : timeLeft.TotalHours >= 1 
                        ? $"{(int)timeLeft.TotalHours} ч."
                        : $"{(int)timeLeft.TotalMinutes} мин.";

                message.AppendLine($"<b>{index}. {book.Title}</b>");
                message.AppendLine($"💰 Текущая цена: <b>{book.Price:N0} ₽</b>");
                message.AppendLine($"⏰ Осталось: {timeLeftStr}");
                message.AppendLine($"🏙️ Город: {book.City}");
                if (book.YearPublished.HasValue)
                    message.AppendLine($"📅 Год издания: {book.YearPublished}");
                message.AppendLine($"📂 Категория: {book.Category?.Name ?? "Не указана"}");
                if (book.BidsCount > 0)
                    message.AppendLine($"👥 Ставок: {book.BidsCount}");
                
                // Ограничиваем длину описания
                if (!string.IsNullOrEmpty(book.Description))
                {
                    var shortDescription = book.Description.Length > 100 
                        ? book.Description.Substring(0, 100) + "..."
                        : book.Description;
                    message.AppendLine($"📝 {shortDescription}");
                }
                
                message.AppendLine();
                index++;
            }

            // Пагинация
            if (totalPages > 1)
            {
                message.AppendLine("📖 <b>Навигация:</b>");
                if (page > 1)
                    message.AppendLine($"  <code>/lots {page - 1}</code> - предыдущая страница");
                if (page < totalPages)
                    message.AppendLine($"  <code>/lots {page + 1}</code> - следующая страница");
                message.AppendLine($"  <code>/lots [номер страницы]</code> - перейти на страницу");
                message.AppendLine();
            }

            message.AppendLine("⚙️ <code>/settings</code> - изменить критерии поиска");

            return message.ToString();
        }

        private async Task<DirectAuthResult> RegisterUserDirectlyAsync(string email, string password, string telegramId, CancellationToken cancellationToken)
        {
            using var scope = _scopeFactory.CreateScope();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            try
            {
                // Проверяем валидность email
                if (string.IsNullOrWhiteSpace(email) || !email.Contains("@"))
                {
                    return DirectAuthResult.Fail("Некорректный email адрес");
                }

                // Проверяем длину пароля
                if (string.IsNullOrWhiteSpace(password) || password.Length < 6)
                {
                    return DirectAuthResult.Fail("Пароль должен содержать минимум 6 символов");
                }

                // Проверяем, не существует ли уже пользователь с таким email
                var existingUser = await userManager.FindByEmailAsync(email);
                if (existingUser != null)
                {
                    return DirectAuthResult.Fail("Пользователь с таким email уже существует. Используйте /login для входа");
                }

                // Проверяем, не привязан ли этот Telegram ID к другому аккаунту
                var userWithTelegramId = await context.Users
                    .FirstOrDefaultAsync(u => u.TelegramId == telegramId, cancellationToken);
                if (userWithTelegramId != null)
                {
                    return DirectAuthResult.Fail($"Этот Telegram аккаунт уже привязан к {userWithTelegramId.Email}");
                }

                // Создаем нового пользователя
                var newUser = new ApplicationUser
                {
                    UserName = email,
                    Email = email,
                    EmailConfirmed = true, // Автоматически подтверждаем email для Telegram регистрации
                    TelegramId = telegramId,
                    Role = "User",
                    CreatedAt = DateTime.UtcNow
                };

                var result = await userManager.CreateAsync(newUser, password);

                if (result.Succeeded)
                {
                    _logger.LogInformation("Пользователь {Email} успешно зарегистрирован через Telegram ID {TelegramId}", email, telegramId);
                    return DirectAuthResult.Success(newUser);
                }
                else
                {
                    var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                    return DirectAuthResult.Fail($"Ошибка создания аккаунта: {errors}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при регистрации пользователя {Email} через Telegram", email);
                return DirectAuthResult.Fail("Внутренняя ошибка сервера");
            }
        }

        private async Task<DirectAuthResult> LoginUserDirectlyAsync(string email, string password, string telegramId, CancellationToken cancellationToken)
        {
            using var scope = _scopeFactory.CreateScope();
            var userManager = scope.ServiceProvider.GetRequiredService<UserManager<ApplicationUser>>();
            var signInManager = scope.ServiceProvider.GetRequiredService<SignInManager<ApplicationUser>>();
            var context = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            try
            {
                // Проверяем валидность email
                if (string.IsNullOrWhiteSpace(email) || !email.Contains("@"))
                {
                    return DirectAuthResult.Fail("Некорректный email адрес");
                }

                // Находим пользователя
                var user = await userManager.FindByEmailAsync(email);
                if (user == null)
                {
                    return DirectAuthResult.Fail("Пользователь с таким email не найден. Используйте /register для создания аккаунта");
                }

                // Проверяем пароль
                var passwordCheck = await signInManager.CheckPasswordSignInAsync(user, password, false);
                if (!passwordCheck.Succeeded)
                {
                    return DirectAuthResult.Fail("Неверный пароль");
                }

                // Проверяем, не привязан ли уже к другому Telegram
                if (!string.IsNullOrEmpty(user.TelegramId) && user.TelegramId != telegramId)
                {
                    return DirectAuthResult.Fail("Этот аккаунт уже привязан к другому Telegram");
                }

                // Проверяем, не привязан ли этот Telegram ID к другому аккаунту
                if (string.IsNullOrEmpty(user.TelegramId))
                {
                    var userWithTelegramId = await context.Users
                        .FirstOrDefaultAsync(u => u.TelegramId == telegramId, cancellationToken);
                    if (userWithTelegramId != null)
                    {
                        return DirectAuthResult.Fail($"Этот Telegram аккаунт уже привязан к {userWithTelegramId.Email}");
                    }

                    // Привязываем Telegram ID
                    user.TelegramId = telegramId;
                    await userManager.UpdateAsync(user);
                }

                _logger.LogInformation("Пользователь {Email} успешно вошел через Telegram ID {TelegramId}", email, telegramId);
                return DirectAuthResult.Success(user);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Ошибка при входе пользователя {Email} через Telegram", email);
                return DirectAuthResult.Fail("Внутренняя ошибка сервера");
            }
        }

        // Методы реализованы в TelegramBotServiceExtended.cs
    }

    public class DirectAuthResult
    {
        public bool IsSuccess { get; private set; }
        public string ErrorMessage { get; private set; }
        public ApplicationUser User { get; private set; }

        private DirectAuthResult(bool isSuccess, string errorMessage, ApplicationUser user)
        {
            IsSuccess = isSuccess;
            ErrorMessage = errorMessage;
            User = user;
        }

        public static DirectAuthResult Success(ApplicationUser user)
        {
            return new DirectAuthResult(true, null, user);
        }

        public static DirectAuthResult Fail(string errorMessage)
        {
            return new DirectAuthResult(false, errorMessage, null);
        }
    }

    public class LotsSearchResult
    {
        public List<RegularBaseBook> Books { get; set; } = new();
        public int TotalCount { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }
}
