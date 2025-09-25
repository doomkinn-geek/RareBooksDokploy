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
using System.Text.RegularExpressions;
using Iveonik.Stemmers;
using LanguageDetection;

namespace RareBooksService.WebApi.Services
{
    public interface ITelegramBotService
    {
        Task ProcessUpdateAsync(TelegramUpdate update, CancellationToken cancellationToken = default);
        Task<List<RegularBaseBook>> FindMatchingBooksAsync(List<UserNotificationPreference> preferences, List<int> bookIds = null, CancellationToken cancellationToken = default);
        Task<int> ProcessNewBookNotificationsAsync(List<int> newBookIds, CancellationToken cancellationToken = default);
        Task<int> TestNotificationsAsync(int limitBooks, bool showBookIds = false, CancellationToken cancellationToken = default);
    }

    public partial class TelegramBotService : ITelegramBotService
    {
        private readonly ITelegramNotificationService _telegramService;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<TelegramBotService> _logger;
        private readonly ITelegramLinkService _linkService;
        private readonly Dictionary<string, IStemmer> _stemmers;
        private static readonly LanguageDetector _languageDetector;

        // Создаём статический экземпляр детектора языка один раз
        static TelegramBotService()
        {
            _languageDetector = new LanguageDetector();
            _languageDetector.AddAllLanguages();
        }

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
            
            _stemmers = new Dictionary<string, IStemmer>
            {
                { "rus", new RussianStemmer() },
                { "eng", new EnglishStemmer() },
                { "fra", new FrenchStemmer() },
                { "deu", new GermanStemmer() },
                { "ita", new ItalianStemmer() },
                { "fin", new FinnishStemmer() }
            };
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
                
                _logger.LogInformation("Отправляем пользователю {TelegramId} результат с {Count} лотами, размер сообщения: {MessageLength} символов", 
                    telegramId, activeLotsResult.Books.Count, message.Length);
                    
                // Отправляем сообщение с результатами пользователю
                bool sendResult = await _telegramService.SendNotificationAsync(chatId, message, cancellationToken);
                
                if (sendResult) {
                    _logger.LogInformation("Сообщение с результатами поиска успешно отправлено пользователю {TelegramId}", telegramId);
                } else {
                    _logger.LogError("Ошибка при отправке сообщения пользователю {TelegramId}. Размер сообщения: {MessageLength}", 
                        telegramId, message.Length);
                        
                    // Пробуем отправить только заголовок с ошибкой, если основное сообщение не отправилось
                    await _telegramService.SendNotificationAsync(chatId, 
                        "❌ <b>Ошибка при отправке результатов поиска</b>\n\nВозможно, сообщение слишком большое для Telegram API. Попробуйте уточнить поисковый запрос или перейти на другие страницы результатов.", 
                        cancellationToken);
                }
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
            _logger.LogInformation("Начало поиска активных лотов...");
            
            var query = booksContext.BooksInfo.Include(b => b.Category).AsQueryable();

            // Фильтр: только активные торги (торги еще не закончились)
            var now = DateTime.UtcNow;
            query = query.Where(b => b.EndDate > now);

            _logger.LogInformation("Применен фильтр по активным торгам");

            // Фильтр по категориям (делаем в SQL)
            /*var categoryIds = preferences.GetCategoryIdsList();
            if (categoryIds.Any())
            {
                query = query.Where(b => categoryIds.Contains(b.CategoryId));
                _logger.LogInformation("Применен фильтр по категориям: {CategoryIds}", string.Join(", ", categoryIds));
            }

            // Фильтр по цене (делаем в SQL)
            if (preferences.MinPrice > 0)
            {
                query = query.Where(b => (decimal)b.Price >= preferences.MinPrice);
                _logger.LogInformation("Применен фильтр минимальной цены: {MinPrice}", preferences.MinPrice);
            }
            if (preferences.MaxPrice > 0)
            {
                query = query.Where(b => (decimal)b.Price <= preferences.MaxPrice);
                _logger.LogInformation("Применен фильтр максимальной цены: {MaxPrice}", preferences.MaxPrice);
            }

            // Фильтр по году издания (делаем в SQL)
            if (preferences.MinYear > 0)
            {
                query = query.Where(b => b.YearPublished >= preferences.MinYear);
                _logger.LogInformation("Применен фильтр минимального года: {MinYear}", preferences.MinYear);
            }
            if (preferences.MaxYear > 0)
            {
                query = query.Where(b => b.YearPublished <= preferences.MaxYear);
                _logger.LogInformation("Применен фильтр максимального года: {MaxYear}", preferences.MaxYear);
            }

            // Фильтр по городам (делаем в SQL)
            var cities = preferences.GetCitiesList();
            if (cities.Any())
            {
                var normalizedCities = cities.Select(c => c.ToLower()).ToList();
                
                foreach (var city in normalizedCities)
                {
                    query = query.Where(b => EF.Functions.ILike(b.City, $"%{city}%"));
                }
                _logger.LogInformation("Применен фильтр по городам: {Cities}", string.Join(", ", normalizedCities));
            }*/

            // Сортировка по дате окончания (ближайшие к завершению - первыми)
            query = query.OrderBy(b => b.EndDate);

            _logger.LogInformation("Начинаем выполнение SQL запроса...");
            
            // ДИАГНОСТИКА: Сначала проверим общее количество активных лотов
            var totalActiveCount = await query.CountAsync(cancellationToken);
            _logger.LogInformation("ДИАГНОСТИКА: Всего активных лотов в базе: {TotalActive}", totalActiveCount);
            
            // ДИАГНОСТИКА: Показываем несколько случайных активных лотов для понимания данных
            var randomActiveBooks = await query
                .Take(5)
                .Select(b => new { b.Id, b.Title, b.Tags, b.BeginDate, b.EndDate })
                .ToListAsync(cancellationToken);
                
            _logger.LogInformation("ДИАГНОСТИКА: Примеры активных лотов:");
            for (int i = 0; i < randomActiveBooks.Count; i++)
            {
                var book = randomActiveBooks[i];
                _logger.LogInformation("ДИАГНОСТИКА: Лот {Index}: Id={Id}, Title='{Title}', Tags=[{Tags}], BeginDate={BeginDate}, EndDate={EndDate}", 
                    i + 1, book.Id, 
                    book.Title?.Substring(0, Math.Min(50, book.Title?.Length ?? 0)),
                    //book.NormalizedTitle?.Substring(0, Math.Min(50, book.NormalizedTitle?.Length ?? 0)),
                    book.Tags != null ? string.Join(", ", book.Tags.Take(3)) : "нет",
                    book.BeginDate,
                    book.EndDate);
            }

            // КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ: для небольших объемов данных (менее 1000 записей) берем все записи
            var keywords = preferences.GetKeywordsList();
            List<RegularBaseBook> allBooks;
            
            // ДИАГНОСТИКА: Специальный режим для отладки - если ключевое слово содержит "DEBUG", показываем все без фильтрации
            var isDebugMode = keywords.Any(k => k.ToUpper().Contains("DEBUG"));
            if (isDebugMode)
            {
                _logger.LogInformation("ДИАГНОСТИКА: Включен DEBUG режим - показываем лоты без фильтрации по ключевым словам");
                allBooks = await query
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .AsNoTracking()
                    .ToListAsync(cancellationToken);
                    
                _logger.LogInformation("ДИАГНОСТИКА: Загружено {Count} записей в DEBUG режиме", allBooks.Count);
            }
            else if (keywords.Any())
            {
                // ИСПРАВЛЕНИЕ: для небольших объемов данных берем ВСЕ записи
                // Это было причиной отсутствия результатов!
                if (totalActiveCount <= 1000)
                {
                    allBooks = await query
                        .AsNoTracking()
                        .ToListAsync(cancellationToken);
                    _logger.LogInformation("Загружено ВСЕ {Count} записей для фильтрации по ключевым словам (небольшой объем данных)", allBooks.Count);
                }
                else
                {
                    // Для больших объемов берем ограниченное количество
                    var batchSize = Math.Max(pageSize * 20, 1000); // Увеличили лимит
                    allBooks = await query
                        .Take(batchSize)
                        .AsNoTracking()
                        .ToListAsync(cancellationToken);
                    _logger.LogInformation("Загружено {Count} записей для фильтрации по ключевым словам (большой объем данных)", allBooks.Count);
                }

                // Обрабатываем ключевые слова через стемминг (как в RegularBaseBooksRepository)
                _logger.LogInformation("ДИАГНОСТИКА: Исходные ключевые слова: {Keywords}", string.Join(", ", keywords));
                
                // Для каждого исходного ключевого слова создаем набор стеммированных слов для поиска
                var keywordGroups = new List<List<string>>();
                var originalKeywords = new List<string>(); // Для fallback-поиска
                
                foreach (var keyword in keywords)
                {
                    var keywordSearchTerms = new List<string>();
                    var lowerKeyword = keyword.ToLower();
                    originalKeywords.Add(lowerKeyword);
                    
                    try
                    {
                        string detectedLanguage;
                        var processedKeyword = PreprocessText(keyword, out detectedLanguage);
                        var keywordParts = processedKeyword.Split(' ', StringSplitOptions.RemoveEmptyEntries);
                        
                        _logger.LogInformation("ДИАГНОСТИКА: '{OriginalKeyword}' -> язык: {Language} -> стемминг: '{ProcessedKeyword}' -> части для поиска: [{Parts}]", 
                            keyword, detectedLanguage, processedKeyword, string.Join(", ", keywordParts));
                        
                        // Добавляем стеммированные части
                        keywordSearchTerms.AddRange(keywordParts);
                        
                        // ИСПРАВЛЕНИЕ: всегда добавляем исходное слово для расширения поиска
                        if (!keywordSearchTerms.Contains(lowerKeyword))
                        {
                            keywordSearchTerms.Add(lowerKeyword);
                            _logger.LogInformation("ДИАГНОСТИКА: Добавляем исходное слово: '{OriginalKeyword}'", lowerKeyword);
                        }
                        
                        // НОВОЕ: добавляем частичные совпадения для учета склонений (первые 4-6 символов)
                        if (lowerKeyword.Length >= 4)
                        {
                            var partialWord = lowerKeyword.Substring(0, Math.Min(lowerKeyword.Length - 1, 6));
                            if (!keywordSearchTerms.Contains(partialWord))
                            {
                                keywordSearchTerms.Add(partialWord);
                                _logger.LogInformation("ДИАГНОСТИКА: Добавляем частичное слово для склонений: '{PartialWord}'", partialWord);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Ошибка при обработке ключевого слова '{Keyword}', используем простой поиск", keyword);
                        keywordSearchTerms.Add(lowerKeyword);
                        _logger.LogInformation("ДИАГНОСТИКА: '{OriginalKeyword}' -> ОШИБКА -> простой поиск: '{SimpleKeyword}'", 
                            keyword, lowerKeyword);
                    }
                    
                    // Убираем дубликаты
                    keywordSearchTerms = keywordSearchTerms.Distinct().ToList();
                    keywordGroups.Add(keywordSearchTerms);
                }

                _logger.LogInformation("ДИАГНОСТИКА: Итоговые группы слов для поиска: [{Groups}]", 
                    string.Join(" | ", keywordGroups.Select(g => "[" + string.Join(", ", g) + "]")));
                    
                // ДИАГНОСТИКА: Тестируем стемминг на известных русских словах
                var testWords = new[] { "книга", "книги", "книг", "пушкин", "пушкина", "гельмольт", "гельмгольц" };
                _logger.LogInformation("ДИАГНОСТИКА: Тестирование стемминга на русских словах:");
                foreach (var testWord in testWords)
                {
                    try
                    {
                        string detectedLang;
                        var stemmed = PreprocessText(testWord, out detectedLang);
                        _logger.LogInformation("ДИАГНОСТИКА: ТЕСТ '{TestWord}' -> язык: {Lang} -> стемминг: '{Stemmed}'", 
                            testWord, detectedLang, stemmed);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "ДИАГНОСТИКА: ОШИБКА стемминга для '{TestWord}'", testWord);
                    }
                }
                
                // ДИАГНОСТИКА: Показываем первые 3 книги для понимания данных
                var sampleBooks = allBooks.Take(3).ToList();
                for (int i = 0; i < sampleBooks.Count; i++)
                {
                    var book = sampleBooks[i];
                    _logger.LogInformation("ДИАГНОСТИКА: Книга {Index}: Id={Id}, Title='{Title}', NormalizedTitle='{NormalizedTitle}', NormalizedDescription='{NormalizedDesc}'", 
                        i + 1, book.Id, book.Title?.Substring(0, Math.Min(50, book.Title.Length)), 
                        book.NormalizedTitle?.Substring(0, Math.Min(50, book.NormalizedTitle.Length)),
                        book.NormalizedDescription?.Substring(0, Math.Min(100, book.NormalizedDescription?.Length ?? 0)));
                }
                
                // ДИАГНОСТИКА: Добавляем подсчетчик для понимания фильтрации
                int totalChecked = 0;
                int matchedByText = 0;
                int matchedByTags = 0;
                int matchedByFallback = 0;
                
                allBooks = allBooks.Where(book =>
                {
                    totalChecked++;
                    
                    // ОСНОВНОЙ ПОИСК: проверяем стеммированные слова в нормализованных полях
                    var matchesText = keywordGroups.All(group => 
                        group.Any(searchTerm =>
                            (book.NormalizedTitle?.Contains(searchTerm) == true) ||
                            (book.NormalizedDescription?.Contains(searchTerm) == true)));

                    // ПОИСК ПО ТЕГАМ: используем исходные ключевые слова, так как теги не стеммированы
                    var matchesTags = originalKeywords.All(originalKeyword =>
                        book.Tags?.Any(tag =>
                            tag.ToLower().Contains(originalKeyword)) == true);

                    // FALLBACK ПОИСК: ищем исходные слова в исходных полях (Title, Description)
                    var matchesFallback = originalKeywords.All(originalKeyword =>
                        (book.Title?.ToLower().Contains(originalKeyword) == true) ||
                        (book.Description?.ToLower().Contains(originalKeyword) == true));

                    var finalMatch = matchesText || matchesTags || matchesFallback;
                    
                    if (matchesText) matchedByText++;
                    if (matchesTags) matchedByTags++;
                    if (matchesFallback) matchedByFallback++;
                    
                    // ДИАГНОСТИКА: Логируем первые 3 проверки для понимания процесса
                    if (totalChecked <= 3)
                    {
                        _logger.LogInformation("ДИАГНОСТИКА: Проверка книги {Index}: '{Title}' | matchesText: {MatchText} | matchesTags: {MatchTags} | matchesFallback: {MatchFallback} | итог: {Final}", 
                            totalChecked, book.Title?.Substring(0, Math.Min(40, book.Title?.Length ?? 0)), 
                            matchesText, matchesTags, matchesFallback, finalMatch);
                            
                        // Показываем детальную проверку каждой группы ключевых слов
                        for (int i = 0; i < keywordGroups.Count; i++)
                        {
                            var group = keywordGroups[i];
                            var groupMatches = group.Any(searchTerm =>
                                (book.NormalizedTitle?.Contains(searchTerm) == true) ||
                                (book.NormalizedDescription?.Contains(searchTerm) == true));
                            _logger.LogInformation("ДИАГНОСТИКА: Группа {GroupIndex} [{Group}]: {GroupMatches}", 
                                i + 1, string.Join(", ", group), groupMatches);
                                
                            // Показываем конкретные совпадения
                            foreach (var searchTerm in group)
                            {
                                var titleMatch = book.NormalizedTitle?.Contains(searchTerm) == true;
                                var descMatch = book.NormalizedDescription?.Contains(searchTerm) == true;
                                if (titleMatch || descMatch)
                                {
                                    _logger.LogInformation("ДИАГНОСТИКА: ✓ Найдено совпадение с '{SearchTerm}': title={TitleMatch}, desc={DescMatch}", 
                                        searchTerm, titleMatch, descMatch);
                                }
                            }
                        }
                        
                        // Проверяем теги детально
                        if (book.Tags?.Any() == true)
                        {
                            _logger.LogInformation("ДИАГНОСТИКА: Теги книги: [{Tags}]", string.Join(", ", book.Tags));
                            foreach (var originalKeyword in originalKeywords)
                            {
                                var tagMatches = book.Tags.Any(tag => tag.ToLower().Contains(originalKeyword));
                                if (tagMatches)
                                {
                                    var matchingTags = book.Tags.Where(tag => tag.ToLower().Contains(originalKeyword)).ToList();
                                    _logger.LogInformation("ДИАГНОСТИКА: ✓ Найдено совпадение в тегах с '{Keyword}': {MatchingTags}", 
                                        originalKeyword, string.Join(", ", matchingTags));
                                }
                            }
                        }

                        // НОВОЕ: Проверяем fallback-поиск детально
                        _logger.LogInformation("ДИАГНОСТИКА: Fallback-поиск по исходным полям:");
                        foreach (var originalKeyword in originalKeywords)
                        {
                            var titleMatch = book.Title?.ToLower().Contains(originalKeyword) == true;
                            var descMatch = book.Description?.ToLower().Contains(originalKeyword) == true;
                            if (titleMatch || descMatch)
                            {
                                _logger.LogInformation("ДИАГНОСТИКА: ✓ Найдено fallback-совпадение с '{Keyword}': title={TitleMatch}, description={DescMatch}", 
                                    originalKeyword, titleMatch, descMatch);
                            }
                        }
                    }

                    return finalMatch;
                }).ToList();
                
                _logger.LogInformation("ДИАГНОСТИКА: Проверено книг: {TotalChecked}, найдено по тексту: {MatchedByText}, по тегам: {MatchedByTags}, fallback-поиск: {MatchedByFallback}", 
                    totalChecked, matchedByText, matchedByTags, matchedByFallback);

                _logger.LogInformation("После фильтрации по ключевым словам осталось {Count} записей", allBooks.Count);
            }
            else
            {
                // Если нет ключевых слов, используем обычную пагинацию в SQL
                allBooks = await query
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .AsNoTracking()
                    .ToListAsync(cancellationToken);

                _logger.LogInformation("Загружено {Count} записей с пагинацией в SQL", allBooks.Count);
            }

            // Применяем пагинацию в памяти только если фильтровали по ключевым словам (но не в DEBUG режиме)
            var totalCount = allBooks.Count;
            List<RegularBaseBook> books;
            
            if (keywords.Any() && !isDebugMode)
            {
                // Для точного подсчета нужен отдельный запрос
                var countQuery = booksContext.BooksInfo.AsQueryable();
                countQuery = countQuery.Where(b => b.EndDate > now);
                
                //if (categoryIds.Any())
                //    countQuery = countQuery.Where(b => categoryIds.Contains(b.CategoryId));
                if (preferences.MinPrice > 0)
                    countQuery = countQuery.Where(b => (decimal)b.Price >= preferences.MinPrice);
                if (preferences.MaxPrice > 0)
                    countQuery = countQuery.Where(b => (decimal)b.Price <= preferences.MaxPrice);
                if (preferences.MinYear > 0)
                    countQuery = countQuery.Where(b => b.YearPublished >= preferences.MinYear);
                if (preferences.MaxYear > 0)
                    countQuery = countQuery.Where(b => b.YearPublished <= preferences.MaxYear);
                /*if (cities.Any())
                {
                    var normalizedCities = cities.Select(c => c.ToLower()).ToList();
                    foreach (var city in normalizedCities)
                        countQuery = countQuery.Where(b => EF.Functions.ILike(b.City, $"%{city}%"));
                }*/
                
                // Примерный подсчет (для производительности)
                totalCount = Math.Min(await countQuery.CountAsync(cancellationToken), 1000);
                
                books = allBooks
                    .Skip((page - 1) * pageSize)
                    .Take(pageSize)
                    .ToList();
            }
            else
            {
                books = allBooks;
                
                // ДИАГНОСТИКА: В DEBUG режиме или без ключевых слов показываем реальный count
                if (isDebugMode)
                {
                    _logger.LogInformation("ДИАГНОСТИКА: DEBUG режим - показаны {Count} лотов без фильтрации", books.Count);
                    totalCount = totalActiveCount; // Показываем общее количество активных лотов
                }
            }

            _logger.LogInformation("Итоговый результат: {BooksCount} книг из {TotalCount} найденных", books.Count, totalCount);

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
            _logger.LogInformation("Форматирование результатов поиска для команды /lots: {Count} книг из {TotalCount}, страница {Page}/{TotalPages}",
               result.Books.Count, result.TotalCount, page, (int)Math.Ceiling((double)result.TotalCount / pageSize));
               
            var message = new StringBuilder();

            var totalPages = (int)Math.Ceiling((double)result.TotalCount / pageSize);

            message.AppendLine("📚 <b>Активные лоты по вашим критериям</b>");
            message.AppendLine();
            message.AppendLine($"📊 Найдено: {result.TotalCount} лотов");
            message.AppendLine($"📄 Страница: {page}/{totalPages}");
            message.AppendLine();

            // Показываем только ключевые слова для упрощения
            if (!string.IsNullOrEmpty(preferences.Keywords))
            {
                message.AppendLine($"🔍 <b>По критерию:</b> {preferences.Keywords}");
                message.AppendLine();
            }

            int index = (page - 1) * pageSize + 1;
            foreach (var book in result.Books)
            {
                var timeLeft = book.EndDate - DateTime.UtcNow;
                var endDateStr = book.EndDate.ToString("dd.MM.yyyy HH:mm");

                // УПРОЩЕННЫЙ ФОРМАТ: название лота, дата окончания, ссылка
                message.AppendLine($"<b>{index}. {book.Title}</b>");
                message.AppendLine($"⏰ Окончание: {endDateStr}");
                message.AppendLine($"🔗 <a href=\"https://meshok.net/item/{book.Id}\">Открыть лот №{book.Id}</a>");
                 
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
             
             // Проверяем размер сообщения
             string resultMessage = message.ToString();
             _logger.LogInformation("Итоговый размер сообщения: {MessageLength} символов", resultMessage.Length);
             
             // Максимальная длина сообщения для Telegram - примерно 4096 символов
             if (resultMessage.Length > 4000)
             {
                 _logger.LogWarning("Сформировано слишком длинное сообщение ({Length} символов). Ограничиваем результаты.", resultMessage.Length);
                 
                 // Создаем сокращенный вариант сообщения
                 var shortMessage = new StringBuilder();
                 shortMessage.AppendLine("📚 <b>Активные лоты по вашим критериям</b>");
                 shortMessage.AppendLine();
                 shortMessage.AppendLine($"📊 Найдено: {result.TotalCount} лотов");
                 shortMessage.AppendLine($"📄 Страница: {page}/{totalPages}");
                 shortMessage.AppendLine();
                 
                 // Добавляем первый лот как пример
                 if (result.Books.Any())
                 {
                     var book = result.Books.First();
                     shortMessage.AppendLine("<b>Пример найденного лота:</b>");
                     shortMessage.AppendLine($"<b>1. {book.Title}</b>");
                     shortMessage.AppendLine($"💰 Цена: <b>{book.Price:N0} ₽</b>");
                     shortMessage.AppendLine($"🏙️ Город: {book.City}");
                     if (book.YearPublished.HasValue)
                         shortMessage.AppendLine($"📅 Год издания: {book.YearPublished}");
                     shortMessage.AppendLine($"🔗 <a href=\"https://meshok.net/item/{book.Id}\">Открыть лот на Meshok.net</a>");
                     shortMessage.AppendLine();
                 }
                 
                 shortMessage.AppendLine("⚠️ <b>Предупреждение:</b> найдено слишком много информации для отображения в одном сообщении.");
                 shortMessage.AppendLine("Для получения более точных результатов уточните критерии поиска.");
                 shortMessage.AppendLine();
                 shortMessage.AppendLine("⚙️ <code>/settings</code> - изменить критерии поиска");
                 
                 resultMessage = shortMessage.ToString();
                 _logger.LogInformation("Сокращенный размер сообщения: {MessageLength} символов", resultMessage.Length);
             }

             return resultMessage;
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
        
        // ------------------- ПОМОГАЮЩИЙ МЕТОД: детект языка + стемминг -----------        
        private string PreprocessText(string text, out string detectedLanguage)
        {
            // Используем статический детектор
            detectedLanguage = DetectLanguage(text);
            if (detectedLanguage == "bul" || detectedLanguage == "ukr" || detectedLanguage == "mkd")
                detectedLanguage = "rus";

            if (!_stemmers.ContainsKey(detectedLanguage))
            {
                throw new NotSupportedException($"Language {detectedLanguage} is not supported.");
            }

            var stemmer = _stemmers[detectedLanguage];
            // Приводим к нижнему регистру с помощью ToLowerInvariant для производительности и предсказуемости
            var normalizedText = Regex.Replace(text.ToLowerInvariant(), @"\p{P}", " ");
            var words = normalizedText.Split(' ', StringSplitOptions.RemoveEmptyEntries)
                                      .Select(word => stemmer.Stem(word));
            return string.Join(" ", words);
        }

        private string DetectLanguage(string text)
        {
            return _languageDetector.Detect(text);
        }

        // ================= ЦЕНТРАЛИЗОВАННЫЕ МЕТОДЫ ПОИСКА И УВЕДОМЛЕНИЙ =================

        /// <summary>
        /// Фильтрация книг по настройкам пользователя (унифицированная логика)
        /// </summary>
        private List<RegularBaseBook> FilterBooksByPreference(List<RegularBaseBook> books, UserNotificationPreference preference)
        {
            var filteredBooks = books.AsEnumerable();

            // Фильтр по категориям
            var categoryIds = preference.GetCategoryIdsList();
            if (categoryIds.Any())
            {
                filteredBooks = filteredBooks.Where(b => categoryIds.Contains(b.CategoryId));
            }

            // Фильтр по ключевым словам (основная логика поиска - ЛОГИКА AND для фраз)
            var keywords = preference.GetKeywordsList();
            if (keywords.Any())
            {
                // Объединяем все ключевые слова в одну фразу и разбиваем на отдельные слова
                var fullPhrase = string.Join(" ", keywords);
                var allWords = fullPhrase.Split(new char[] { ' ', ',', ';' }, StringSplitOptions.RemoveEmptyEntries)
                    .Select(w => w.Trim().ToLower())
                    .Where(w => !string.IsNullOrEmpty(w))
                    .Distinct()
                    .ToList();

                _logger.LogInformation("Поиск по фразе: '{FullPhrase}' -> слова: [{Words}]", 
                    fullPhrase, string.Join(", ", allWords));

                // Создаем варианты поиска для каждого слова (стемминг + частичные совпадения)
                var searchVariants = new List<List<string>>();
                
                foreach (var word in allWords)
                {
                    var wordVariants = new List<string> { word }; // Исходное слово
                    
                    try
                    {
                        // Стемминг
                        string detectedLanguage;
                        var stemmedWord = PreprocessText(word, out detectedLanguage);
                        if (!string.IsNullOrEmpty(stemmedWord) && stemmedWord != word)
                        {
                            wordVariants.Add(stemmedWord.ToLower());
                        }
                        
                        // Частичные совпадения для склонений (первые 4-6 символов)
                        if (word.Length >= 4)
                        {
                            var partialWord = word.Substring(0, Math.Min(word.Length - 1, 6));
                            if (!wordVariants.Contains(partialWord))
                            {
                                wordVariants.Add(partialWord);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Ошибка при обработке слова '{Word}', используем простой поиск", word);
                    }
                    
                    searchVariants.Add(wordVariants.Distinct().ToList());
                }

                // Фильтруем книги: ВСЕ слова фразы должны найтись (логика AND)
                filteredBooks = filteredBooks.Where(book =>
                {
                    // Основной поиск: ВСЕ слова должны найтись в нормализованных полях
                    var matchesText = searchVariants.All(wordVariants =>
                        wordVariants.Any(variant =>
                            (book.NormalizedTitle?.Contains(variant) == true) ||
                            (book.NormalizedDescription?.Contains(variant) == true)));

                    // Поиск по тегам: ВСЕ исходные слова должны найтись в тегах
                    var matchesTags = allWords.All(word =>
                        book.Tags?.Any(tag =>
                            tag.ToLower().Contains(word)) == true);

                    // Fallback поиск: ВСЕ слова должны найтись в исходных полях
                    var matchesFallback = allWords.All(word =>
                        (book.Title?.ToLower().Contains(word) == true) ||
                        (book.Description?.ToLower().Contains(word) == true));

                    var result = matchesText || matchesTags || matchesFallback;
                    
                    if (result)
                    {
                        _logger.LogDebug("Книга '{BookTitle}' соответствует фразе '{FullPhrase}'", 
                            book.Title, fullPhrase);
                    }

                    return result;
                });
            }

            return filteredBooks.OrderBy(b => b.EndDate).ToList();
        }

        /// <summary>
        /// Унифицированный поиск книг по настройкам пользователей
        /// </summary>
        public async Task<List<RegularBaseBook>> FindMatchingBooksAsync(List<UserNotificationPreference> preferences, List<int> bookIds = null, CancellationToken cancellationToken = default)
        {
            if (!preferences?.Any() == true)
            {
                _logger.LogWarning("FindMatchingBooksAsync: Нет настроек для поиска");
                return new List<RegularBaseBook>();
            }

            using var scope = _scopeFactory.CreateScope();
            var booksContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();

            _logger.LogInformation("Начинаем унифицированный поиск книг для {PreferencesCount} настроек", preferences.Count);

            // Базовый запрос
            var query = booksContext.BooksInfo.Include(b => b.Category).AsQueryable();

            // Если указаны конкретные ID книг
            if (bookIds?.Any() == true)
            {
                query = query.Where(b => bookIds.Contains(b.Id));
                _logger.LogInformation("Ограничиваем поиск {BookCount} конкретными книгами", bookIds.Count);
            }
            else
            {
                // Только активные торги
                var now = DateTime.UtcNow;
                query = query.Where(b => b.EndDate > now);
                _logger.LogInformation("Поиск только среди активных лотов (EndDate > {Now})", now);
            }

            // Загружаем все подходящие книги
            var allBooks = await query.AsNoTracking().ToListAsync(cancellationToken);
            _logger.LogInformation("Загружено {BookCount} книг для фильтрации", allBooks.Count);

            var matchingBooks = new List<RegularBaseBook>();

            // Фильтруем по каждой настройке
            foreach (var preference in preferences)
            {
                _logger.LogInformation("Обрабатываем настройку ID {PreferenceId} пользователя {UserId}, ключевые слова: '{Keywords}'", 
                    preference.Id, preference.UserId, preference.Keywords);

                var booksForPreference = FilterBooksByPreference(allBooks, preference);
                _logger.LogInformation("Для настройки {PreferenceId} найдено {Count} подходящих книг", 
                    preference.Id, booksForPreference.Count);

                // Добавляем книги, избегая дубликатов
                foreach (var book in booksForPreference)
                {
                    if (!matchingBooks.Any(mb => mb.Id == book.Id))
                    {
                        matchingBooks.Add(book);
                    }
                }
            }

            _logger.LogInformation("Итого найдено {Count} уникальных книг по всем настройкам", matchingBooks.Count);
            return matchingBooks.OrderBy(b => b.EndDate).ToList();
        }

        /// <summary>
        /// Обработка уведомлений о новых книгах (единая точка входа)
        /// </summary>
        public async Task<int> ProcessNewBookNotificationsAsync(List<int> newBookIds, CancellationToken cancellationToken = default)
        {
            if (!newBookIds?.Any() == true)
            {
                _logger.LogWarning("ProcessNewBookNotificationsAsync: Список ID книг пуст");
                return 0;
            }

            _logger.LogInformation("Начинаем обработку уведомлений для {Count} новых книг", newBookIds.Count);

            using var scope = _scopeFactory.CreateScope();
            var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            // Получаем активные настройки уведомлений
            var preferences = await usersContext.UserNotificationPreferences
                .Where(np => np.IsEnabled && np.DeliveryMethod == NotificationDeliveryMethod.Telegram) // 4 = Telegram
                .ToListAsync(cancellationToken);

            if (!preferences.Any())
            {
                _logger.LogInformation("Нет активных настроек Telegram уведомлений");
                return 0;
            }

            _logger.LogInformation("Найдено {Count} активных настроек Telegram уведомлений", preferences.Count);

            // Ищем подходящие книги
            var matchingBooks = await FindMatchingBooksAsync(preferences, newBookIds, cancellationToken);

            if (!matchingBooks.Any())
            {
                _logger.LogInformation("Среди новых книг не найдено подходящих по критериям");
                return 0;
            }

            _logger.LogInformation("Найдено {Count} подходящих книг для уведомлений", matchingBooks.Count);

            int notificationsSent = 0;

            // Группируем уведомления по пользователям
            var userNotifications = new Dictionary<string, List<(UserNotificationPreference preference, List<RegularBaseBook> books)>>();

            foreach (var preference in preferences)
            {
                var booksForPreference = FilterBooksByPreference(matchingBooks, preference);
                if (booksForPreference.Any())
                {
                    var userId = preference.UserId;
                    if (!userNotifications.ContainsKey(userId))
                    {
                        userNotifications[userId] = new List<(UserNotificationPreference, List<RegularBaseBook>)>();
                    }
                    userNotifications[userId].Add((preference, booksForPreference));
                }
            }

            _logger.LogInformation("Создано уведомлений для {UserCount} пользователей", userNotifications.Count);

            // Отправляем уведомления каждому пользователю
            foreach (var userNotification in userNotifications)
            {
                var userId = userNotification.Key;
                var preferencesWithBooks = userNotification.Value;
                
                try
                {
                    var user = await usersContext.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
                    if (user?.TelegramId == null)
                    {
                        _logger.LogWarning("Пользователь {UserId} не имеет привязанного Telegram ID", userId);
                        continue;
                    }

                    await SendNewBooksNotificationAsync(user.TelegramId, preferencesWithBooks, cancellationToken);
                    notificationsSent++;

                    // Обновляем время последнего уведомления
                    foreach (var item in preferencesWithBooks)
                    {
                        item.preference.LastNotificationSent = DateTime.UtcNow;
                    }
                    await usersContext.SaveChangesAsync(cancellationToken);

                    _logger.LogInformation("Отправлено уведомление пользователю {TelegramId} ({UserId})", user.TelegramId, userId);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Ошибка при отправке уведомления пользователю {UserId}", userId);
                }
            }

            _logger.LogInformation("Обработка завершена. Отправлено {Count} уведомлений", notificationsSent);
            return notificationsSent;
        }

        /// <summary>
        /// Тестирование уведомлений (для админ панели)
        /// </summary>
        public async Task<int> TestNotificationsAsync(int limitBooks, bool showBookIds = false, CancellationToken cancellationToken = default)
        {
            _logger.LogInformation("ТЕСТ: Начинаем тестирование уведомлений с лимитом {Limit} книг", limitBooks);

            using var scope = _scopeFactory.CreateScope();
            var booksContext = scope.ServiceProvider.GetRequiredService<BooksDbContext>();
            var usersContext = scope.ServiceProvider.GetRequiredService<UsersDbContext>();

            // Получаем активные лоты
            var now = DateTime.UtcNow;
            var activeBookIds = await booksContext.BooksInfo
                .Where(b => b.EndDate > now)
                .OrderBy(b => b.EndDate)
                .Take(limitBooks)
                .Select(b => b.Id)
                .ToListAsync(cancellationToken);

            _logger.LogInformation("ТЕСТ: Найдено {Count} активных лотов для тестирования", activeBookIds.Count);

            if (!activeBookIds.Any())
            {
                _logger.LogWarning("ТЕСТ: Нет активных лотов для тестирования");
                return 0;
            }

            // Получаем активные настройки уведомлений
            var preferences = await usersContext.UserNotificationPreferences
                .Where(np => np.IsEnabled && np.DeliveryMethod == NotificationDeliveryMethod.Telegram) // 4 = Telegram
                .ToListAsync(cancellationToken);

            _logger.LogInformation("ТЕСТ: Найдено {Count} активных настроек уведомлений", preferences.Count);

            if (!preferences.Any())
            {
                _logger.LogWarning("ТЕСТ: Нет активных настроек для тестирования");
                return 0;
            }

            // ВАЖНО: Для теста пропускаем проверку частоты уведомлений
            return await ProcessNewBookNotificationsAsync(activeBookIds, cancellationToken);
        }

        /// <summary>
        /// Отправка уведомления о новых книгах пользователю (УПРОЩЕННЫЙ ФОРМАТ)
        /// </summary>
        private async Task SendNewBooksNotificationAsync(string telegramId, List<(UserNotificationPreference preference, List<RegularBaseBook> books)> preferencesWithBooks, CancellationToken cancellationToken)
        {
            int totalBooks = preferencesWithBooks.Sum(p => p.books.Count);
            
            _logger.LogInformation("Отправляем упрощенные уведомления пользователю {TelegramId}: {PreferencesCount} критериев, {TotalBooks} книг", 
                telegramId, preferencesWithBooks.Count, totalBooks);

            // Формируем общее сообщение с группировкой по критериям
            var message = new StringBuilder();
            message.AppendLine("🔔 <b>Новые лоты по вашим критериям!</b>");
            message.AppendLine();
            message.AppendLine($"📊 Найдено: {totalBooks} новых лотов");
            message.AppendLine();

            // Группируем по критериям
            foreach (var item in preferencesWithBooks)
            {
                var preference = item.preference;
                var books = item.books;

                if (!string.IsNullOrEmpty(preference.Keywords))
                {
                    message.AppendLine($"🔍 <b>По запросу:</b> {preference.Keywords}");
                }
                else
                {
                    message.AppendLine($"🔍 <b>По вашим критериям</b>");
                }

                foreach (var book in books)
                {
                    message.AppendLine($"📚 <b>{book.Title}</b>");
                    message.AppendLine($"🔗 <a href=\"https://meshok.net/item/{book.Id}\">Открыть лот №{book.Id}</a>");
                    message.AppendLine();
                }
                
                message.AppendLine("━━━━━━━━━━━━━━━━━━━━");
                message.AppendLine();
            }

            message.AppendLine("⚙️ <code>/settings</code> - управление настройками");
            message.AppendLine("📋 <code>/lots</code> - посмотреть все лоты");

            // Проверяем размер сообщения и разбиваем при необходимости
            await SendLongMessageAsync(telegramId, message.ToString(), cancellationToken);
        }

        /// <summary>
        /// Отправка длинного сообщения с разбивкой при необходимости
        /// </summary>
        private async Task SendLongMessageAsync(string telegramId, string message, CancellationToken cancellationToken)
        {
            const int maxMessageLength = 4000; // Оставляем запас от лимита Telegram в 4096 символов
            
            if (message.Length <= maxMessageLength)
            {
                // Сообщение помещается в один блок
                await _telegramService.SendNotificationAsync(telegramId, message, cancellationToken);
                return;
            }

            _logger.LogInformation("Сообщение слишком длинное ({Length} символов), разбиваем на части", message.Length);

            // Разбиваем сообщение по разделителям
            var lines = message.Split('\n');
            var currentMessage = new StringBuilder();
            int partNumber = 1;
            int totalParts = (int)Math.Ceiling((double)message.Length / maxMessageLength);

            foreach (var line in lines)
            {
                // Проверяем, поместится ли еще одна строка
                if (currentMessage.Length + line.Length + 1 > maxMessageLength && currentMessage.Length > 0)
                {
                    // Отправляем текущую часть
                    var partMessage = currentMessage.ToString();
                    if (totalParts > 1)
                    {
                        partMessage += $"\n\n📄 <i>Часть {partNumber}/{totalParts}</i>";
                    }
                    
                    await _telegramService.SendNotificationAsync(telegramId, partMessage, cancellationToken);
                    
                    // Начинаем новую часть
                    partNumber++;
                    currentMessage.Clear();
                    
                    // Небольшая задержка между частями
                    await Task.Delay(300, cancellationToken);
                }
                
                currentMessage.AppendLine(line);
            }

            // Отправляем последнюю часть
            if (currentMessage.Length > 0)
            {
                var partMessage = currentMessage.ToString();
                if (totalParts > 1)
                {
                    partMessage += $"\n\n📄 <i>Часть {partNumber}/{totalParts} (последняя)</i>";
                }
                
                await _telegramService.SendNotificationAsync(telegramId, partMessage, cancellationToken);
            }
        }
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

