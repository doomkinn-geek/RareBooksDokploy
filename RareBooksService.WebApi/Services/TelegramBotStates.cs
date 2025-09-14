namespace RareBooksService.WebApi.Services
{
    /// <summary>
    /// Состояния диалога с пользователем в Telegram боте
    /// </summary>
    public static class TelegramBotStates
    {
        // Основные состояния
        public const string None = "NONE";
        public const string AwaitingKeywords = "AWAITING_KEYWORDS";
        public const string AwaitingPrice = "AWAITING_PRICE";
        public const string AwaitingYear = "AWAITING_YEAR";
        public const string AwaitingCities = "AWAITING_CITIES";
        public const string AwaitingCategories = "AWAITING_CATEGORIES";
        public const string AwaitingFrequency = "AWAITING_FREQUENCY";

        // Состояния создания настройки
        public const string CreatingNotification = "CREATING_NOTIFICATION";
        public const string CreatingKeywords = "CREATING_KEYWORDS";
        public const string CreatingPrice = "CREATING_PRICE";
        public const string CreatingYear = "CREATING_YEAR";
        public const string CreatingCities = "CREATING_CITIES";
        public const string CreatingCategories = "CREATING_CATEGORIES";
        public const string CreatingFrequency = "CREATING_FREQUENCY";

        // Состояния редактирования
        public const string EditingNotification = "EDITING_NOTIFICATION";
        public const string EditingKeywords = "EDITING_KEYWORDS";
        public const string EditingPrice = "EDITING_PRICE";
        public const string EditingYear = "EDITING_YEAR";
        public const string EditingCities = "EDITING_CITIES";
        public const string EditingCategories = "EDITING_CATEGORIES";
        public const string EditingFrequency = "EDITING_FREQUENCY";

        // Callbacks для inline клавиатуры
        public const string CallbackStart = "start";
        public const string CallbackHelp = "help";
        public const string CallbackSettings = "settings";
        public const string CallbackList = "list";
        public const string CallbackCreate = "create";
        public const string CallbackEdit = "edit_";
        public const string CallbackToggle = "toggle_";
        public const string CallbackDelete = "delete_";
        public const string CallbackDeleteConfirm = "delete_confirm_";
        public const string CallbackCancel = "cancel";
        public const string CallbackCancelDelete = "cancel_delete";
        
        // Callbacks для редактирования полей
        public const string CallbackEditKeywords = "edit_keywords_";
        public const string CallbackEditPrice = "edit_price_";
        public const string CallbackEditYear = "edit_year_";
        public const string CallbackEditCities = "edit_cities_";
        public const string CallbackEditCategories = "edit_categories_";
        public const string CallbackEditFrequency = "edit_frequency_";
    }

    /// <summary>
    /// Вспомогательные методы для работы с состояниями
    /// </summary>
    public static class TelegramBotStatesHelper
    {
        /// <summary>
        /// Проверяет, является ли состояние состоянием создания настройки
        /// </summary>
        public static bool IsCreatingState(string state)
        {
            return state?.StartsWith("CREATING_") == true;
        }

        /// <summary>
        /// Проверяет, является ли состояние состоянием редактирования настройки
        /// </summary>
        public static bool IsEditingState(string state)
        {
            return state?.StartsWith("EDITING_") == true;
        }

        /// <summary>
        /// Проверяет, является ли состояние состоянием ожидания ввода
        /// </summary>
        public static bool IsAwaitingState(string state)
        {
            return state?.StartsWith("AWAITING_") == true;
        }

        /// <summary>
        /// Извлекает ID настройки из callback данных
        /// </summary>
        public static string? ExtractNotificationIdFromCallback(string callbackData)
        {
            if (string.IsNullOrEmpty(callbackData))
                return null;

            var prefixes = new[] { 
                TelegramBotStates.CallbackEdit, 
                TelegramBotStates.CallbackToggle, 
                TelegramBotStates.CallbackDelete,
                TelegramBotStates.CallbackDeleteConfirm,
                TelegramBotStates.CallbackEditKeywords,
                TelegramBotStates.CallbackEditPrice,
                TelegramBotStates.CallbackEditYear,
                TelegramBotStates.CallbackEditCities,
                TelegramBotStates.CallbackEditCategories,
                TelegramBotStates.CallbackEditFrequency
            };

            foreach (var prefix in prefixes)
            {
                if (callbackData.StartsWith(prefix))
                {
                    return callbackData.Substring(prefix.Length);
                }
            }

            return null;
        }
    }
}
